import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/coding_problem.dart';
import '../models/curriculum.dart';
import '../models/hot_question.dart';

/// All curriculum and learner data live in SQLite after first launch.
class LearningRepository {
  final Database db;
  LearningRepository(this.db);
  static Future<LearningRepository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final catalog = jsonDecode(
      await rootBundle.loadString('assets/content/catalog.json'),
    ) as Map<String, dynamic>;
    final contents = <Map<String, dynamic>>[];
    for (final asset in catalog['chapters'] as List) {
      contents.add(
        jsonDecode(await rootBundle.loadString(asset as String))
            as Map<String, dynamic>,
      );
    }
    final location = path ?? p.join(await f.getDatabasesPath(), 'ml_path.db');
    final db = await f.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE chapters (id TEXT PRIMARY KEY, content TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE progress (lesson_id TEXT PRIMARY KEY, completed INTEGER NOT NULL DEFAULT 0, bookmarked INTEGER NOT NULL DEFAULT 0, note TEXT NOT NULL DEFAULT \'\')',
          );
          await db.execute(
            'CREATE TABLE quiz_answers (question_id TEXT PRIMARY KEY, choice INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE exercises (id TEXT PRIMARY KEY, draft TEXT NOT NULL, solved INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
      ),
    );
    // Update curriculum without replacing learner state; stable IDs are permanent.
    await db.transaction((txn) async {
      for (final content in contents) {
        await txn.insert('chapters', {
          'id': content['id'],
          'content': jsonEncode(content),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return LearningRepository(db);
  }

  Future<List<Curriculum>> chapters() async =>
      (await db.query('chapters', orderBy: 'id'))
          .map((r) => Curriculum.fromJson(jsonDecode(r['content'] as String)))
          .toList();

  Future<List<CodingProblem>> codingProblems() async {
    final catalog =
        jsonDecode(await rootBundle.loadString('assets/coding/catalog.json'))
            as Map<String, dynamic>;
    final list = <CodingProblem>[];
    for (final asset in (catalog['packs'] as List? ?? const [])) {
      final pack =
          jsonDecode(await rootBundle.loadString(asset as String))
              as Map<String, dynamic>;
      for (final item in (pack['problems'] as List? ?? const [])) {
        list.add(CodingProblem.fromJson(item as Map<String, dynamic>));
      }
    }
    list.sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  Future<List<HotQuestion>> hotQuestions() async {
    final catalog =
        jsonDecode(await rootBundle.loadString('assets/viva/catalog.json'))
            as Map<String, dynamic>;
    final list = <HotQuestion>[];
    for (final asset in (catalog['packs'] as List? ?? const [])) {
      final pack =
          jsonDecode(await rootBundle.loadString(asset as String))
              as Map<String, dynamic>;
      for (final item in (pack['questions'] as List? ?? const [])) {
        list.add(HotQuestion.fromJson(item as Map<String, dynamic>));
      }
    }
    list.sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  Future<Curriculum> curriculum({String id = 'chapter_01'}) async =>
      Curriculum.fromJson(
        jsonDecode(
          (await db.query(
                'chapters',
                where: 'id = ?',
                whereArgs: [id],
              )).single['content']
              as String,
        ),
      );
  Future<List<Map<String, Object?>>> progress() => db.query('progress');
  Future<Map<String, int>> answers() async => {
    for (final r in await db.query('quiz_answers'))
      r['question_id'] as String: r['choice'] as int,
  };
  Future<void> updateLesson(
    String id, {
    bool? completed,
    bool? bookmarked,
    String? note,
  }) async {
    await db.transaction((txn) async {
      await txn.insert('progress', {
        'lesson_id': id,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'progress',
        {
          if (completed != null) 'completed': completed ? 1 : 0,
          if (bookmarked != null) 'bookmarked': bookmarked ? 1 : 0,
          'note': ?note,
        },
        where: 'lesson_id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> answer(String id, int choice) async {
    await db.insert('quiz_answers', {
      'question_id': id,
      'choice': choice,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> resetQuiz(Iterable<String> questionIds) async {
    await db.transaction((txn) async {
      for (final id in questionIds) {
        await txn.delete(
          'quiz_answers',
          where: 'question_id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<String?> setting(String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveExercise(String id, String draft, bool solved) async {
    await db.insert('exercises', {
      'id': id,
      'draft': draft,
      'solved': solved ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>?> exercise(String id) async {
    final rows = await db.query('exercises', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.single;
  }

  Future<String> exportBackup() async {
    final progressRows = await db.query('progress', orderBy: 'lesson_id');
    final answerRows = await db.query('quiz_answers', orderBy: 'question_id');
    final exerciseRows = await db.query('exercises', orderBy: 'id');
    final settingRows = await db.query('settings', orderBy: 'key');
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'ml_path_backup_v1',
      'progress': progressRows,
      'quiz_answers': answerRows,
      'exercises': exerciseRows,
      'settings': settingRows,
    });
  }

  Future<Map<String, int>> importBackup(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'ml_path_backup_v1') {
      throw const FormatException('Invalid ML Path backup format');
    }
    final progressList = List<Map<String, dynamic>>.from(
      (decoded['progress'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final answerList = List<Map<String, dynamic>>.from(
      (decoded['quiz_answers'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final exerciseList = List<Map<String, dynamic>>.from(
      (decoded['exercises'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final settingList = List<Map<String, dynamic>>.from(
      (decoded['settings'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    await db.transaction((txn) async {
      for (final row in progressList) {
        if (row['lesson_id'] is! String) continue;
        await txn.insert('progress', {
          'lesson_id': row['lesson_id'],
          'completed': (row['completed'] as num?)?.toInt() ?? 0,
          'bookmarked': (row['bookmarked'] as num?)?.toInt() ?? 0,
          'note': row['note']?.toString() ?? '',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in answerList) {
        if (row['question_id'] is! String || row['choice'] is! num) continue;
        await txn.insert('quiz_answers', {
          'question_id': row['question_id'],
          'choice': (row['choice'] as num).toInt(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in exerciseList) {
        if (row['id'] is! String) continue;
        await txn.insert('exercises', {
          'id': row['id'],
          'draft': row['draft']?.toString() ?? '',
          'solved': (row['solved'] as num?)?.toInt() ?? 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in settingList) {
        if (row['key'] is! String || row['value'] == null) continue;
        await txn.insert('settings', {
          'key': row['key'],
          'value': row['value'].toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return {
      'progress': progressList.length,
      'quiz_answers': answerList.length,
      'exercises': exerciseList.length,
    };
  }

  Future<void> close() => db.close();
}
