"""Validate the bundled Python examples in a development Python environment.

Requires numpy and scikit-learn; these are NOT app/runtime dependencies.
"""
import contextlib
import io
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
chapter = json.loads((ROOT / "assets/content/chapter_02.json").read_text(encoding="utf-8"))
for lesson in chapter["lessons"]:
    for block in lesson["blocks"]:
        if block.get("type") == "code":
            compile(block["body"], lesson["id"], "exec")
for exercise in chapter["exercises"]:
    compile(exercise["starter"], exercise["id"], "exec")
    compile(exercise["solution"], exercise["id"], "exec")

workflow = next(l for l in chapter["lessons"] if l["id"] == "ch02_workflow")
namespace = {}
with contextlib.redirect_stdout(io.StringIO()):
    for block in workflow["blocks"]:
        if block.get("type") == "code":
            exec(block["body"], namespace)
assert len(namespace["X_train"]) == 210
assert len(namespace["X_val"]) == len(namespace["X_test"]) == 45
mae = namespace["mean_absolute_error"](namespace["y_test"], namespace["pred"])
baseline_mae = namespace["mean_absolute_error"](namespace["y_test"], namespace["baseline"])
assert math.isfinite(mae) and mae < baseline_mae

# The CV snippet intentionally expects an already-split training partition.
ridge = next(l for l in chapter["lessons"] if l["id"] == "ch02_regularization")
with contextlib.redirect_stdout(io.StringIO()):
    exec(next(b["body"] for b in ridge["blocks"] if b.get("type") == "code"), namespace)

for lesson in chapter["lessons"]:
    if lesson["id"] in ("ch02_regularization", "ch02_workflow"):
        continue
    local = {}
    with contextlib.redirect_stdout(io.StringIO()):
        for block in lesson["blocks"]:
            if block.get("type") == "code":
                exec(block["body"], local)
    if lesson["id"] == "ch02_evaluation":
        assert math.isclose(local["metrics"]([3,6,9], [2,4,8])["r2"], 2/3)
for exercise in chapter["exercises"]:
    local = {}
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        exec(exercise["solution"], local)
    if exercise["id"] == "ch02_ex_metrics":
        result = local["evaluate"]([3,6,9], [2,4,8])[2]
    else:
        result = float(output.getvalue().strip())
    assert math.isclose(result, exercise["expected"], abs_tol=1e-9), exercise["id"]
print("PASS: all Chapter 2 snippets compile; runnable examples, CV, workflow, and exercise solutions execute correctly.")
print("Test MAE:", round(mae, 4), "Baseline MAE:", round(baseline_mae, 4))
