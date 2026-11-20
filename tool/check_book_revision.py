"""Audit the offline book, execute new examples, and verify compatibility.

Python 3.12+, standard library only. Optional --fonts needs fontTools (the
existing build/font-qa folder is supported); --package needs Android build-tools.
No training, network calls or newly scored held-out outcomes are involved.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import math
import os
import re
from pathlib import Path
import subprocess
import sys
import unicodedata
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def ast_hash(code: str) -> str:
    tree = ast.dump(ast.parse(code), include_attributes=False)
    return hashlib.sha256(tree.encode()).hexdigest()


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def run_numbers(code: str, name: str) -> list[float]:
    # Isolate standalone examples so their globals cannot influence each other.
    result = subprocess.run(
        [sys.executable, "-X", "utf8", "-c", code],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=10,
        check=True,
    )
    try:
        return [float(value) for value in result.stdout.split()]
    except ValueError as error:
        raise AssertionError(
            f"Non-numeric output in {name}: {result.stdout}"
        ) from error


def audit_book():
    spec = read(ROOT / "tool/book_revision_spec.json")
    compatibility = read(ROOT / "tool/book_revision_compatibility.json")
    revisions = read(ROOT / "tool/foundation_revision_spec.json")["code_revisions"]
    catalog = read(ROOT / "assets/content/catalog.json")
    chapters = [read(ROOT / path) for path in catalog["chapters"]]
    by_id = {chapter["id"]: chapter for chapter in chapters}
    require(
        len(chapters) == len(by_id) == len(spec["order"]),
        "Catalog must match the planned chapter count with unique IDs",
    )
    ordered = sorted(chapters, key=lambda chapter: chapter["book"]["order"])
    require(
        [chapter["number"] for chapter in ordered] == spec["order"], "Reading order"
    )
    seen = set()
    all_ids = []
    code_count = 0
    for chapter in ordered:
        book = chapter["book"]
        require(book["purpose"] and len(book["outcomes"]) >= 2, chapter["id"])
        require(book["part"] == spec["parts"][str(chapter["number"])],
                f"Wrong book part: {chapter['id']}")
        require(
            set(book["prerequisites"]) <= seen,
            f"Prerequisite cycle/order: {chapter['id']}",
        )
        seen.add(chapter["id"])
        for lesson in chapter["lessons"]:
            all_ids.append(lesson["id"])
            for block in lesson["blocks"]:
                if block.get("type") == "code":
                    ast.parse(block["body"])
                    code_count += 1
                if block.get("type") == "checkpoint":
                    require(
                        block.get("solution") and block.get("reference"), lesson["id"]
                    )
        for quiz in chapter["quizzes"]:
            all_ids.append(quiz["id"])
            require(0 <= quiz["answer"] < len(quiz["options"]), quiz["id"])
            require(quiz["explanation"], quiz["id"])
        for exercise in chapter["exercises"]:
            all_ids.append(exercise["id"])
            ast.parse(exercise["solution"])
        for question in chapter["interviews"]:
            require(
                question["title"] and question["prompt"] and question["answer"],
                chapter["id"],
            )
    require(len(all_ids) == len(set(all_ids)), "Global learner IDs collide")
    lesson_ids = {lesson["id"] for chapter in chapters for lesson in chapter["lessons"]}
    for chapter in chapters:
        for question in chapter["interviews"]:
            require(set(question.get("prerequisiteLessons", [])) <= lesson_ids,
                    f"Unknown interview prerequisite: {question['title']}")

    old_code = old_solutions = revised_code = 0
    for chapter_id, previous in compatibility["chapters"].items():
        chapter = by_id[chapter_id]
        lessons = {lesson["id"]: lesson for lesson in chapter["lessons"]}
        require(set(previous["lesson_ids"]) <= lessons.keys(), chapter_id)
        # Original relative order stays intact, even with inserted bridge lessons.
        old_order = [
            lesson["id"]
            for lesson in chapter["lessons"]
            if lesson["id"] in previous["lesson_ids"]
        ]
        require(
            old_order == previous["lesson_ids"], f"Legacy order changed: {chapter_id}"
        )
        answers = {q["id"]: q["answer"] for q in chapter["quizzes"]}
        require(
            all(answers.get(key) == value for key, value in previous["quiz_answers"].items()),
            f"Saved quiz choices changed: {chapter_id}",
        )
        exercises = {exercise["id"]: exercise for exercise in chapter["exercises"]}
        require(
            all(exercises[key]["expected"] == value
                for key, value in previous["exercise_results"].items()),
            chapter_id,
        )
        for key, expected in previous["code_ast"].items():
            lesson_id, block_index = key.rsplit(":", 1)
            current = ast_hash(lessons[lesson_id]["blocks"][int(block_index)]["body"])
            if key in revisions:
                revision = revisions[key]
                require(expected == revision["before"], f"Original baseline: {key}")
                require(current == revision["after"] and revision["reason"], key)
                revised_code += 1
            else:
                require(current == expected, key)
                old_code += 1
        for exercise_id, expected in previous["exercise_ast"].items():
            require(
                ast_hash(exercises[exercise_id]["solution"]) == expected, exercise_id
            )
            old_solutions += 1
    for relative, expected in compatibility["assets"].items():
        require(
            hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == expected,
            relative,
        )

    for item in spec["lessons"]:
        chapter = by_id[f"chapter_{item['chapter']:02}"]
        lesson = next(
            lesson for lesson in chapter["lessons"] if lesson["id"] == item["lesson"]
        )
        code = next(
            block["body"] for block in lesson["blocks"] if block.get("type") == "code"
        )
        actual = run_numbers(code, item["lesson"])
        require(len(actual) == len(item["expected"]), item["lesson"])
        require(
            all(
                math.isclose(a, e, rel_tol=1e-6, abs_tol=1e-7)
                for a, e in zip(actual, item["expected"])
            ),
            f"{item['lesson']}: {actual}",
        )
        if "before" in item:
            ids = [lesson["id"] for lesson in chapter["lessons"]]
            require(
                ids.index(item["lesson"]) < ids.index(item["before"]), item["lesson"]
            )
    checked_exercises = list(by_id["chapter_41"]["exercises"])
    for item in spec.get("exerciseChecks", []):
        chapter = by_id[f"chapter_{item['chapter']:02}"]
        checked_exercises.append(next(
            exercise for exercise in chapter["exercises"] if exercise["id"] == item["id"]
        ))
    for exercise in checked_exercises:
        actual = run_numbers(exercise["solution"], exercise["id"])
        require(
            len(actual) == 1
            and math.isclose(actual[0], exercise["expected"], abs_tol=1e-9),
            exercise["id"],
        )

    return dict(
        passed=True,
        chapters=len(chapters),
        lessons=sum(len(ch["lessons"]) for ch in chapters),
        quizzes=sum(len(ch["quizzes"]) for ch in chapters),
        exercises=sum(len(ch["exercises"]) for ch in chapters),
        interviews=sum(len(ch["interviews"]) for ch in chapters),
        new_walkthroughs_executed=len(spec["lessons"]),
        new_exercise_solutions_executed=len(checked_exercises),
        all_code_blocks_parsed=code_count,
        legacy_walkthrough_asts_unchanged=old_code,
        intentionally_revised_legacy_walkthroughs=revised_code,
        legacy_solution_asts_unchanged=old_solutions,
        original_data_and_font_files_unchanged=len(compatibility["assets"]),
        newly_scored_reserved_outcomes=0,
    )


def check_fonts():
    sys.path.insert(0, str(ROOT / "build/font-qa"))
    from fontTools.ttLib import TTFont

    covered = set()
    for path in (ROOT / "assets/fonts").glob("*.ttf"):
        with TTFont(path) as font:
            covered.update(font.getBestCmap())
    paths = list((ROOT / "assets/content").glob("*.json"))
    paths += list((ROOT / "assets/coding").glob("*.json"))
    paths += list((ROOT / "lib/features/book").glob("*.dart"))
    paths += list((ROOT / "lib/features/coding").glob("*.dart"))
    paths += list((ROOT / "lib/features/reinforcement").glob("*.dart"))
    chars = {
        ord(char)
        for path in paths
        for char in path.read_text(encoding="utf-8")
        if ord(char) > 127 and unicodedata.category(char) not in {"Cc", "Cf"}
    }
    missing = sorted(chars - covered)
    require(not missing, f"Missing glyphs: {[(hex(c), chr(c)) for c in missing]}")
    return dict(checked_files=len(paths), non_ascii_codepoints=len(chars), missing=[])


def check_package():
    apk = ROOT / "build/app/outputs/flutter-apk/app-release.apk"
    sdk = Path(os.environ.get("ANDROID_HOME", os.environ.get("ANDROID_SDK_ROOT", "")))
    aapt = sorted((sdk / "build-tools").glob("*/aapt.exe"))[-1]
    badging = subprocess.check_output(
        [str(aapt), "dump", "badging", str(apk)], text=True
    )
    require("name='dev.mlpath.ml_path'" in badging, "APK application ID")
    # Validate the artifact against this release rather than a stale version.
    declared = re.search(
        r"^version:\s*([0-9.]+)\+(\d+)\s*$",
        (ROOT / "pubspec.yaml").read_text(encoding="utf-8"),
        re.MULTILINE,
    )
    require(declared is not None, "Declared app version")
    require(
        f"versionCode='{declared[2]}'" in badging
        and f"versionName='{declared[1]}'" in badging,
        "APK version",
    )
    permissions = subprocess.check_output(
        [str(aapt), "dump", "permissions", str(apk)], text=True
    )
    require(
        "android.permission.INTERNET" not in permissions, "Release network permission"
    )
    catalog = read(ROOT / "assets/content/catalog.json")
    coding_catalog = read(ROOT / "assets/coding/catalog.json")
    data = read(ROOT / "tool/book_revision_compatibility.json")["assets"]
    paths = [
        "assets/content/catalog.json",
        *catalog["chapters"],
        "assets/coding/catalog.json",
        *coding_catalog.get("packs", []),
        *data.keys(),
    ]
    with zipfile.ZipFile(apk) as package:
        font_manifest = json.loads(package.read('assets/flutter_assets/FontManifest.json'))
        require({'Manrope', 'NotoSansBengali', 'NotoSansMath', 'NotoSans'} <=
                {entry['family'] for entry in font_manifest}, 'Bundled font families')
        for relative in paths:
            require(
                package.read("assets/flutter_assets/" + relative)
                == (ROOT / relative).read_bytes(),
                relative,
            )
    return dict(
        version=f"{declared[1]}+{declared[2]}",
        byte_matched_files=len(paths),
        internet_permission=False,
        apk_bytes=apk.stat().st_size,
        sha256=hashlib.sha256(apk.read_bytes()).hexdigest(),
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fonts", action="store_true")
    parser.add_argument("--package", action="store_true")
    args = parser.parse_args()
    report = audit_book()
    if args.fonts:
        report["fonts"] = check_fonts()
    if args.package:
        report["package"] = check_package()
    (ROOT / "build/book-code-verification.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, indent=2))
