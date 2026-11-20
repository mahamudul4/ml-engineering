"""Execute bundled classification examples in a dev environment (not the app).

Requires numpy and scikit-learn. See README for separate external execution.
"""
import contextlib
import io
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
d=json.loads((ROOT/"assets/content/chapter_03.json").read_text(encoding="utf-8"))
for lesson in d["lessons"]:
    for block in lesson["blocks"]:
        if block.get("type")=="code":
            compile(block["body"],lesson["id"],"exec")
    if lesson["id"]=="ch03_workflow":
        continue
    scope={}
    with contextlib.redirect_stdout(io.StringIO()):
        for block in lesson["blocks"]:
            if block.get("type")=="code":
                exec(block["body"],scope)
    if lesson["id"]=="ch03_logistic":
        assert scope["sigmoid"](0)==.5 and scope["sigmoid"](-1000)==0
    if lesson["id"]=="ch03_multiclass":
        assert math.isclose(sum(scope["softmax"]([1000,1000,1000])),1)
workflow=next(l for l in d["lessons"] if l["id"]=="ch03_workflow")
scope={}
with contextlib.redirect_stdout(io.StringIO()):
    for block in workflow["blocks"]:
        if block.get("type")=="code":
            exec(block["body"],scope)
assert len(scope["X_train"])==124
assert len(scope["X_val"])==len(scope["X_test"])==27
assert scope["X"].shape == (178, 13)
assert int(scope["y"].sum()) == 59
assert .1<=scope["threshold"]<=.9
f1=scope["f1_score"](scope["y_test"],scope["test_pred"],zero_division=0)
assert math.isfinite(f1) and f1>0
for exercise in d["exercises"]:
    compile(exercise["starter"],exercise["id"],"exec")
    capture=io.StringIO()
    with contextlib.redirect_stdout(capture):
        exec(exercise["solution"],{})
    assert math.isclose(float(capture.getvalue().strip()),exercise["expected"],abs_tol=1e-9)
print("PASS: all Chapter 3 examples and reference solutions compile and execute.")
print("Validation-selected threshold:",scope["threshold"],"Test F1:",round(f1,4))
