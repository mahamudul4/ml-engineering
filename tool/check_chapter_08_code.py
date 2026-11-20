"""Execute every Chapter 8 snippet/solution and audit inference against SciPy."""
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
from scipy import stats

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
chapter = json.loads((ROOT/'assets/content/chapter_08.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons','quizzes','interviews','exercises']] == [16,20,8,8]
scopes = {}
snippet_count = 0
for lesson in chapter['lessons']:
    module = types.ModuleType(lesson['id'])
    sys.modules[lesson['id']] = module
    for block in lesson['blocks']:
        if block['type'] == 'code':
            with contextlib.redirect_stdout(io.StringIO()):
                exec(compile(block['body'],lesson['id'],'exec'),module.__dict__)
            snippet_count += 1
    scopes[lesson['id']] = module.__dict__
solutions = {}
for exercise in chapter['exercises']:
    compile(exercise['starter'],exercise['id'],'exec')
    scope = {}
    with contextlib.redirect_stdout(io.StringIO()): exec(exercise['solution'],scope)
    assert math.isclose(float(scope['answer']),exercise['expected'],abs_tol=1e-10),exercise['id']
    solutions[exercise['id']] = scope
workflow = scopes['ch08_workflow']
report = workflow['report']

class StatisticsBehaviorTests(unittest.TestCase):
    def test_wilson_matches_score_reference_and_boundaries(self):
        interval = workflow['wilson_interval']
        for n in [1,10,20,100]:
            for k in [0,n//2,n]:
                for confidence in [.9,.95,.99]:
                    ref=stats.binomtest(k,n).proportion_ci(confidence,method='wilson')
                    np.testing.assert_allclose(interval(k,n,confidence),ref,atol=1e-14)
        for args in [(-1,10),(11,10),(0,0),(True,10),(1,10,1),(1,10,float('nan'))]:
            with self.assertRaises(ValueError): interval(*args)

    def test_welch_matches_independent_api_and_rejects_degenerate_data(self):
        f=workflow['welch_difference']; a=np.array([2.,3.,7.,8.,12.]); b=np.arange(1.,7.)
        own=f(a,b); reference=stats.ttest_ind(a,b,equal_var=False)
        np.testing.assert_allclose([own['statistic'],own['p_two_sided'],own['df']], [reference.statistic,reference.pvalue,reference.df])
        np.testing.assert_allclose(own['confidence_interval'],reference.confidence_interval(.95))
        reverse=f(b,a)
        np.testing.assert_allclose(reverse['confidence_interval'],-np.array(own['confidence_interval'])[::-1])
        for a_bad,b_bad in [([1],[2,3]),([1,1],[2,2]),([[1],[2]],[1,2]),([1,np.nan],[2,3])]:
            with self.assertRaises(ValueError): f(a_bad,b_bad)

    def test_cluster_resampling_preserves_all_rows_and_recomputes_denominator(self):
        f=workflow['profile_bootstrap_means']
        # Two unequal clusters: totals 0 and 30, counts 1 and 3.
        # All possible two-cluster draws yield means 0, 7.5 or 10, not mean-of-means 5.
        values=[0.,10.,10.,10.]; groups=[0,1,1,1]
        draws=f(values,groups,resamples=1000,rng=np.random.default_rng(42))
        self.assertEqual(set(draws),{0.,7.5,10.})
        np.testing.assert_array_equal(draws,f(values,groups,resamples=1000,rng=np.random.default_rng(42)))
        np.testing.assert_allclose(f([.25,.25,.25],[0,1,1],resamples=100,rng=np.random.default_rng(1)),.25)
        for v,g in [([1,2],[0,0]),([1,2],[0]),([1,np.nan],[0,1])]:
            with self.assertRaises(ValueError): f(v,g,rng=np.random.default_rng(1))

    def test_exact_coverage_matches_pmf_sum(self):
        n,p=20,.2; z=stats.norm.ppf(.975)
        counts=np.arange(n+1); phat=counts/n
        wilson=np.array([workflow['wilson_interval'](int(k),n) for k in counts])
        half=z*np.sqrt(phat*(1-phat)/n)
        wald=np.stack([np.maximum(0,phat-half),np.minimum(1,phat+half)],axis=1)
        masses=stats.binom.pmf(counts,n,p)
        coverage=lambda ci:float(masses[(ci[:,0]<=p)&(p<=ci[:,1])].sum())
        self.assertAlmostEqual(coverage(wilson),.9563281218730577,places=12)
        self.assertAlmostEqual(coverage(wald),.9208429234028657,places=12)

    def test_source_scope_and_declared_contrast(self):
        self.assertEqual((report['rows'],report['positive_income']),(32561,7841))
        self.assertAlmostEqual(report['observed_income_proportion'],7841/32561)
        self.assertEqual(report['profile_clusters'],32493)
        self.assertEqual((report['cohort_a']['rows'],report['cohort_b']['rows']),(7291,10501))
        self.assertAlmostEqual(report['iid_row_welch']['difference'],-1.7230901365651619)
        self.assertEqual(report['beta_bernoulli_working_model']['posterior'],[7842,24721])
        for key in ['iid_row_wilson_95','profile_bootstrap_proportion_percentile_95','profile_bootstrap_difference_percentile_95']:
            low,high=report[key]; self.assertTrue(np.isfinite([low,high]).all()); self.assertLess(low,high)
        self.assertEqual(len(report['assumptions']),5)

    def test_exact_permutation_and_posterior_identity(self):
        self.assertAlmostEqual(scopes['ch08_resampling']['result'].pvalue,.1)
        self.assertEqual(len(scopes['ch08_resampling']['result'].null_distribution),20)
        self.assertAlmostEqual(solutions['ch08_ex_beta']['answer'],9/14)
        self.assertEqual(solutions['ch08_ex_holm']['answer'],1)

    def test_import_safe_standalone_and_cli_match_lesson(self):
        output=io.StringIO()
        with contextlib.redirect_stdout(output):
            standalone=runpy.run_path(str(ROOT/'assets/datasets/adult/statistics_workflow.py'))
        self.assertEqual(output.getvalue(),'')
        self.assertEqual(standalone['run_analysis'](ROOT/'assets/datasets/adult/adult.data'),report)
        with tempfile.TemporaryDirectory() as directory:
            destination=Path(directory)/'report.json'
            result=subprocess.run([sys.executable,'assets/datasets/adult/statistics_workflow.py','--output',str(destination)],check=True,capture_output=True,text=True,timeout=60)
            self.assertEqual(json.loads(result.stdout),report)
            self.assertEqual(json.loads(destination.read_text()),report)
            self.assertFalse(destination.with_suffix('.json.tmp').exists())

if __name__ == '__main__':
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(StatisticsBehaviorTests)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful(): raise SystemExit(1)
    destination=ROOT/'build/chapter-08-python-verification.json'
    destination.write_text(json.dumps({'snippets':snippet_count,'solutions':len(solutions),'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippet_count} snippets, {len(solutions)} solutions, {result.testsRun} behavior tests; standalone/CLI match.')
