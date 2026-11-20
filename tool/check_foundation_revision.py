"""Verify the Chapter 1–5 teaching calculations in a local QA Python environment.

Run with tool/requirements-python-qa.txt installed. Plots are written under build.
Executes the new walkthroughs and the first five chapters' exercise solutions.
"""

import contextlib
import io
import json
import math
import os
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def read(relative):
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))


def verify():
    (ROOT / "build/screenshots").mkdir(parents=True, exist_ok=True)
    spec = read("tool/foundation_revision_spec.json")
    chapters = {n: read(f"assets/content/chapter_{n:02}.json") for n in range(1, 6)}
    scopes = {}
    examples = []
    for item in spec["examples"]:
        chapter = chapters[item["chapter"]]
        lesson = next(
            value for value in chapter["lessons"] if value["id"] == item["lesson"]
        )
        body = lesson["blocks"][item["block"]]["body"]
        scope = dict(scopes[item["setup"]]) if "setup" in item else {}
        capture = io.StringIO()
        # The plot backend is selected only by this headless verifier.
        os.environ["MPLBACKEND"] = "Agg"
        previous = Path.cwd()
        with tempfile.TemporaryDirectory(prefix="ml_foundation_") as folder:
            try:
                os.chdir(folder)
                with contextlib.redirect_stdout(capture):
                    exec(compile(body, item["id"], "exec"), scope)
                if item["id"] == "ch02_residual_plot":
                    source = Path("diabetes_residuals.png")
                    assert source.stat().st_size > 10000
                    (ROOT / "build/screenshots/diabetes-residuals.png").write_bytes(
                        source.read_bytes()
                    )
            finally:
                os.chdir(previous)
        if item["expected"] is not None:
            values = [float(value) for value in capture.getvalue().split()]
            assert len(values) == len(item["expected"]), item["id"]
            assert all(
                math.isclose(value, expected, abs_tol=1e-6, rel_tol=1e-6)
                for value, expected in zip(values, item["expected"])
            ), item["id"]
        scopes[item["id"]] = scope
        examples.append({"id": item["id"], "output": capture.getvalue().strip()})

    real = scopes["ch02_real_regression"]
    import numpy as np
    import sklearn
    import matplotlib

    assert real["real_X"].shape == (442, 10)
    assert len(real["real_train_y"]) == 353 and len(real["real_val_y"]) == 89
    assert all(math.isfinite(value) for value in real["real_scores"].values())
    assert real["real_winner"] == min(real["real_scores"], key=real["real_scores"].get)
    prepared_training = real["real_model"][:-1].transform(real["real_train_X"])
    assert np.allclose(prepared_training.mean(axis=0), 0, atol=1e-12)

    # The actual source function must compute its denominator once, including
    # nonuniform logits. A constant-output shortcut would fail these assertions.
    softmax_lesson = next(
        value for value in chapters[3]["lessons"] if value["id"] == "ch03_multiclass"
    )
    body = next(
        block["body"]
        for block in softmax_lesson["blocks"]
        if block.get("type") == "code"
    )
    namespace = {}
    with contextlib.redirect_stdout(io.StringIO()):
        exec(body, namespace)
    visits = []

    def tracked_sum(values):
        visits.append(len(values))
        return sum(values)

    namespace["sum"] = tracked_sum
    probabilities = namespace["softmax"]([float(value) for value in range(100)])
    assert visits == [100]
    assert math.isclose(sum(probabilities), 1) and probabilities[-1] > probabilities[0]
    assert namespace["softmax"]([2.0, 3.0]) == namespace["softmax"]([1002.0, 1003.0])

    split = next(
        value for value in chapters[1]["lessons"] if value["id"] == "training_testing"
    )
    namespace = {}
    with contextlib.redirect_stdout(io.StringIO()):
        exec(
            next(
                block["body"]
                for block in split["blocks"]
                if block.get("type") == "code"
            ),
            namespace,
        )
    assert [len(namespace[name]) for name in ["X_train", "X_val", "X_test"]] == [
        309,
        66,
        67,
    ]
    assert np.array_equal(
        namespace["model"][0].mean_, namespace["X_train"].mean(axis=0)
    )

    solutions = 0
    for chapter in chapters.values():
        for exercise in chapter["exercises"]:
            output, namespace = io.StringIO(), {}
            with contextlib.redirect_stdout(output):
                exec(exercise["solution"], namespace)
            if exercise["id"] == "ch02_ex_metrics":
                result = namespace["evaluate"]([3, 6, 9], [2, 4, 8])[2]
            else:
                result = float(output.getvalue().strip())
            assert math.isclose(result, exercise["expected"], abs_tol=1e-9), exercise[
                "id"
            ]
            solutions += 1

    counts = {
        key: sum(len(chapter[key]) for chapter in chapters.values())
        for key in ["lessons", "quizzes", "exercises", "interviews"]
    }
    report = {
        "passed": True,
        "chapters": 5,
        **counts,
        "examples": examples,
        "exercise_solutions_executed": solutions,
        "softmax_elements_summed_for_100_classes": 100,
        "versions": {
            "numpy": np.__version__,
            "sklearn": sklearn.__version__,
            "matplotlib": matplotlib.__version__,
        },
    }
    (ROOT / "build/foundation-validation.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        json.dumps(
            {key: value for key, value in report.items() if key != "examples"}, indent=2
        )
    )


if __name__ == "__main__":
    verify()
