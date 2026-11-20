"""Execute every Chapter9 example/solution and independently audit tree behavior."""
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
from sklearn.tree import DecisionTreeClassifier

ROOT=Path(__file__).resolve().parent.parent
os.chdir(ROOT)
chapter=json.loads((ROOT/'assets/content/chapter_09.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons','quizzes','exercises','interviews']]==[16,20,8,8]
scopes={}; snippets=0
for lesson in chapter['lessons']:
    module=types.ModuleType(lesson['id']); sys.modules[lesson['id']]=module
    for block in lesson['blocks']:
        if block['type']=='code':
            with contextlib.redirect_stdout(io.StringIO()): exec(compile(block['body'],lesson['id'],'exec'),module.__dict__)
            snippets+=1
    scopes[lesson['id']]=module.__dict__
solutions={}
for exercise in chapter['exercises']:
    compile(exercise['starter'],exercise['id'],'exec'); scope={}
    with contextlib.redirect_stdout(io.StringIO()): exec(exercise['solution'],scope)
    assert math.isclose(float(scope['answer']),exercise['expected'],abs_tol=1e-10),exercise['id']
    solutions[exercise['id']]=scope
api=scopes['ch09_workflow']; report=api['report']

class TreeBehaviorTests(unittest.TestCase):
    def test_scratch_cart_unique_split_matches_reference_and_preserves_inputs(self):
        X=np.arange(6.).reshape(-1,1); y=np.array([0,0,0,1,1,1]); original=X.copy(); labels=y.copy()
        own=api['fit_cart'](X,y,max_depth=1,min_leaf=2)
        ref=DecisionTreeClassifier(max_depth=1,min_samples_leaf=2,random_state=42).fit(X,y)
        self.assertEqual(own['root']['threshold'],ref.tree_.threshold[0])
        for probe in [X,np.array([[2.5],[2.50001],[-10.],[100.]])]:
            np.testing.assert_allclose(api['predict_cart'](own,probe),ref.predict_proba(probe)[:,1])
        np.testing.assert_array_equal(X,original); np.testing.assert_array_equal(y,labels)
        self.assertEqual(api['predict_cart'](own,np.empty((0,1))).shape,(0,))

    def test_scratch_stops_pure_constant_depth_and_duplicate_boundaries(self):
        fit=api['fit_cart']; best=api['best_split']; pred=api['predict_cart']
        X=np.arange(6.).reshape(-1,1); y=np.array([0,0,0,1,1,1])
        self.assertNotIn('feature',fit(X,y,max_depth=0)['root'])
        self.assertNotIn('feature',fit(X,np.ones(6))['root'])
        self.assertIsNone(best(np.ones((6,1)),y))
        self.assertIsNone(best(X,y,4))
        duplicate=np.array([[0.],[0.],[1.],[1.]])
        chosen=best(duplicate,np.array([0,0,1,1]))
        self.assertEqual(chosen['threshold'],.5)
        for a,b in [([[1],[2]],[0]),([[np.nan],[2]],[0,1]),([[1],[2]],[0,2])]:
            with self.assertRaises(ValueError): fit(a,b)
        with self.assertRaises(ValueError): fit(X,y,min_leaf=0)
        with self.assertRaises(ValueError): pred(fit(X,y),np.ones((2,2)))

    def test_greedy_zero_gain_policy_is_explicit(self):
        X=np.array([[0.,0.],[0.,1.],[1.,0.],[1.,1.]]); y=np.array([0,1,1,0])
        own=api['fit_cart'](X,y,max_depth=2)
        np.testing.assert_allclose(api['predict_cart'](own,X),.5)
        ref=DecisionTreeClassifier(max_depth=2,random_state=42).fit(X,y)
        self.assertEqual(ref.score(X,y),1)

    def test_real_split_lab_exactly_matches_original_rows_and_weighted_reference(self):
        frame,X,y,groups,digest=api['load_source'](ROOT/'assets/datasets/adult/adult.data')
        lab=api['split_asset']
        self.assertEqual(lab,json.loads((ROOT/'assets/datasets/adult/tree_split_lab.json').read_text()))
        for i,row in enumerate(lab['rows']): self.assertEqual((row['source_row_1based'],row['age'],row['positive']),(i+1,X[i,0],int(y[i])))
        self.assertEqual(int(y[:24].sum()),8)
        train,valid=api['development_split'](X,y,groups)
        self.assertTrue(set(groups[train]).isdisjoint(groups[valid]))
        self.assertEqual((len(train),len(valid)),(26050,6511))
        # Independent library stump on the real subset verifies the best split.
        own=api['best_split'](X[:24,:1],y[:24],2)
        ref=DecisionTreeClassifier(max_depth=1,min_samples_leaf=2,random_state=42).fit(X[:24,:1],y[:24])
        self.assertEqual(own['threshold'],ref.tree_.threshold[0])
        weighted=(ref.tree_.n_node_samples[1]*ref.tree_.impurity[1]+ref.tree_.n_node_samples[2]*ref.tree_.impurity[2])/24
        self.assertAlmostEqual(own['gain'],ref.tree_.impurity[0]-weighted)

    def test_pruning_path_matches_fitted_risk_and_is_weakly_nested(self):
        asset=api['pruning_asset']
        self.assertEqual(asset,json.loads((ROOT/'assets/datasets/adult/tree_pruning_lab.json').read_text()))
        path=asset['snapshots']; self.assertEqual((len(path),path[0]['leaves'],path[-1]['leaves']),(27,29,1))
        self.assertTrue(np.all(np.diff([r['leaves'] for r in path])<=0))
        self.assertTrue(np.all(np.diff([r['risk'] for r in path])>=-1e-12))
        # Every selected path tree minimizes the penalized training criterion
        # among these nested candidates, allowing equality at pruning breakpoints.
        for selected in path:
            chosen=selected['risk']+selected['alpha']*selected['leaves']
            costs=[r['risk']+selected['alpha']*r['leaves'] for r in path]
            self.assertLessEqual(chosen,min(costs)+1e-10)

    def test_selection_and_metrics_are_consistent_with_declared_protocol(self):
        self.assertEqual(report['candidate_count'],8); self.assertEqual(report['inner_folds'],3)
        self.assertEqual(report['selected']['mean_inner_ap'],max(r['mean_inner_ap'] for r in report['candidates']))
        self.assertEqual(report['selected_leaves'],37)
        self.assertEqual(report['selected_depth'],6)
        self.assertAlmostEqual(report['baseline_validation']['average_precision'],1-report['baseline_validation']['accuracy'])
        self.assertAlmostEqual(sum(report['feature_importance_mdi'].values()),1)
        self.assertEqual(report['example_path']['leaf'],report['example_path']['node_ids'][-1])
        self.assertTrue(np.isfinite(report['regression_fixed']['validation_rmse']))

    def test_import_safe_cli_and_packaged_assets_reproduce_lesson(self):
        captured=io.StringIO()
        with contextlib.redirect_stdout(captured): imported=runpy.run_path(str(ROOT/'assets/datasets/adult/tree_workflow.py'))
        self.assertEqual(captured.getvalue(),'')
        self.assertEqual(imported['run_analysis'](ROOT/'assets/datasets/adult/adult.data')[0],report)
        with tempfile.TemporaryDirectory() as folder:
            output=Path(folder)/'report.json'
            result=subprocess.run([sys.executable,str(ROOT/'assets/datasets/adult/tree_workflow.py'),'--output',str(output)],cwd=folder,check=True,capture_output=True,text=True,timeout=90)
            self.assertEqual(json.loads(result.stdout),report)
            self.assertEqual(json.loads(output.read_text()),report)
            self.assertFalse(output.with_suffix('.json.tmp').exists())

if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(TreeBehaviorTests)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful(): raise SystemExit(1)
    (ROOT/'build/chapter-09-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':8,'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, 8 solutions, {result.testsRun} behavior tests; all reports/assets agree.')
