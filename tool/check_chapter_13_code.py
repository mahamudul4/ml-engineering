"""Execute Chapter 13 lessons/solutions; audit causal features and score semantics."""
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
from scipy.stats import median_abs_deviation
from sklearn.metrics import mean_absolute_error,root_mean_squared_error
from threadpoolctl import threadpool_limits

ROOT=Path(__file__).resolve().parent.parent;os.chdir(ROOT)
chapter=json.loads((ROOT/'assets/content/chapter_13.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons','quizzes','exercises','interviews']]==[20,24,10,10]
scopes={};snippets=0
with threadpool_limits(limits=1):
 for lesson in chapter['lessons']:
    module=types.ModuleType(lesson['id']);sys.modules[lesson['id']]=module
    for block in lesson['blocks']:
        if block['type']=='code':
            with contextlib.redirect_stdout(io.StringIO()):exec(compile(block['body'],lesson['id'],'exec'),module.__dict__)
            snippets+=1
    scopes[lesson['id']]=module.__dict__
solutions={}
for ex in chapter['exercises']:
    compile(ex['starter'],ex['id'],'exec');scope={}
    with contextlib.redirect_stdout(io.StringIO()):exec(ex['solution'],scope)
    assert math.isclose(float(scope['answer']),ex['expected'],abs_tol=1e-10),ex['id']
    solutions[ex['id']]=scope
api=scopes['ch13_experiment'];report=api['report'];asset=api['asset']

class TemporalBehaviorTests(unittest.TestCase):
    def test_robust_reference_translation_scale_zero_and_monotone_flags(self):
        X=np.array([-4.,-2.,0.,2.,20.]);original=X.copy();median,mad=api['robust_fit'](X)
        self.assertEqual((median,mad),(0,2));self.assertEqual(mad,median_abs_deviation(X))
        self.assertAlmostEqual(mad/.6744897501960817,median_abs_deviation(X,scale='normal'))
        scores=api['robust_scores'](X,median,mad);np.testing.assert_allclose(scores,api['robust_scores'](X*3+10,median*3+10,mad*3))
        self.assertTrue(set(np.flatnonzero(scores>3.5))<=set(np.flatnonzero(scores>.5)));np.testing.assert_array_equal(X,original)
        with self.assertRaises(ValueError):api['robust_fit']([1,1,1])
        with self.assertRaises(ValueError):api['robust_scores']([1],0,0)

    def test_forecast_formula_wrap_gap_history_and_input_contract(self):
        history=np.arange(1.,8.);old=history.copy()
        np.testing.assert_array_equal(api['forecast'](history,10,'seasonal'),[1,2,3,4,5,6,7,1,2,3])
        np.testing.assert_array_equal(api['forecast'](history,3,'seasonal',gap=9),[3,4,5])
        np.testing.assert_array_equal(api['forecast'](history,3,'naive',gap=9),[7,7,7])
        np.testing.assert_array_equal(api['forecast']([2,4,6],3,'drift',gap=1),[10,12,14]);np.testing.assert_array_equal(history,old)
        for kwargs in [dict(horizon=0,method='naive'),dict(horizon=1,method='seasonal',period=8),dict(horizon=True,method='naive'),dict(horizon=1,method='unknown')]:
            with self.assertRaises(ValueError):api['forecast'](history,**kwargs)

    def test_metrics_independent_sklearn_reference_and_undefined_scale(self):
        actual=np.array([1.,3.,8.]);pred=np.array([2.,1.,4.]);training=np.arange(1.,9.)
        m=api['metrics'](actual,pred,training)
        self.assertEqual(m['mae'],mean_absolute_error(actual,pred));self.assertEqual(m['rmse'],root_mean_squared_error(actual,pred));self.assertAlmostEqual(m['mase7'],m['mae']/7)
        self.assertIsNone(api['metrics'](actual,pred,np.ones(10))['mase7'])
        with self.assertRaises(ValueError):api['metrics'](actual,pred[:2],training)

    def test_causal_feature_suffix_invariance_and_component_exclusion(self):
        _,y=api['load_source'](ROOT/'assets/datasets/bike_sharing/day.csv');dates=pd.Series(pd.date_range('2011-01-01',periods=len(y)))
        X,target,position=api['lag_features'](y,dates);changed=y.copy();changed[365:]=999999
        altered,_,_=api['lag_features'](changed,dates)
        np.testing.assert_array_equal(X[position<=365],altered[position<=365])
        row=X[position==365][0];self.assertEqual(row[0],y[364]);self.assertEqual(row[1],y[358]);self.assertAlmostEqual(row[3],np.mean(y[358:365]));self.assertEqual(X.shape,(717,6))
        self.assertEqual(target[position==365][0],y[365]);self.assertEqual(len(position[position<365]),351)

    def test_temporal_fold_boundaries_and_cv_local_scaling_scope(self):
        train,gap,valid=api['temporal_fold'](200,100,14,gap=7,window=60)
        self.assertEqual((train[0],train[-1],len(train),gap[0],gap[-1],valid[0],valid[-1]),(40,99,60,100,106,107,120))
        with self.assertRaises(ValueError):api['temporal_fold'](120,100,14,gap=7)
        # Reproduce train-only CV independently from its declared feature/target matrix.
        frame,y=api['load_source'](ROOT/'assets/datasets/bike_sharing/day.csv');X,target,pos=api['lag_features'](y[:365],frame.dteday.iloc[:365])
        from sklearn.model_selection import TimeSeriesSplit
        from sklearn.preprocessing import StandardScaler
        for tr,va in TimeSeriesSplit(n_splits=3,test_size=56,gap=7).split(X):
            self.assertLess(tr[-1]+7,va[0]);scaler=StandardScaler().fit(X[tr]);np.testing.assert_allclose(scaler.mean_,X[tr].mean(axis=0))
        candidates=report['ridge_candidates_training_cv'];self.assertEqual(report['selected_alpha'],min(candidates,key=lambda r:r['training_cv_mae'])['alpha'])

    def test_original_observations_asset_scores_and_reserved_outcomes(self):
        frame,y=api['load_source'](ROOT/'assets/datasets/bike_sharing/day.csv')
        self.assertEqual((len(y),report['training_rows'],report['development_rows'],report['reserved_outcomes_not_evaluated']),(731,365,182,184))
        self.assertEqual(asset,json.loads((ROOT/'assets/datasets/bike_sharing/temporal_lab.json').read_text()))
        np.testing.assert_array_equal(asset['counts'],y[:547]);self.assertEqual(asset['dates'][-1],'2012-06-30');self.assertEqual(len(asset['anomaly_queries']),42)
        for q in asset['anomaly_queries']:
            i=q['source_row_1based']-1;self.assertEqual(q['actual'],y[i]);self.assertEqual(q['lag7'],y[i-7]);self.assertEqual(q['date'],str(frame.dteday.iloc[i].date()));self.assertNotIn('is_anomaly',q)
            self.assertAlmostEqual(q['robust_score'],api['robust_scores']([q['residual']],54.5,489.5)[0])

    def test_protocols_flags_and_frozen_origin_predictions(self):
        _,y=api['load_source'](ROOT/'assets/datasets/bike_sharing/day.csv');copy=y.copy();copy[365:]=-999999
        for method in ['naive','seasonal','drift']:np.testing.assert_array_equal(api['forecast'](y[:365],28,method),api['forecast'](copy[:365],28,method))
        self.assertEqual(report['robust_threshold_3_5_development_alerts'],16)
        for row in report['detector_flags_without_ground_truth']:
            self.assertAlmostEqual(row['development_rate'],row['development_alerts']/182);self.assertNotIn('accuracy',row)
        self.assertEqual(len(report['fixed_origin_14day_backtests']),9);self.assertEqual(len(report['assumptions']),7)
        self.assertNotIn('test_metrics',report)

    def test_import_safe_cli_external_directory_and_report_agreement(self):
        output=io.StringIO();script=ROOT/'assets/datasets/bike_sharing/temporal_workflow.py'
        with contextlib.redirect_stdout(output):imported=runpy.run_path(str(script))
        self.assertEqual(output.getvalue(),'');self.assertEqual(imported['run_analysis'](script.with_name('day.csv'))[0],report)
        with tempfile.TemporaryDirectory() as directory:
            target=Path(directory)/'report.json';r=subprocess.run([sys.executable,str(script),'--output',str(target)],cwd=directory,capture_output=True,text=True,timeout=90,check=True)
            self.assertEqual(json.loads(r.stdout),report);self.assertEqual(json.loads(target.read_text()),report);self.assertFalse(target.with_name('report.json.tmp').exists())

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(TemporalBehaviorTests))
    if not result.wasSuccessful():raise SystemExit(1)
    (ROOT/'build/chapter-13-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':len(solutions),'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, {len(solutions)} solutions, {result.testsRun} behavior tests; reports/assets agree.')
