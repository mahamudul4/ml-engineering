"""Execute Chapter10 examples/solutions and audit ensemble behavior independently."""
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
from sklearn.ensemble import GradientBoostingRegressor

ROOT=Path(__file__).resolve().parent.parent
os.chdir(ROOT)
chapter=json.loads((ROOT/'assets/content/chapter_10.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons','quizzes','exercises','interviews']]==[18,24,10,10]
scopes={}; snippets=0
for lesson in chapter['lessons']:
    module=types.ModuleType(lesson['id']);sys.modules[lesson['id']]=module
    for block in lesson['blocks']:
        if block['type']=='code':
            with contextlib.redirect_stdout(io.StringIO()):exec(compile(block['body'],lesson['id'],'exec'),module.__dict__)
            snippets+=1
    scopes[lesson['id']]=module.__dict__
solutions={}
for exercise in chapter['exercises']:
    compile(exercise['starter'],exercise['id'],'exec');scope={}
    with contextlib.redirect_stdout(io.StringIO()):exec(exercise['solution'],scope)
    assert math.isclose(float(scope['answer']),exercise['expected'],abs_tol=1e-10),exercise['id']
    solutions[exercise['id']]=scope
api=scopes['ch10_workflow']; report=api['report']

class EnsembleBehaviorTests(unittest.TestCase):
    def test_adaboost_updates_match_classic_and_samme_distributions(self):
        f=api['adaboost_step'];y=np.array([1,1,-1,-1]);h=np.array([1,-1,-1,-1]);w=np.ones(4)/4
        original=w.copy();r=f(y,h,w)
        self.assertAlmostEqual(r['error'],.25);self.assertAlmostEqual(r['alpha'],.5*np.log(3))
        np.testing.assert_allclose(r['weights'],[1/6,.5,1/6,1/6])
        samme=w*np.exp(2*r['alpha']*(y!=h));samme/=samme.sum()
        np.testing.assert_allclose(r['weights'],samme)
        np.testing.assert_array_equal(w,original)
        weighted=f(y,h,[0.,1.,1.,1.]);self.assertEqual(weighted['weights'][0],0)
        self.assertAlmostEqual(weighted['weights'].sum(),1)

    def test_adaboost_boundaries_and_invalid_inputs(self):
        f=api['adaboost_step'];y=np.array([1,-1])
        self.assertEqual(f(y,y,[1,1])['status'],'perfect_stop')
        self.assertIsNone(f(y,y,[1,1])['alpha'])
        self.assertEqual(f(y,-y,[1,1])['status'],'reject_weak_learner')
        self.assertEqual(f(y,[1,1],[1,1])['status'],'reject_weak_learner')
        for h,w in [([1],[1,1]),([0,1],[1,1]),([1,-1],[-1,2]),([1,-1],[0,0]),([1,-1],[np.nan,1])]:
            with self.assertRaises(ValueError):f(y,h,w)

    def test_squared_boost_matches_staged_reference_and_preserves_inputs(self):
        X=np.arange(8.).reshape(-1,1);y=np.array([1.,1.,2.,3.,7.,8.,9.,9.]);oldX=X.copy();oldy=y.copy()
        own=api['fit_squared_boost'](X,y,rounds=4,rate=.5,min_leaf=1)
        stages=api['staged_squared_predict'](own,X)
        ref=GradientBoostingRegressor(loss='squared_error',n_estimators=4,learning_rate=.5,max_depth=2,min_samples_leaf=1,random_state=42).fit(X,y)
        np.testing.assert_allclose(stages[1:],np.array(list(ref.staged_predict(X))),rtol=1e-10,atol=1e-9)
        np.testing.assert_allclose(stages[0],y.mean());self.assertTrue(np.all(np.diff(own['training_rmse'])<=1e-12))
        np.testing.assert_array_equal(X,oldX);np.testing.assert_array_equal(y,oldy)
        empty=api['staged_squared_predict'](own,np.empty((0,1)));self.assertEqual(empty.shape,(5,0))
        zero=api['fit_squared_boost'](X,y,rounds=0,min_leaf=1);self.assertEqual(api['staged_squared_predict'](zero,X).shape,(1,8))

    def test_squared_boost_invalid_schema_rates_and_budget(self):
        f=api['fit_squared_boost'];X=np.arange(6.).reshape(-1,1);y=np.arange(6.)
        for kw in [{'rounds':-1},{'rounds':101},{'rounds':True},{'rate':0},{'rate':2},{'rate':np.nan},{'min_leaf':0}]:
            with self.assertRaises(ValueError):f(X,y,**kw)
        with self.assertRaises(ValueError):f(X,y[:,None])
        with self.assertRaises(ValueError):f([[np.nan]],[1])
        with self.assertRaises(ValueError):api['staged_squared_predict'](f(X,y),np.ones((2,2)))

    def test_real_membership_and_boosting_assets_reproduce(self):
        bag,boost=api['bag_asset'],api['boost_asset']
        self.assertEqual(bag,json.loads((ROOT/'assets/datasets/adult/ensemble_bagging_lab.json').read_text()))
        self.assertEqual(boost,json.loads((ROOT/'assets/datasets/adult/ensemble_boosting_lab.json').read_text()))
        self.assertEqual((len(bag['points']),bag['members']),(12,24));self.assertTrue(bag['points'][0]['in_bag'][0])
        frame,X,y,groups,digest=api['load_source'](ROOT/'assets/datasets/adult/adult.data')
        for row in bag['points']:
            self.assertEqual(row['positive'],int(y[row['source_row_1based']-1]))
            eligible=~np.array(row['in_bag']);self.assertGreater(eligible.sum(),0)
            mean=float(np.mean(np.array(row['probabilities'])[eligible]));self.assertTrue(0<=mean<=1)
        for i,probe in enumerate(boost['probes']):self.assertEqual(probe['target'],float(frame['hours_per_week'].iloc[probe['source_row_1based']-1]))
        for run in boost['runs']:
            pred=np.asarray(run['probe_predictions']);out=np.asarray(run['probe_tree_outputs'])
            np.testing.assert_allclose(pred[:,1:],pred[:,:-1]+run['rate']*out)
            np.testing.assert_allclose(pred[:,0],boost['base'])

    def test_loss_derivatives_newton_optimum_and_ordered_scope(self):
        logistic=scopes['ch10_logistic'];self.assertAlmostEqual(logistic['g'],logistic['numeric_g'],places=7)
        self.assertAlmostEqual(logistic['h'],logistic['numeric_h'],places=7)
        leaf=scopes['ch10_xgboost']['leaf_weight'];self.assertEqual(leaf(-3,2,1),1)
        with self.assertRaises(ValueError):leaf(1,0,0)
        self.assertAlmostEqual(scopes['ch10_xgboost']['gain'],59/60)
        # Own-label change at row2 cannot affect its already-computed prefix encoding.
        def ordered(y):
            counts={};sums={};values=[]
            for c,target in zip(['a','a','b','a'],y):
                values.append((sums.get(c,0)+1)/(counts.get(c,0)+2))
                sums[c]=sums.get(c,0)+target;counts[c]=counts.get(c,0)+1
            return values
        self.assertEqual(ordered([1,0,1,1])[1],ordered([1,1,1,1])[1])
        self.assertNotEqual(ordered([1,0,1,1])[3],ordered([1,1,1,1])[3])

    def test_selection_scope_oob_coverage_and_metrics(self):
        self.assertEqual((report['train_rows'],report['valid_rows'],report['inner_folds']),(26050,6511,3))
        self.assertEqual(len(report['candidates']),4)
        self.assertEqual(report['selected']['inner_ap'],max(row['inner_ap'] for row in report['candidates']))
        self.assertEqual(report['row_oob']['covered_rows'],26050)
        self.assertTrue(0<report['row_oob']['average_member_count']<24)
        self.assertAlmostEqual(report['baseline_validation']['ap'],1-report['baseline_validation']['accuracy'])
        self.assertEqual(len(report['assumptions']),6)
        for row in report['regression_runs']:self.assertTrue(np.isfinite(row['round16_valid_rmse']))

    def test_import_safe_cli_from_another_directory_matches_lesson(self):
        output=io.StringIO()
        with contextlib.redirect_stdout(output):imported=runpy.run_path(str(ROOT/'assets/datasets/adult/ensemble_workflow.py'))
        self.assertEqual(output.getvalue(),'')
        self.assertEqual(imported['run_analysis'](ROOT/'assets/datasets/adult/adult.data')[0],report)
        with tempfile.TemporaryDirectory() as folder:
            destination=Path(folder)/'report.json'
            result=subprocess.run([sys.executable,str(ROOT/'assets/datasets/adult/ensemble_workflow.py'),'--output',str(destination)],cwd=folder,capture_output=True,text=True,check=True,timeout=90)
            self.assertEqual(json.loads(result.stdout),report)
            self.assertEqual(json.loads(destination.read_text()),report)
            self.assertFalse(destination.with_suffix('.json.tmp').exists())

if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(EnsembleBehaviorTests)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():raise SystemExit(1)
    (ROOT/'build/chapter-10-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':10,'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, 10 solutions, {result.testsRun} behavior tests; all reports/assets agree.')
