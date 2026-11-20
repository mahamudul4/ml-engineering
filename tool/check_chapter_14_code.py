"""Execute Chapter14 examples/solutions and audit the complete capstone contract."""
import contextlib,hashlib,io,json,math,os,runpy,subprocess,sys,tempfile,types,unittest
from pathlib import Path
import joblib
import numpy as np
from sklearn.metrics import confusion_matrix,average_precision_score,brier_score_loss
from sklearn.base import clone
from sklearn.model_selection import StratifiedGroupKFold
from threadpoolctl import threadpool_limits

ROOT=Path(__file__).resolve().parent.parent;os.chdir(ROOT)
chapter=json.loads((ROOT/'assets/content/chapter_14.json').read_text(encoding='utf-8'))
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
api=scopes['ch14_artifacts'];report=api['report'];asset=api['asset'];model=api['model'];schema=api['schema']

class CapstoneBehaviorTests(unittest.TestCase):
    def test_policy_sklearn_reference_ties_costs_and_invalid_inputs(self):
        y=np.array([0,1,1,0]);p=np.array([.2,.3,.9,.7]);r=api['policy_metrics'](y,p,.3)
        np.testing.assert_array_equal([r[k] for k in ['tn','fp','fn','tp']],confusion_matrix(y,p>=.3).ravel());self.assertEqual(r['mean_cost'],.25)
        self.assertIsNone(api['policy_metrics'](y,p,1)['precision']);self.assertEqual(api['policy_metrics']([1],[1],1)['tp'],1)
        self.assertEqual(api['choose_policy']([0,0],[.1,.1])[0]['threshold'],.95)
        for args in [([0,1],[.2],.3),([0,2],[.2,.3],.3),([0],[1.1],.3),([0],[.2],-1)]:
            with self.assertRaises(ValueError):api['policy_metrics'](*args)
        with self.assertRaises(ValueError):api['policy_metrics'](y,p,.3,cost_fn=-1)

    def test_probability_metrics_ap_not_trapezoid_and_undefined_support(self):
        y=[0,1,1,0];p=[.2,.3,.9,.7];r=api['probability_metrics'](y,p)
        self.assertEqual(r['ap'],average_precision_score(y,p));self.assertEqual(r['brier'],brier_score_loss(y,p));self.assertAlmostEqual(r['ap'],5/6)
        single=api['probability_metrics']([0,0],[.1,.2]);self.assertIsNone(single['ap']);self.assertIsNone(single['roc_auc'])

    def test_source_split_groups_and_test_exclusion_from_all_lab_rows(self):
        frame,X,y,groups=api['load_source'](ROOT/'assets/datasets/wine_quality/winequality-red.csv');fit,decision,test=api['split_roles'](X,y,groups)
        self.assertEqual((len(X),len(np.unique(groups)),len(fit),len(decision),len(test)),(1599,1359,966,313,320))
        for left,right in [(fit,decision),(fit,test),(decision,test)]:self.assertTrue(set(groups[left]).isdisjoint(groups[right]))
        self.assertEqual(asset,json.loads((ROOT/'assets/datasets/wine_quality/capstone_lab.json').read_text()))
        for q in asset['decision_predictions']:
            i=q['source_row_1based']-1;self.assertIn(i,decision);self.assertNotIn(i,test);self.assertEqual(q['quality'],int(frame.quality.iloc[i]));self.assertEqual(q['positive'],int(y[i]))
        for q in asset['logistic_reference']['queries']:
            i=q['source_row_1based']-1;self.assertIn(i,decision);np.testing.assert_array_equal(q['values'],X[i])

    def test_recomputed_fold_evidence_training_scope_and_declared_selection(self):
        _,X,y,groups=api['load_source'](ROOT/'assets/datasets/wine_quality/winequality-red.csv');fit,_,_=api['split_roles'](X,y,groups)
        templates={key:template for key,_,template in api['candidate_models']()}
        folds=list(StratifiedGroupKFold(3,shuffle=True,random_state=44).split(X[fit],y[fit],groups[fit]))
        for tr,va in folds:self.assertTrue(set(groups[fit][tr]).isdisjoint(groups[fit][va]))
        # Independently reproduce the selected logistic CV and scaler scope.
        own=[]
        with threadpool_limits(limits=1):
            for tr,va in folds:
                fitted=clone(templates['logistic_1']).fit(X[fit][tr],y[fit][tr]);np.testing.assert_allclose(fitted[0].mean_,X[fit][tr].mean(axis=0))
                own.append(average_precision_score(y[fit][va],fitted.predict_proba(X[fit][va])[:,1]))
        row=next(r for r in report['candidates'] if r['id']=='logistic_1');np.testing.assert_allclose(own,row['fold_ap'])
        self.assertEqual(report['selected_id'],min(report['candidates'],key=lambda r:(-r['mean_ap'],r['declared_order']))['id'])
        np.testing.assert_allclose(model[0].mean_,X[fit].mean(axis=0))

    def test_locked_policy_and_final_arithmetic_without_refit(self):
        frame,X,y,groups=api['load_source'](ROOT/'assets/datasets/wine_quality/winequality-red.csv');fit,decision,test=api['split_roles'](X,y,groups)
        p=model.predict_proba(X[decision])[:,1];selected,_=api['choose_policy'](y[decision],p)
        self.assertEqual(selected['threshold'],.3);self.assertEqual(selected,report['policy_selection'])
        test_p=model.predict_proba(X[test])[:,1];final=report['locked_final_test']
        self.assertEqual(final['ap'],average_precision_score(y[test],test_p));self.assertEqual(final['mean_cost'],(72+4*21)/320)
        self.assertEqual([final[k] for k in ['tn','fp','fn','tp']],[57,72,21,170]);self.assertEqual(len(report['assumptions']),7)

    def test_fixed_prediction_bootstrap_scope_and_single_class(self):
        result=api['group_bootstrap']([0,0,0],[.1,.2,.3],[1,1,2],.5,repeats=20)
        self.assertEqual(result['ap_defined_resamples'],0);self.assertIsNone(result['ap_percentile95']);self.assertEqual(result['mean_cost_percentile95'],[0,0])
        first=api['group_bootstrap']([0,1,0,1,0,1],[.9]*6,[0,0,0,1,2,2],.3,repeats=40)
        self.assertEqual(first,api['group_bootstrap']([0,1,0,1,0,1],[.9]*6,[0,0,0,1,2,2],.3,repeats=40))
        rng=np.random.default_rng(42);sizes=np.array([3,1,2]);false_positives=np.array([2,0,1]);cost=[]
        for _ in range(40):
            chosen=rng.integers(0,3,size=3);cost.append(false_positives[chosen].sum()/sizes[chosen].sum())
        np.testing.assert_allclose(first['mean_cost_percentile95'],np.quantile(cost,[.025,.975]))

    def test_artifact_roundtrip_hashes_selected_model_identity_and_reference_math(self):
        with tempfile.TemporaryDirectory() as temp:
            folder=Path(temp);hashes=api['write_artifacts'](folder,report,asset,model,schema)
            for name,digest in hashes.items():self.assertEqual(hashlib.sha256((folder/name).read_bytes()).hexdigest(),digest)
            card=json.loads((folder/'model_card.json').read_text());reference=json.loads((folder/'reference_queries.json').read_text());restored=joblib.load(folder/'model.joblib')
            self.assertEqual(card['selected_id'],reference['model_id']);self.assertEqual(card['locked_threshold'],.3)
            X=np.array([r['values'] for r in reference['queries']]);p=np.array([r['probability'] for r in reference['queries']]);np.testing.assert_allclose(restored.predict_proba(X)[:,1],p)
        trace=asset['logistic_reference'];X=np.array([q['values'] for q in trace['queries']]);z=(X-trace['mean'])/trace['scale'];logit=z@np.array(trace['weights'])+trace['bias']
        np.testing.assert_allclose(logit,[q['logit'] for q in trace['queries']],atol=1e-10)

    def test_import_safe_cli_external_directory_report_and_asset_agreement(self):
        script=ROOT/'assets/datasets/wine_quality/capstone_workflow.py';out=io.StringIO()
        with contextlib.redirect_stdout(out):imported=runpy.run_path(str(script))
        self.assertEqual(out.getvalue(),'');self.assertEqual(imported['run_analysis'](script.with_name('winequality-red.csv'))[0],report)
        with tempfile.TemporaryDirectory() as temp:
            destination=Path(temp)/'report.json';result=subprocess.run([sys.executable,str(script),'--output',str(destination),'--artifact-dir',str(Path(temp)/'artifacts')],cwd=temp,capture_output=True,text=True,check=True,timeout=90)
            self.assertEqual(json.loads(result.stdout),report);self.assertEqual(json.loads(destination.read_text()),report);self.assertFalse(destination.with_name('report.json.tmp').exists());self.assertTrue((Path(temp)/'artifacts/model.joblib').exists())

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(CapstoneBehaviorTests))
    if not result.wasSuccessful():raise SystemExit(1)
    (ROOT/'build/chapter-14-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':len(solutions),'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, {len(solutions)} solutions, {result.testsRun} behavior tests; reports/assets/artifacts agree.')
