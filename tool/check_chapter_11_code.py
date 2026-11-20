"""Execute Chapter11 code and reference solutions; independently audit the math/data."""
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
from sklearn.naive_bayes import GaussianNB
from sklearn.neighbors import KNeighborsClassifier
from sklearn.metrics.pairwise import rbf_kernel

ROOT=Path(__file__).resolve().parent.parent;os.chdir(ROOT)
chapter=json.loads((ROOT/'assets/content/chapter_11.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons','quizzes','exercises','interviews']]==[19,24,10,10]
scopes={};snippets=0
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
api=scopes['ch11_workflow'];report=api['report']

class ClassicalBehaviorTests(unittest.TestCase):
    def test_hinge_subgradient_away_from_kink_and_input_immutability(self):
        f=api['hinge_objective'];X=np.array([[1.,0.],[0.,2.]]);y=np.array([1,-1]);w=np.array([.2,-.1]);b=.05;old=w.copy()
        loss,g,gb=f(X,y,w,b,C=2);eps=1e-6
        numeric=np.array([(f(X,y,w+np.eye(2)[j]*eps,b,C=2)[0]-f(X,y,w-np.eye(2)[j]*eps,b,C=2)[0])/(2*eps) for j in range(2)])
        np.testing.assert_allclose(g,numeric,atol=1e-8);self.assertAlmostEqual(gb,(f(X,y,w,b+eps,C=2)[0]-f(X,y,w,b-eps,C=2)[0])/(2*eps))
        np.testing.assert_array_equal(w,old)
        with self.assertRaises(ValueError):f(X,[0,1],w,b)
        with self.assertRaises(ValueError):f(X,y[:,None],w,b)
        with self.assertRaises(ValueError):f(X,y,w,b,C=-1)

    def test_kernel_reference_symmetry_and_invalid_gamma(self):
        f=api['rbf_kernel'];X=np.array([[0.,0.],[1.,0.],[0.,1.]])
        K=f(X,X,.5);np.testing.assert_allclose(K,rbf_kernel(X,X,gamma=.5));np.testing.assert_allclose(K,K.T)
        self.assertGreaterEqual(np.linalg.eigvalsh(K).min(),-1e-12);np.testing.assert_allclose(f(X,X,0),1)
        with self.assertRaises(ValueError):f(X,X,-1)
        with self.assertRaises(ValueError):f(X,np.ones((3,3)),1)

    def test_neighbor_reference_without_cutoff_ties(self):
        f=api['knn_predict'];X=np.array([[0.,0.],[1.,0.],[4.,0.],[8.,0.]]);y=np.array([0,1,1,0]);queries=np.array([[2.1,0.],[6.2,0.]])
        for p in [1,2]:
            for weighted in [False,True]:
                own,_=f(X,y,queries,k=3,p=p,weighted=weighted)
                ref=KNeighborsClassifier(n_neighbors=3,p=p,weights='distance' if weighted else 'uniform',algorithm='brute').fit(X,y)
                np.testing.assert_allclose(own,ref.predict_proba(queries)[:,1])
        zero,_=f([[0],[0],[1]],[0,1,1],[[0]],k=3,weighted=True);np.testing.assert_allclose(zero,.5)
        tie,detail=f([[-1],[1]],[0,1],[[0]],k=1);self.assertEqual(detail[0]['indices'].tolist(),[0])
        empty,_=f(X,y,np.empty((0,2)),k=3);self.assertEqual(empty.shape,(0,))
        with self.assertRaises(ValueError):f(X,y,queries,k=5)
        with self.assertRaises(ValueError):f(X,y,queries,p=0)

    def test_gaussian_density_reference_and_validation(self):
        f=api['gaussian_log_scores'];X=np.array([[0.,1.],[1.,2.],[3.,4.],[4.,6.]]);y=[0,0,1,1]
        model=GaussianNB().fit(X,y);Q=np.array([[2.,3.],[20.,30.]])
        joint,logp,terms=f(Q,model.theta_,model.var_,model.class_prior_)
        np.testing.assert_allclose(logp,model.predict_log_proba(Q));np.testing.assert_allclose(np.exp(logp).sum(axis=1),1)
        np.testing.assert_allclose(joint,np.log(model.class_prior_)[None,:]+terms.sum(axis=2))
        empty=f(np.empty((0,2)),model.theta_,model.var_,model.class_prior_);self.assertEqual(empty[1].shape,(0,2))
        with self.assertRaises(ValueError):f(Q,model.theta_,np.zeros((2,2)),[.5,.5])
        with self.assertRaises(ValueError):f(Q,model.theta_,model.var_,[0,1])

    def test_original_source_budget_and_group_separation(self):
        frame,X,y,groups,digest=api['load_source'](ROOT/'assets/datasets/adult/adult.data');outer,train,valid=api['split_and_budget'](X,y,groups)
        self.assertEqual((len(outer),len(train),len(valid)),(26050,6013,6511));self.assertEqual(len(np.unique(groups[train])),6000)
        self.assertTrue(set(groups[train]).isdisjoint(groups[valid]));self.assertTrue(set(train)<=set(outer))
        for key,asset in [('svm',api['svm_asset']),('knn',api['knn_asset']),('nb',api['nb_asset'])]:
            self.assertEqual(asset,json.loads((ROOT/f'assets/datasets/adult/classical_{key}_lab.json').read_text()))
            points=asset.get('points',asset.get('pool',[]))+asset['queries']
            for point in points:
                i=point['source_row_1based']-1;self.assertEqual(point['positive'],int(y[i]));np.testing.assert_array_equal(point['values'],X[i,:2])

    def test_fitted_margin_and_nb_asset_scores_reconstruct(self):
        svm=api['svm_asset'];X=np.array([q['values'] for q in svm['queries']]);Z=(X-svm['mean'])/svm['scale']
        for s in svm['snapshots']:
            np.testing.assert_allclose(Z@np.array(s['weights'])+s['bias'],s['query_scores'],atol=1e-10)
            self.assertAlmostEqual(s['norm'],np.linalg.norm(s['weights']));self.assertLessEqual(s['support_count'],1024)
        nb=api['nb_asset'];queries=np.array([p['values'] for p in nb['queries']])
        own=api['gaussian_log_scores'](queries,nb['means'],nb['variances'],nb['priors'])[1]
        np.testing.assert_allclose(own,nb['reference_log_probability'],atol=1e-10)

    def test_selection_and_metric_semantics(self):
        self.assertEqual((len(report['candidates']),report['inner_folds']),(6,3))
        self.assertEqual(report['selected']['inner_ap'],max(r['inner_ap'] for r in report['candidates']))
        self.assertEqual(report['selected']['family'],'linear');self.assertNotIn('brier',report['winner_validation'])
        self.assertAlmostEqual(report['baseline_validation']['ap'],1-report['baseline_validation']['accuracy'])
        self.assertEqual(len(report['assumptions']),7)

    def test_import_safe_cli_another_directory_and_report_agreement(self):
        output=io.StringIO()
        with contextlib.redirect_stdout(output):imported=runpy.run_path(str(ROOT/'assets/datasets/adult/classical_workflow.py'))
        self.assertEqual(output.getvalue(),'');self.assertEqual(imported['run_analysis'](ROOT/'assets/datasets/adult/adult.data')[0],report)
        with tempfile.TemporaryDirectory() as folder:
            destination=Path(folder)/'report.json'
            result=subprocess.run([sys.executable,str(ROOT/'assets/datasets/adult/classical_workflow.py'),'--output',str(destination)],cwd=folder,check=True,capture_output=True,text=True,timeout=90)
            self.assertEqual(json.loads(result.stdout),report);self.assertEqual(json.loads(destination.read_text()),report);self.assertFalse(destination.with_suffix('.json.tmp').exists())

if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(ClassicalBehaviorTests);result=unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():raise SystemExit(1)
    (ROOT/'build/chapter-11-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':10,'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, 10 solutions, {result.testsRun} behavior tests; all reports/assets agree.')
