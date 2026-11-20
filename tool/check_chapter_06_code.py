"""Execute the Chapter 6 curriculum, solutions, semantic fixtures and real audit.

Run using local numpy/pandas: python tool/check_chapter_06_code.py
"""
import contextlib
import io
import json
import math
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import types
import unittest
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
SOURCE = ROOT / 'assets/datasets/adult/python_workflow.py'
chapter = json.loads((ROOT / 'assets/content/chapter_06.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons', 'quizzes', 'interviews', 'exercises']] == [14, 18, 8, 8]
scopes = {}
for lesson in chapter['lessons']:
    module = types.ModuleType(lesson['id'])
    sys.modules[lesson['id']] = module
    for block in lesson['blocks']:
        if block['type'] == 'code':
            with contextlib.redirect_stdout(io.StringIO()):
                exec(compile(block['body'], lesson['id'], 'exec'), module.__dict__)
    scopes[lesson['id']] = module.__dict__
solutions = {}
for exercise in chapter['exercises']:
    compile(exercise['starter'], exercise['id'], 'exec')
    output = io.StringIO()
    scope = {}
    with contextlib.redirect_stdout(output):
        exec(exercise['solution'], scope)
    assert math.isclose(float(output.getvalue().strip()), exercise['expected'], abs_tol=1e-10), exercise['id']
    solutions[exercise['id']] = scope

# Importing must not execute I/O-heavy main or print a report.
captured = io.StringIO()
with contextlib.redirect_stdout(captured):
    module_scope = runpy.run_path(str(SOURCE))
assert captured.getvalue() == ''
workflow = scopes['ch06_workflow']

class WorkflowTests(unittest.TestCase):
    def test_online_moments_and_chunk_partitions(self):
        values = np.array([1., 2., 3., 9., 10.])
        for sizes in [[5], [2, 3], [1, 1, 1, 1, 1]]:
            state = module_scope['OnlineMoments']()
            start = 0
            for size in sizes:
                state.update(values[start:start+size]); start += size
            self.assertEqual(state.count, len(values))
            self.assertAlmostEqual(state.mean, float(values.mean()))
            self.assertAlmostEqual(state.summary()['population_variance'], float(values.var()))
        empty = module_scope['OnlineMoments']()
        empty.update(np.array([]))
        self.assertIsNone(empty.summary()['mean'])
        before = (state.count, state.mean, state.m2)
        with self.assertRaises(ValueError): state.update(np.array([np.inf]))
        self.assertEqual(before, (state.count, state.mean, state.m2))

    def test_schema_and_input_ownership(self):
        frame = pd.read_csv(SOURCE.parent/'adult.data', names=module_scope['COLUMNS'],
                            header=None, skipinitialspace=True, na_values='?', nrows=5)
        original = frame.copy()
        clean = module_scope['validate_frame'](frame)
        pd.testing.assert_frame_equal(frame, original)
        matrix = module_scope['numeric_matrix'](clean)
        self.assertEqual(matrix.shape, (5, 5))
        self.assertEqual(matrix.dtype, np.dtype('float64'))
        matrix[0,0] = -999
        self.assertNotEqual(clean.iloc[0]['age'], -999)
        for column, bad in [('age', np.inf), ('age', 130), ('income', 'bad')]:
            broken = frame.copy(); broken[column] = broken[column].astype(object)
            broken.loc[0, column] = bad
            with self.assertRaises(ValueError): module_scope['validate_frame'](broken)
        with self.assertRaises(ValueError): module_scope['validate_frame'](frame.iloc[:, ::-1])
        with self.assertRaises(ValueError): module_scope['numeric_matrix'](clean, ('age','age'))

    def test_safe_merge_rejects_bad_cardinality_coverage_and_identity(self):
        rows = pd.DataFrame({'source_row':[0,1,2], 'workclass':['A','B','A']})
        lookup = pd.DataFrame({'workclass':['A','B'], 'source_count':[2,1]})
        attach = module_scope['attach_audit_counts']
        joined = attach(rows, lookup)
        self.assertEqual(joined['source_count'].tolist(), [2,1,2])
        with self.assertRaises(pd.errors.MergeError): attach(rows, pd.concat([lookup, lookup]))
        with self.assertRaises(ValueError): attach(rows, lookup.iloc[:1])
        repeated = rows.copy(); repeated.loc[1,'source_row'] = 0
        with self.assertRaises(ValueError): attach(repeated, lookup)
        missing = rows.copy(); missing.loc[0,'workclass'] = None
        with self.assertRaises(ValueError): attach(missing, lookup)

    def test_generator_laziness_and_exhaustion(self):
        batches = scopes['ch06_iterators']['batches']
        with self.assertRaises(ValueError): list(batches([], 0))
        with self.assertRaises(ValueError): list(batches([], True))
        self.assertEqual(list(batches([], 3)), [])
        source = batches(range(10), 3)
        self.assertEqual([len(v) for v in source], [3,3,3,1])
        self.assertEqual(list(source), [])
        self.assertEqual([len(v) for v in batches(range(10),3,drop_last=True)], [3,3,3])

    def test_exercise_solutions_reject_semantic_failures(self):
        mse = solutions['ch06_ex_mse']['mse']
        for p,y in [([[1],[2]],[1,2]), ([],[]), ([1,np.nan],[1,2])]:
            with self.assertRaises(ValueError): mse(p,y)
        self.assertEqual(mse([1,2],[1,2]), 0)
        unique = solutions['ch06_ex_dedup']['unique_in_order']
        self.assertEqual(unique([3,1,3,2,1]), [3,1,2])
        finite = solutions['ch06_ex_mean']['finite_mean']
        with self.assertRaises(ValueError): finite([])
        with self.assertRaises(ValueError): finite([np.nan])

    def test_numpy_lab_matches_reference_cases(self):
        self.assertEqual(np.broadcast_shapes((0,3),(1,3)), (0,3))
        np.testing.assert_array_equal(np.arange(1,4).reshape(3,1)+np.array([10,20,30]),
                                     [[11,21,31],[12,22,32],[13,23,33]])
        with self.assertRaises(ValueError): np.broadcast_shapes((3,), (2,))

suite = unittest.defaultTestLoader.loadTestsFromTestCase(WorkflowTests)
result = unittest.TextTestRunner(verbosity=2).run(suite)
assert result.wasSuccessful()
full = pd.read_csv(SOURCE.parent/'adult.data', names=module_scope['COLUMNS'], header=None,
                   skipinitialspace=True, na_values='?')
reports = [module_scope['audit_file'](SOURCE.parent/'adult.data', size) for size in [127,1024,2048]]
for report in reports:
    assert report['rows'] == 32561
    assert report['labels'] == {'<=50K':24720, '>50K':7841}
    assert report['missing']['occupation'] == 1843
    assert report['missing']['workclass'] == 1836
    assert report['missing']['native_country'] == 583
    assert report['retained_inspection_rows'] == 12
    assert report['max_matrix_payload_bytes'] <= report['chunk_size'] * 5 * 8
    for name in module_scope['NUMERIC']:
        values = pd.to_numeric(full[name]).dropna().to_numpy(dtype=float)
        np.testing.assert_allclose(report['numeric'][name]['mean'], values.mean(), rtol=1e-12, atol=1e-9)
        np.testing.assert_allclose(report['numeric'][name]['population_variance'], values.var(), rtol=1e-12, atol=1e-8)
    assert report['labels'] == reports[0]['labels'] and report['missing'] == reports[0]['missing']
lesson_report = workflow['audit_file'](SOURCE.parent/'adult.data',1024)
assert lesson_report == reports[1]
with tempfile.TemporaryDirectory() as folder:
    output = Path(folder)/'report.json'
    completed = subprocess.run([sys.executable,str(SOURCE),'--output',str(output)],check=True,
                               capture_output=True,text=True,cwd=folder)
    assert json.loads(completed.stdout) == json.loads(output.read_text(encoding='utf-8')) == reports[1]
    assert not output.with_name('report.json.tmp').exists()
    invalid = subprocess.run([sys.executable,str(SOURCE),'--chunk-size','0'],capture_output=True,text=True)
    assert invalid.returncode != 0
(ROOT/'build/chapter-06-python-verification.json').write_text(json.dumps(reports[1],indent=2),encoding='utf-8')
print('PASS: All lesson code, eight solutions, six behavior tests, three chunk sizes, full-frame moments and standalone CLI agreement.')
