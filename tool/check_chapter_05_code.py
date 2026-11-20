"""Execute Chapter 5 lesson code/solutions and verify the real-data experiment.

Run with local numpy, pandas and scikit-learn installed. No network access.
"""
import contextlib
import hashlib
import io
import json
import math
from pathlib import Path
import runpy
import os
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
chapter = json.loads((ROOT / 'assets/content/chapter_05.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons', 'quizzes', 'interviews', 'exercises']] == [12, 16, 8, 6]
data = ROOT / 'assets/datasets/adult'
expected_hashes = {
    'adult.data': '5b00264637dbfec36bdeaab5676b0b309ff9eb788d63554ca0a249491c86603d',
    'adult.test': 'a2a9044bc167a35b2361efbabec64e89d69ce82d9790d2980119aac5fd7e9c05',
    'adult.names': 'c248284c0b5de30c9e1958d6cdd168a34a654758b620e68f46aefa83fc0a576a',
}
for filename, expected in expected_hashes.items():
    assert hashlib.sha256((data / filename).read_bytes()).hexdigest() == expected
for lesson in chapter['lessons']:
    scope = {}
    for block in lesson['blocks']:
        if block['type'] == 'code':
            compile(block['body'], lesson['id'], 'exec')
            with contextlib.redirect_stdout(io.StringIO()):
                exec(block['body'], scope)
    if lesson['id'] == 'ch05_workflow':
        experiment = scope
report = experiment['report']
assert report['development_rows'] == 32561
assert report['evaluated_test_rows'] == 16255
assert report['excluded_overlap'] == 26
assert len(report['outer_folds']) == 3
assert sum(r['validation_rows'] for r in report['outer_folds']) == 32561
assert len(report['selection_candidates']) == 3
assert report['final_C'] in [0.1, 1.0, 10.0]
assert all(math.isfinite(r['log_loss']) for r in report['outer_folds'])
assert math.isclose(report['paired_loss_gain']['estimate'],
    report['baseline_log_loss'] - report['test_log_loss'], abs_tol=1e-12)
assert sum(r['rows'] for r in report['predeclared_slices']) == 16255
# The last outer model's imputer must use only its outer-training rows.
outer_train = experiment['X'].iloc[experiment['train_idx']]
expected_medians = outer_train[experiment['NUMERIC']].median().to_numpy()
fitted = experiment['search'].best_estimator_['prepare'].named_transformers_['numeric']['impute']
assert np.allclose(fitted.statistics_, expected_medians)
# Audit every inner split's groups (including final all-development search).
X, y, groups = experiment['X'], experiment['y'], experiment['groups']
for tr, va in experiment['make_search']().cv.split(X, y, groups):
    assert set(groups[tr]).isdisjoint(set(groups[va]))
interval = experiment['cluster_interval']
assert math.isclose(interval([1, 1, 0], [10, 10, 20])['estimate'], 2/3)
point = interval([.25, .25, .25], [1, 1, 2])
assert point['percentile_95'] == [.25, .25]
for differences, ids in [([1, 2], [1]), ([float('nan'), 1], [1, 2]), ([1, 2], [1, 1])]:
    try:
        interval(differences, ids)
    except ValueError:
        pass
    else:
        raise AssertionError('Invalid cluster inputs accepted')
for exercise in chapter['exercises']:
    compile(exercise['starter'], exercise['id'], 'exec')
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        exec(exercise['solution'], {})
    assert math.isclose(float(output.getvalue().strip()), exercise['expected'], abs_tol=1e-10)
with contextlib.redirect_stdout(io.StringIO()):
    standalone = runpy.run_path(str(data / 'evaluation_workflow.py'))
assert standalone['report'] == report
(ROOT / 'build/chapter-05-python-verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('PASS: All Chapter 5 code, six solutions, hashes, nested groups, train-only statistics, bootstrap and standalone agreement.')
print('Outer mean loss:', round(report['outer_mean_log_loss'], 6), 'External loss:', round(report['test_log_loss'], 6))
