"""Execute Chapter21 and independently audit the grouped white-wine capstone."""
import contextlib,hashlib,io,json,math,os,runpy,subprocess,sys,tempfile,types,unittest
from pathlib import Path
import joblib,numpy as np,pandas as pd,torch
from torch import nn
from sklearn.metrics import average_precision_score,roc_auc_score,brier_score_loss,confusion_matrix
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from threadpoolctl import threadpool_limits
ROOT=Path(__file__).resolve().parent.parent;os.chdir(ROOT);torch.set_num_threads(1)
chapter=json.loads((ROOT/'assets/content/chapter_21.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons','quizzes','exercises','interviews']]==[20,24,10,10]
scopes={};snippets=0
for lesson in chapter['lessons']:
    module=types.ModuleType(lesson['id']);sys.modules[lesson['id']]=module
    for b in lesson['blocks']:
        if b['type']=='code':
            with contextlib.redirect_stdout(io.StringIO()),threadpool_limits(limits=1):exec(compile(b['body'],lesson['id'],'exec'),module.__dict__)
            snippets+=1
    scopes[lesson['id']]=module.__dict__
solutions={}
for e in chapter['exercises']:
    compile(e['starter'],e['id'],'exec');scope={}
    with contextlib.redirect_stdout(io.StringIO()):exec(e['solution'],scope)
    assert math.isclose(float(scope['answer']),e['expected'],abs_tol=1e-10),e['id']
    solutions[e['id']]=scope
api=scopes['ch21_experiment'];report,asset=api['report'],api['asset'];DATA=ROOT/'assets/datasets/wine_quality'
def pipeline(entry):
    m=api['WineMLP']();p=entry['weights']
    with torch.no_grad():
        m.hidden.weight.copy_(torch.tensor(p['w1'],dtype=torch.float64));m.hidden.bias.copy_(torch.tensor(p['b1'],dtype=torch.float64));m.output.weight.copy_(torch.tensor([p['w2']],dtype=torch.float64));m.output.bias.fill_(p['b2'])
    return {'model':m.eval(),'mean':np.array(entry['mean']),'scale':np.array(entry['scale'])}
def independent_metrics(y,p,t):
    tn,fp,fn,tp=confusion_matrix(y,p>=t,labels=[0,1]).ravel()
    return {'ap':float(average_precision_score(y,p)),'roc_auc':float(roc_auc_score(y,p)),'brier':float(np.mean((p-y)**2)),'tn':int(tn),'fp':int(fp),'fn':int(fn),'tp':int(tp),'mean_cost':float((fp+4*fn)/len(y))}
class DeepCapstoneBehaviorTests(unittest.TestCase):
    def test_source_original_bytes_profile_identity_roles_and_no_test_rows_in_labs(self):
        f,X,y,g=api['load_source'](DATA/'winequality-white.csv');roles=api['split_roles'](X,y,g)
        manifest=json.loads((DATA/'white_source_manifest.json').read_text());self.assertEqual(hashlib.sha256((DATA/'winequality-white.csv').read_bytes()).hexdigest(),manifest['sha256']);self.assertEqual(manifest['sha256'],report['sha256'])
        self.assertEqual(X.shape,(4898,11));self.assertEqual(len(np.unique(g)),3961);self.assertEqual(len(X)-len(np.unique(g)),937)
        self.assertEqual({k:len(v) for k,v in roles.items()},{'fit':2975,'decision':955,'test':968})
        for left in roles:
            for right in roles:
                if left!=right:self.assertTrue(set(g[roles[left]]).isdisjoint(g[roles[right]]))
        self.assertEqual(set(np.concatenate(list(roles.values()))),set(range(4898)))
        self.assertEqual(asset['fit_rows_1based'],(roles['fit']+1).tolist());self.assertEqual(asset['decision_rows_1based'],(roles['decision']+1).tolist())
        for s in asset['samples']:
            i=s['source_row_1based']-1;self.assertIn(i,roles['decision']);self.assertNotIn(i,roles['test']);np.testing.assert_array_equal(s['raw'],X[i]);self.assertEqual(s['quality'],int(f.quality.iloc[i]))
        self.assertEqual([s['source_row_1based'] for s in asset['samples']],[3,6,11]);self.assertEqual(asset['selection']['test_rows_in_labs'],0)
    def test_fold_only_scalers_grouped_cv_means_and_declared_selection(self):
        _,X,y,g=api['load_source'](DATA/'winequality-white.csv');fit=api['split_roles'](X,y,g)['fit'];folds=list(StratifiedGroupKFold(3,shuffle=True,random_state=23).split(X[fit],y[fit],g[fit]));scores={k:[] for k in ['prior','logistic','mlp']}
        with threadpool_limits(limits=1):
            for tr,va in folds:
                self.assertTrue(set(g[fit][tr]).isdisjoint(g[fit][va]))
                logistic=make_pipeline(StandardScaler(),LogisticRegression(C=1,max_iter=2000,random_state=21)).fit(X[fit][tr],y[fit][tr])
                mlp=api['fit_mlp'](X[fit][tr],y[fit][tr]);np.testing.assert_allclose(mlp['mean'],X[fit][tr].mean(0),atol=1e-12);np.testing.assert_allclose(mlp['scale'],X[fit][tr].std(0),atol=1e-12)
                scores['prior'].append(average_precision_score(y[fit][va],np.full(len(va),y[fit][tr].mean())))
                scores['logistic'].append(average_precision_score(y[fit][va],logistic.predict_proba(X[fit][va])[:,1]));scores['mlp'].append(average_precision_score(y[fit][va],api['predict']('mlp',mlp,X[fit][va])))
        for c in report['candidates']:np.testing.assert_allclose(scores[c['id']],c['fold_ap'],atol=1e-12);self.assertAlmostEqual(np.mean(scores[c['id']]),c['mean_ap'],places=12)
        winner=min(report['candidates'],key=lambda c:(-c['mean_ap'],c['declared_order']))['id'];self.assertEqual(winner,'mlp')
    def test_actual_forward_chain_bce_gradient_and_finite_difference(self):
        for entry in asset['pipelines']:
            m=pipeline(entry);self.assertEqual(sum(p.numel() for p in m['model'].parameters()),105)
            for s in asset['samples']:
                p=entry['weights'];x=(np.array(s['raw'])-m['mean'])/m['scale'];pre=np.array(p['w1'])@x+p['b1'];h=np.maximum(0,pre);z=float(np.array(p['w2'])@h+p['b2']);r=next(r for r in s['references'] if r['id']==entry['id'])
                np.testing.assert_allclose(x,r['standardized'],atol=1e-12);np.testing.assert_allclose(pre,r['pre'],atol=1e-12);np.testing.assert_allclose(h,r['hidden'],atol=1e-12);self.assertAlmostEqual(z,r['logit'],places=12)
        m=pipeline(asset['pipelines'][0]);X=torch.tensor((np.array([s['raw'] for s in asset['samples']])-m['mean'])/m['scale'],dtype=torch.float64);y=torch.tensor([s['quality']>=6 for s in asset['samples']],dtype=torch.float64)
        model=m['model'];z=model(X);self.assertEqual(z.shape,(3,));loss=nn.functional.binary_cross_entropy_with_logits(z,y);loss.backward()
        p=model.hidden.weight;index=np.unravel_index(p.grad.abs().argmax().item(),p.shape);old=p[index].item();analytic=p.grad[index].item();eps=1e-6;self.assertGreater(abs(analytic),1e-6)
        with torch.no_grad():p[index]=old+eps;hi=nn.functional.binary_cross_entropy_with_logits(model(X),y).item();p[index]=old-eps;lo=nn.functional.binary_cross_entropy_with_logits(model(X),y).item();p[index]=old
        self.assertAlmostEqual(analytic,(hi-lo)/(2*eps),places=7)
        extreme=torch.tensor([-1000.,1000.],dtype=torch.float64,requires_grad=True);target=torch.tensor([0.,1.],dtype=torch.float64);bce=nn.functional.binary_cross_entropy_with_logits(extreme,target);bce.backward();self.assertTrue(torch.isfinite(bce));self.assertTrue(torch.isfinite(extreme.grad).all())
    def test_decision_policy_grid_boundaries_costs_and_metric_objective_separation(self):
        rows=asset['decision_rows'];y=np.array([r['positive'] for r in rows]);p=np.array([r['probability'] for r in rows]);records=[]
        for reference in asset['policy_curve']:
            t=reference['threshold'];r=independent_metrics(y,p,t)
            for key in ['tn','fp','fn','tp','mean_cost']:self.assertAlmostEqual(r[key],reference[key],places=12)
            records.append(r|{'threshold':t})
        best=min(records,key=lambda r:(r['mean_cost'],-r['threshold']));self.assertEqual(best['threshold'],.25);self.assertEqual(best['threshold'],report['threshold'])
        zero=api['policy_metrics'](y,p,0);self.assertEqual([zero[k] for k in ['tn','fp','fn','tp']],[0,335,0,620])
        self.assertEqual(api['policy_metrics']([0,1],[.25,.25],.25)['fp'],1);self.assertIsNone(api['policy_metrics']([0,1],[.2,.8],1)['precision'])
        self.assertEqual(api['choose_policy']([1,1],[.1,.9],cost_fn=0)[0]['threshold'],.95)
        self.assertLess(report['decision']['logistic']['mean_cost'],report['decision']['mlp']['mean_cost']);self.assertEqual(report['winner'],'mlp')
    def test_ablation_common_initial_state_fixed_budget_and_fit_only_refit(self):
        _,X,y,g=api['load_source'](DATA/'winequality-white.csv');roles=api['split_roles'](X,y,g);fit=roles['fit'];left,right=asset['pipelines']
        self.assertEqual(left['initial'],right['initial']);np.testing.assert_allclose(left['mean'],X[fit].mean(0),atol=1e-12);np.testing.assert_allclose(left['scale'],X[fit].std(0),atol=1e-12)
        np.testing.assert_array_equal(right['mean'],np.zeros(11));np.testing.assert_array_equal(right['scale'],np.ones(11));self.assertEqual(len(left['history']),81);self.assertEqual(len(right['history']),81)
        p=api['predict']('mlp',pipeline(right),X[roles['decision']]);self.assertAlmostEqual(average_precision_score(y[roles['decision']],p),report['no_scale_diagnostic']['ap'],places=12)
        self.assertLess(report['no_scale_diagnostic']['ap'],report['decision']['mlp']['ap']);self.assertEqual([c['id'] for c in report['candidates']],['prior','logistic','mlp'])
    def test_locked_final_metrics_and_fixed_prediction_group_bootstrap_are_recomputed(self):
        _,X,y,g=api['load_source'](DATA/'winequality-white.csv');test=api['split_roles'](X,y,g)['test'];p=api['predict']('mlp',pipeline(asset['pipelines'][0]),X[test]);actual=independent_metrics(y[test],p,.25)
        for key,v in actual.items():self.assertAlmostEqual(v,report['final_test'][key],places=12)
        reference=report['final_all_positive_reference'];self.assertEqual([reference[k] for k in ['tn','fp','fn','tp']],[0,317,0,651]);self.assertAlmostEqual(reference['mean_cost'],317/968,places=12);self.assertGreater(report['final_test']['mean_cost'],reference['mean_cost'])
        unique=np.unique(g[test]);members=[np.flatnonzero(g[test]==key) for key in unique];rng=np.random.default_rng(24);aps=[];costs=[]
        for _ in range(200):
            rows=np.concatenate([members[i] for i in rng.integers(0,len(unique),size=len(unique))]);truth=y[test][rows];prob=p[rows]
            if len(np.unique(truth))==2:aps.append(average_precision_score(truth,prob))
            costs.append((((prob>=.25)&(truth==0)).sum()+4*((prob<.25)&(truth==1)).sum())/len(rows))
        intervals=report['fixed_prediction_group_bootstrap'];np.testing.assert_allclose(np.quantile(aps,[.025,.975]),intervals['ap_percentile95'],atol=1e-12);np.testing.assert_allclose(np.quantile(costs,[.025,.975]),intervals['mean_cost_percentile95'],atol=1e-12)
    def test_reproducible_artifacts_model_card_golden_rows_and_trusted_reload(self):
        self.assertEqual(asset,json.loads((DATA/'deep_capstone_lab.json').read_text()));self.assertLess(report['final_train_bce'],report['initial_train_bce'])
        with tempfile.TemporaryDirectory() as temp:
            own,own_asset=api['run_analysis'](DATA/'winequality-white.csv',Path(temp));self.assertEqual(own,report);self.assertEqual(own_asset,asset)
            for name,digest in json.loads((Path(temp)/'checksums.json').read_text()).items():self.assertEqual(hashlib.sha256((Path(temp)/name).read_bytes()).hexdigest(),digest)
            m=api['WineMLP']();m.load_state_dict(torch.load(Path(temp)/'mlp.pt',weights_only=True,map_location='cpu'));self.assertEqual(api['weights'](m),asset['pipelines'][0]['weights'])
            schema=json.loads((Path(temp)/'schema.json').read_text());self.assertEqual(schema['features'],api['FEATURES']);self.assertEqual(json.loads((Path(temp)/'golden.json').read_text()),asset['samples']);self.assertEqual(json.loads((Path(temp)/'model_card.json').read_text())['final_test'],report['final_test'])
            _,X,y,g=api['load_source'](DATA/'winequality-white.csv');ids=api['split_roles'](X,y,g)['decision'];logistic=joblib.load(Path(temp)/'logistic.joblib');self.assertAlmostEqual(average_precision_score(y[ids],logistic.predict_proba(X[ids])[:,1]),report['decision']['logistic']['ap'],places=12)
    def test_import_safe_external_cli_rng_threads_and_unchanged_assets(self):
        script=DATA/'deep_capstone_workflow.py';before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()};out=io.StringIO()
        with contextlib.redirect_stdout(out):module=runpy.run_path(str(script))
        self.assertEqual(out.getvalue(),'');rng=torch.get_rng_state().clone();torch.set_num_threads(2)
        try:own,own_asset=module['run_analysis'](DATA/'winequality-white.csv');self.assertEqual(torch.get_num_threads(),2)
        finally:torch.set_num_threads(1)
        torch.testing.assert_close(rng,torch.get_rng_state());self.assertEqual(own,report);self.assertEqual(own_asset,asset)
        with tempfile.TemporaryDirectory() as temp:
            dest=Path(temp)/'report.json';r=subprocess.run([sys.executable,str(script),'--output',str(dest)],cwd=temp,capture_output=True,text=True,check=True,timeout=120)
            self.assertEqual(json.loads(r.stdout),report);self.assertEqual(json.loads(dest.read_text()),report);self.assertFalse(dest.with_name(dest.name+'.tmp').exists())
        self.assertEqual(before,{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()})
if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2,stream=sys.stdout).run(unittest.defaultTestLoader.loadTestsFromTestCase(DeepCapstoneBehaviorTests))
    if not result.wasSuccessful():raise SystemExit(1)
    (ROOT/'build/chapter-21-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':len(solutions),'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, {len(solutions)} solutions, {result.testsRun} behavior tests; grouped capstone, policy and artifact contracts verified.')
