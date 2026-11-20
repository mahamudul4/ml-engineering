"""Shared verification for content revisions, defaulting to Chapter 6–10."""

import contextlib
import io
import json
import math
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative):
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))


def verify(start_chapter=6, end_chapter=None):
    if end_chapter is None:
        end_chapter = start_chapter + 4
    if start_chapter < 1 or end_chapter < start_chapter:
        raise ValueError("Chapter range must be positive and ordered")
    os.chdir(ROOT)
    (ROOT / "build").mkdir(exist_ok=True)
    batch = f"{start_chapter:02}_{end_chapter:02}"
    manifest = read(f"tool/chapter_{batch}_revision_spec.json")
    assert manifest["chapters"] == list(range(start_chapter, end_chapter + 1)), batch
    chapters = {
        n: read(f"assets/content/chapter_{n:02}.json")
        for n in range(start_chapter, end_chapter + 1)
    }
    uses_torch = manifest.get("requires_torch", 15 in chapters)
    if uses_torch:
        import torch

        torch.set_num_threads(1)
    lesson_ids = {
        lesson["id"]
        for path in (ROOT / "assets/content").glob("chapter_*.json")
        for lesson in json.loads(path.read_text(encoding="utf-8"))["lessons"]
    }
    linked_interviews = 0
    for chapter in chapters.values():
        for interview in chapter["interviews"]:
            prerequisites = interview.get("prerequisiteLessons", [])
            assert set(prerequisites) <= lesson_ids, interview["title"]
            linked_interviews += bool(prerequisites)
    outputs = []
    for item in manifest["examples"]:
        lesson = next(
            value
            for value in chapters[item["chapter"]]["lessons"]
            if value["id"] == item["lesson"]
        )
        block = lesson["blocks"][item["block"]]
        capture = io.StringIO()
        with contextlib.redirect_stdout(capture):
            exec(compile(block["body"], item["id"], "exec"), {})
        actual = [float(value) for value in capture.getvalue().split()]
        assert len(actual) == len(item["expected"]), item["id"]
        assert all(
            math.isclose(a, e, rel_tol=1e-6, abs_tol=1e-6)
            for a, e in zip(actual, item["expected"])
        ), (item["id"], actual)
        outputs.append({"id": item["id"], "numbers": actual})

    solutions = 0
    for chapter in chapters.values():
        for exercise in chapter["exercises"]:
            scope, capture = {}, io.StringIO()
            with contextlib.redirect_stdout(capture):
                exec(compile(exercise["solution"], exercise["id"], "exec"), scope)
            result = (
                float(scope["answer"])
                if "answer" in scope
                else float(capture.getvalue().strip())
            )
            assert math.isclose(result, exercise["expected"], abs_tol=1e-9), exercise[
                "id"
            ]
            solutions += 1

    # Rounded values shown in the rewritten feedback must pass the actual
    # JSON tolerance contract, including small probability answers.
    rounded = manifest.get(
        "rounded_feedback",
        {
            "ch06_ex_mse": 0.3333333,
            "ch07_ex_ridge": 0.8333333,
            "ch08_ex_bayes": 0.1538462,
            "ch08_ex_beta": 0.6428571,
            "ch08_ex_wilson": 0.2775328,
            "ch08_ex_welch": 1.9604421,
            "ch09_ex_weights": 0.6666667,
            "ch10_ex_average": 0.6566667,
            "ch10_ex_ada": 0.5493061,
            "ch10_ex_gain": 0.9833333,
            "ch10_ex_ordered": 0.6666667,
        },
    )
    for chapter in chapters.values():
        for exercise in chapter["exercises"]:
            if exercise["id"] in rounded:
                tolerance = exercise.get("absoluteTolerance", 1e-9) + exercise.get(
                    "relativeTolerance", 1e-6
                ) * abs(exercise["expected"])
                assert (
                    abs(rounded[exercise["id"]] - exercise["expected"]) <= tolerance
                ), exercise["id"]

    import numpy
    import pandas
    import scipy
    import sklearn

    report = {
        "passed": True,
        "chapters": list(chapters),
        "examples": outputs,
        "exercise_solutions_executed": solutions,
        "feedback_precision_checks": len(rounded),
        "interviews_with_valid_prerequisites": linked_interviews,
        "versions": {
            "numpy": numpy.__version__,
            "pandas": pandas.__version__,
            "scipy": scipy.__version__,
            "sklearn": sklearn.__version__,
        },
    }
    if uses_torch:
        report["versions"]["torch"] = torch.__version__
    report_name = f"chapter-{start_chapter:02}-{end_chapter:02}-validation.json"
    (ROOT / "build" / report_name).write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        json.dumps(
            {key: value for key, value in report.items() if key != "examples"}, indent=2
        )
    )
    print("Executable examples", len(outputs))


if __name__ == "__main__":
    verify()
