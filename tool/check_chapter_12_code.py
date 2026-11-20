"""Execute Chapter 12 code/solutions and independently audit geometry and data."""
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
from sklearn.cluster import KMeans, DBSCAN
from sklearn.decomposition import PCA
from sklearn.metrics import adjusted_rand_score
from threadpoolctl import threadpool_limits

ROOT=Path(__file__).resolve().parent.parent;os.chdir(ROOT)
chapter=json.loads((ROOT/'assets/content/chapter_12.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons','quizzes','exercises','interviews']]==[19,24,10,10]
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
api=scopes['ch12_experiment'];report=api['report']

class UnsupervisedBehaviorTests(unittest.TestCase):
    def test_lloyd_independent_reference_monotonic_and_input_immutability(self):
        X=np.array([[0.,0.],[1.,0.],[8.,9.],[9.,8.]]);start=X[[0,2]].copy();old=start.copy()
        states=api['lloyd_steps'](X,start,max_steps=20)
        with threadpool_limits(limits=1):ref=KMeans(n_clusters=2,init=start,n_init=1,tol=1e-10,algorithm='lloyd').fit(X)
        self.assertAlmostEqual(states[-1]['inertia'],ref.inertia_);self.assertEqual(adjusted_rand_score(states[-1]['labels'],ref.labels_),1)
        self.assertTrue(np.all(np.diff([s['inertia'] for s in states])<=1e-12));np.testing.assert_array_equal(start,old)
        empty=api['lloyd_steps']([[0],[0],[4]],[[0],[0]],max_steps=1)
        self.assertEqual(empty[1]['empty_before_update'],[1]);self.assertEqual(empty[1]['centers'][1],[0.])
        self.assertEqual(len(api['lloyd_steps'](X,start,max_steps=0)),1)
        with self.assertRaises(ValueError):api['lloyd_steps'](X,[[1,2,3]])
        with self.assertRaises(ValueError):api['lloyd_steps'](X,start,max_steps=True)

    def test_density_reference_and_boundary_cases(self):
        X=np.array([[0.,0.],[.1,0.],[.2,0.],[.4,0.],[2.,0.]])
        own,core,counts=api['density_partition'](X,.21,3)
        with threadpool_limits(limits=1):ref=DBSCAN(eps=.21,min_samples=3,algorithm='brute').fit(X)
        expected=np.zeros(len(X),bool);expected[ref.core_sample_indices_]=True
        np.testing.assert_array_equal(core,expected);self.assertEqual(adjusted_rand_score(own,ref.labels_),1)
        self.assertEqual(counts[0],3);self.assertEqual(own[-1],-1)
        duplicate=api['density_partition']([[0],[0],[1]],0,2);np.testing.assert_array_equal(duplicate[0],[0,0,-1])
        edge=api['density_partition']([[0],[1],[3]],1,2);np.testing.assert_array_equal(edge[2],[2,2,1])
        with self.assertRaises(ValueError):api['density_partition'](X,-1,2)
        with self.assertRaises(ValueError):api['density_partition'](X,1,False)

    def test_border_cannot_bridge_core_components_and_undefined_silhouette(self):
        X=np.array([[0],[-1],[-1.5],[-1.5],[-1.5],[-1.5],[1],[1.5],[1.5],[1.5],[1.5]])
        labels,core,counts=api['density_partition'](X,1,5)
        self.assertFalse(core[0]);self.assertEqual(counts[0],3);self.assertEqual(labels[0],0);self.assertEqual(len(np.unique(labels)),2)
        noise=api['density_partition'](X,1,12)[0];self.assertTrue(np.all(noise==-1))
        self.assertIsNone(api['safe_silhouette'](X,noise));self.assertIsNone(api['safe_silhouette'](X,np.arange(len(X))))

    def test_pca_reference_projection_energy_and_sample_variance(self):
        X=np.array([[0.,0.],[1.,2.],[3.,1.],[4.,5.]])
        fit=api['fit_pca'](X);ref=PCA(svd_solver='full').fit(X)
        np.testing.assert_allclose(fit['variance'],ref.explained_variance_)
        scores=ref.transform(X);scores[:,1]=0
        np.testing.assert_allclose(api['reconstruct'](fit,X,1),ref.inverse_transform(scores))
        for q in [0,1,2]:
            restored=api['reconstruct'](fit,X,q)
            self.assertAlmostEqual(np.sum((X-restored)**2),np.sum(fit['singular'][q:]**2))
        np.testing.assert_allclose(api['reconstruct'](fit,X,0),np.tile(X.mean(axis=0),(len(X),1)))
        np.testing.assert_allclose(api['reconstruct'](fit,X,2),X,atol=1e-12)
        with self.assertRaises(ValueError):api['fit_pca'](np.ones((3,2)))
        with self.assertRaises(ValueError):api['reconstruct'](fit,X,3)
        with self.assertRaises(ValueError):api['reconstruct'](fit,[[0]],1)

    def test_pca_sign_invariance_and_rank_deficient_new_queries(self):
        fit=api['fit_pca']([[0,0],[1,0],[2,0]])
        before=api['reconstruct'](fit,[[3,4]],1);fit['components'][0]*=-1
        np.testing.assert_allclose(before,api['reconstruct'](fit,[[3,4]],1));np.testing.assert_allclose(before,[[3,0]])
        # n<d yields only min(n,d) SVD directions; new queries need not lie in their span.
        thin=api['fit_pca']([[0,0,0],[1,0,0]])
        self.assertEqual(thin['components'].shape,(2,3))
        self.assertGreater(np.linalg.norm(api['reconstruct'](thin,[[0,0,1]],2)-[[0,0,1]]),0)

    def test_source_rows_groups_and_three_assets_reproduce(self):
        frame,X,groups,digest=api['load_source'](ROOT/'assets/datasets/adult/adult.data');outer,train,valid=api['split_budget'](X,groups)
        self.assertEqual((len(frame),len(outer),len(train),len(valid)),(32561,26050,6013,6511))
        self.assertEqual(len(np.unique(groups[train])),6000);self.assertTrue(set(groups[train]).isdisjoint(groups[valid]))
        self.assertEqual(api['FEATURES'],['age','education_num','hours_per_week'])
        for name,key in [('kmeans','kmeans_asset'),('density','density_asset'),('pca','pca_asset')]:
            self.assertEqual(api[key],json.loads((ROOT/f'assets/datasets/adult/unsupervised_{name}_lab.json').read_text()))
        for point in api['kmeans_asset']['points']:
            row=point['source_row_1based']-1;self.assertIn(row,train);np.testing.assert_array_equal(point['values'],X[row,[0,2]])
            self.assertNotIn('positive',point);self.assertNotIn('income',point)

    def test_diagnostic_meanings_coverage_and_no_automatic_best_k(self):
        self.assertEqual(report['fixed_k'],3);self.assertNotIn('winner',report)
        self.assertEqual([r['k'] for r in report['kmeans_diagnostics']],[2,3,4,5])
        for r in report['kmeans_diagnostics']:self.assertEqual(sum(r['sizes']),6013)
        self.assertAlmostEqual(sum(report['pca_training_variance_ratio']),1)
        compression=report['pca_compression'];self.assertTrue(np.all(np.diff([r['validation_coordinate_mse'] for r in compression])<=1e-12))
        density=report['density_subset_diagnostics'];self.assertEqual(density[1]['clusters'],1);self.assertIsNone(density[1]['assigned_only_silhouette']);self.assertEqual(density[1]['coverage'],.625)
        self.assertEqual(len(report['assumptions']),7)

    def test_import_safe_cli_external_directory_and_lesson_agreement(self):
        output=io.StringIO()
        with contextlib.redirect_stdout(output):imported=runpy.run_path(str(ROOT/'assets/datasets/adult/unsupervised_workflow.py'))
        self.assertEqual(output.getvalue(),'');self.assertEqual(imported['run_analysis'](ROOT/'assets/datasets/adult/adult.data')[0],report)
        with tempfile.TemporaryDirectory() as folder:
            target=Path(folder)/'report.json'
            result=subprocess.run([sys.executable,str(ROOT/'assets/datasets/adult/unsupervised_workflow.py'),'--output',str(target)],cwd=folder,capture_output=True,text=True,check=True,timeout=90)
            self.assertEqual(json.loads(result.stdout),report);self.assertEqual(json.loads(target.read_text()),report);self.assertFalse(target.with_name('report.json.tmp').exists())

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(UnsupervisedBehaviorTests))
    if not result.wasSuccessful():raise SystemExit(1)
    (ROOT/'build/chapter-12-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':len(solutions),'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, {len(solutions)} solutions, {result.testsRun} behavior tests; reports/assets agree.')
