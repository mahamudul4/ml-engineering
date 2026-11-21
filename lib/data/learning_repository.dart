import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/coding_problem.dart';
import '../models/curriculum.dart';
import '../models/hot_question.dart';

/// All curriculum and learner data live in SQLite on mobile/desktop,
/// with an automatic in-memory fallback on Flutter Web for live browser preview.
class LearningRepository {
  final Database? _db;
  final Map<String, Map<String, dynamic>>? _webChapters;
  final Map<String, Map<String, Object?>> _webProgress = {};
  final Map<String, int> _webAnswers = {};
  final Map<String, Map<String, Object?>> _webExercises = {};
  final Map<String, String> _webSettings = {};

  LearningRepository(Database db) : _db = db, _webChapters = null;

  LearningRepository._web(Map<String, Map<String, dynamic>> chapters)
    : _db = null,
      _webChapters = chapters;

  bool get _isWebStore => _db == null;
  Database get db => _db!;

  static Future<LearningRepository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final catalog =
        jsonDecode(await rootBundle.loadString('assets/content/catalog.json'))
            as Map<String, dynamic>;
    final contents = <Map<String, dynamic>>[];
    for (final asset in catalog['chapters'] as List) {
      contents.add(
        jsonDecode(await rootBundle.loadString(asset as String))
            as Map<String, dynamic>,
      );
    }
    if (kIsWeb && factory == null) {
      return LearningRepository._web({
        for (final content in contents) content['id'] as String: content,
      });
    }
    final f = factory ?? databaseFactory;
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

  Future<List<Curriculum>> chapters() async {
    if (_isWebStore) {
      final ids = _webChapters!.keys.toList()..sort();
      return ids.map((id) => Curriculum.fromJson(_webChapters[id]!)).toList();
    }
    return (await _db!.query('chapters', orderBy: 'id'))
        .map((r) => Curriculum.fromJson(jsonDecode(r['content'] as String)))
        .toList();
  }

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

  Future<Curriculum> curriculum({String id = 'chapter_01'}) async {
    if (_isWebStore) {
      return Curriculum.fromJson(_webChapters![id]!);
    }
    return Curriculum.fromJson(
      jsonDecode(
        (await _db!.query(
              'chapters',
              where: 'id = ?',
              whereArgs: [id],
            )).single['content']
            as String,
      ),
    );
  }

  Future<List<Map<String, Object?>>> progress() async {
    if (_isWebStore) {
      return _webProgress.values.map((r) => Map<String, Object?>.from(r)).toList();
    }
    return _db!.query('progress');
  }

  Future<Map<String, int>> answers() async {
    if (_isWebStore) {
      return Map<String, int>.from(_webAnswers);
    }
    return {
      for (final r in await _db!.query('quiz_answers'))
        r['question_id'] as String: r['choice'] as int,
    };
  }

  Future<void> updateLesson(
    String id, {
    bool? completed,
    bool? bookmarked,
    String? note,
  }) async {
    if (_isWebStore) {
      final row = _webProgress.putIfAbsent(
        id,
        () => {'lesson_id': id, 'completed': 0, 'bookmarked': 0, 'note': ''},
      );
      if (completed != null) row['completed'] = completed ? 1 : 0;
      if (bookmarked != null) row['bookmarked'] = bookmarked ? 1 : 0;
      if (note != null) row['note'] = note;
      return;
    }
    await _db!.transaction((txn) async {
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
    if (_isWebStore) {
      _webAnswers[id] = choice;
      return;
    }
    await _db!.insert('quiz_answers', {
      'question_id': id,
      'choice': choice,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> resetQuiz(Iterable<String> questionIds) async {
    if (_isWebStore) {
      for (final id in questionIds) {
        _webAnswers.remove(id);
      }
      return;
    }
    await _db!.transaction((txn) async {
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
    if (_isWebStore) return _webSettings[key];
    final rows = await _db!.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    if (_isWebStore) {
      _webSettings[key] = value;
      return;
    }
    await _db!.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveExercise(String id, String draft, bool solved) async {
    if (_isWebStore) {
      _webExercises[id] = {'id': id, 'draft': draft, 'solved': solved ? 1 : 0};
      return;
    }
    await _db!.insert('exercises', {
      'id': id,
      'draft': draft,
      'solved': solved ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>?> exercise(String id) async {
    if (_isWebStore) {
      final row = _webExercises[id];
      return row == null ? null : Map<String, Object?>.from(row);
    }
    final rows = await _db!.query('exercises', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.single;
  }

  Future<String> exportBackup() async {
    if (_isWebStore) {
      final progressRows = _webProgress.values.toList()
        ..sort((a, b) => (a['lesson_id'] as String).compareTo(b['lesson_id'] as String));
      final answerRows = [
        for (final k in _webAnswers.keys.toList()..sort())
          {'question_id': k, 'choice': _webAnswers[k]},
      ];
      final exerciseRows = _webExercises.values.toList()
        ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      final settingRows = [
        for (final k in _webSettings.keys.toList()..sort())
          {'key': k, 'value': _webSettings[k]},
      ];
      return const JsonEncoder.withIndent('  ').convert({
        'format': 'ml_path_backup_v1',
        'progress': progressRows,
        'quiz_answers': answerRows,
        'exercises': exerciseRows,
        'settings': settingRows,
      });
    }
    final progressRows = await _db!.query('progress', orderBy: 'lesson_id');
    final answerRows = await _db.query('quiz_answers', orderBy: 'question_id');
    final exerciseRows = await _db.query('exercises', orderBy: 'id');
    final settingRows = await _db.query('settings', orderBy: 'key');
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
    if (_isWebStore) {
      for (final row in progressList) {
        if (row['lesson_id'] is! String) continue;
        _webProgress[row['lesson_id'] as String] = {
          'lesson_id': row['lesson_id'],
          'completed': (row['completed'] as num?)?.toInt() ?? 0,
          'bookmarked': (row['bookmarked'] as num?)?.toInt() ?? 0,
          'note': row['note']?.toString() ?? '',
        };
      }
      for (final row in answerList) {
        if (row['question_id'] is! String || row['choice'] is! num) continue;
        _webAnswers[row['question_id'] as String] = (row['choice'] as num).toInt();
      }
      for (final row in exerciseList) {
        if (row['id'] is! String) continue;
        _webExercises[row['id'] as String] = {
          'id': row['id'],
          'draft': row['draft']?.toString() ?? '',
          'solved': (row['solved'] as num?)?.toInt() ?? 0,
        };
      }
      for (final row in settingList) {
        if (row['key'] is! String || row['value'] == null) continue;
        _webSettings[row['key'] as String] = row['value'].toString();
      }
      return {
        'progress': progressList.length,
        'quiz_answers': answerList.length,
        'exercises': exerciseList.length,
      };
    }
    await _db!.transaction((txn) async {
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

  Future<void> close() async {
    if (!_isWebStore) await _db!.close();
  }
}
