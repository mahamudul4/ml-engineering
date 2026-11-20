"""Execute Chapter20 and independently audit Transformer visibility and numerics."""
import contextlib,hashlib,io,json,math,os,runpy,subprocess,sys,tempfile,types,unittest
from pathlib import Path
import numpy as np
import pandas as pd
import torch
from torch import nn
from torch.nn.functional import scaled_dot_product_attention as sdpa
ROOT=Path(__file__).resolve().parent.parent;os.chdir(ROOT);torch.set_num_threads(1)
chapter=json.loads((ROOT/'assets/content/chapter_20.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons','quizzes','exercises','interviews']]==[20,24,10,10]
scopes={};snippets=0
for lesson in chapter['lessons']:
    module=types.ModuleType(lesson['id']);sys.modules[lesson['id']]=module
    for b in lesson['blocks']:
        if b['type']=='code':
            with contextlib.redirect_stdout(io.StringIO()):exec(compile(b['body'],lesson['id'],'exec'),module.__dict__)
            snippets+=1
    scopes[lesson['id']]=module.__dict__
solutions={}
for e in chapter['exercises']:
    compile(e['starter'],e['id'],'exec');scope={}
    with contextlib.redirect_stdout(io.StringIO()):exec(e['solution'],scope)
    assert math.isclose(float(scope['answer']),e['expected'],abs_tol=1e-10),e['id']
    solutions[e['id']]=scope
api=scopes['ch20_experiment'];report,asset=api['report'],api['asset'];DATA=ROOT/'assets/datasets/bike_sharing'
def fitted():
    model=api['CountTransformer']();model.load_state_dict({k:torch.tensor(v,dtype=torch.float64) for k,v in asset['weights'].items()});return model.eval()
class AttentionBehaviorTests(unittest.TestCase):
    def test_original_source_calendar_roles_and_training_only_transform(self):
        self.assertEqual(hashlib.sha256((DATA/'day.csv').read_bytes()).hexdigest(),report['sha256'])
        dates,y,mean,scale=api['prepare'](DATA/'day.csv');original=pd.read_csv(DATA/'day.csv')
        self.assertEqual(len(original),731);self.assertEqual(len(y),547);self.assertEqual(dates[-1],'2012-06-30');self.assertEqual(report['reserved_outcomes_used'],0)
        self.assertEqual(mean,original.cnt.iloc[:365].mean());self.assertEqual(scale,original.cnt.iloc[:365].std(ddof=0))
        X,z,ids=api['windows'](y,mean,scale,14,365);self.assertEqual(X.shape,(351,14,1));self.assertEqual(z.shape,(351,))
        for q in asset['queries']:
            t=q['target_index'];np.testing.assert_array_equal(q['counts'],y[t-14:t]);self.assertEqual(q['outcome'],y[t]);self.assertEqual(q['history_dates'],dates[t-14:t]);self.assertLess(t,547)
        changed=y.copy();changed[400:]=999999;A,_,_=api['windows'](y,mean,scale,400,401);B,_,_=api['windows'](changed,mean,scale,400,401);torch.testing.assert_close(A,B)
    def test_all_fifteen_modes_against_modules_sdpa_and_manual_norm(self):
        model=fitted()
        for q in asset['queries']:
            X=torch.tensor(q['standardized'],dtype=torch.float64).reshape(1,14,1)
            for r in q['references']:
                with torch.no_grad():actual=model.inspect(X,r['causal'],r['valid'],r['use_position'])
                trace=r['trace'];own=api['manual'](q['standardized'],asset['weights'],r['causal'],r['valid'],r['use_position']);self.assertEqual(own,trace)
                for key,v in actual.items():np.testing.assert_allclose(trace[key],v[0],atol=2e-11,rtol=2e-11)
                allowed=(torch.arange(14)[None,:]<r['valid']).expand(14,14).clone()
                if r['causal']:allowed&=torch.ones(14,14,dtype=torch.bool).tril()
                Q,K,V=[torch.tensor(trace[key],dtype=torch.float64)[None] for key in ['q','k','v']]
                mixed=sdpa(Q,K,V,attn_mask=allowed,dropout_p=0.)
                np.testing.assert_allclose(trace['mixed'],mixed[0],atol=1e-12)
                x=np.array(trace['embedding']);expected=(x-x.mean(-1,keepdims=True))/np.sqrt(x.var(-1,keepdims=True)+1e-5)*np.array(asset['weights']['norm1.weight'])+np.array(asset['weights']['norm1.bias']);np.testing.assert_allclose(expected,trace['norm1'],atol=1e-12)
    def test_mask_polarity_padding_query_semantics_and_future_prefix_invariance(self):
        model=fitted();s=np.array(asset['queries'][0]['standardized']);X=torch.tensor(s,dtype=torch.float64).reshape(1,14,1);changed=X.clone();changed[:,6:10]=changed[:,6:10].flip(1)
        with torch.no_grad():last_causal=model.inspect(X);last_full=model.inspect(X,causal=False)
        torch.testing.assert_close(last_causal['state'][:,-1],last_full['state'][:,-1]);torch.testing.assert_close(last_causal['prediction'],last_full['prediction'])
        with torch.no_grad():causal=model.inspect(X,valid=10);other=model.inspect(changed,valid=10);full=model.inspect(X,causal=False,valid=10);full_other=model.inspect(changed,causal=False,valid=10)
        torch.testing.assert_close(causal['state'][:,:6],other['state'][:,:6]);self.assertGreater((full['state'][:,5]-full_other['state'][:,5]).abs().max().item(),1e-8)
        self.assertTrue(torch.equal(causal['weights'][:,:,:,10:],torch.zeros_like(causal['weights'][:,:,:,10:])));self.assertTrue(torch.isfinite(causal['state'][:,10:]).all())
        padding_changed=X.clone();padding_changed[:,10:]=999999
        with torch.no_grad():p=model.inspect(padding_changed,valid=10)
        torch.testing.assert_close(causal['state'][:,:10],p['state'][:,:10])
        # MHA blocked mask and SDPA allowed mask must be complements.
        allowed=torch.ones(14,14,dtype=torch.bool).tril();trace=api['manual'](s,asset['weights']);Q,K,V=[torch.tensor(trace[k],dtype=torch.float64)[None] for k in ['q','k','v']]
        np.testing.assert_allclose(sdpa(Q,K,V,attn_mask=allowed,dropout_p=0.)[0],trace['mixed'],atol=1e-12)
        self.assertGreater((sdpa(Q,K,V,attn_mask=~allowed,dropout_p=0.)-sdpa(Q,K,V,attn_mask=allowed,dropout_p=0.)).abs().max().item(),1e-3)
        for valid in [0,15]:
            with self.assertRaises(ValueError):model.inspect(X,valid=valid)
    def test_positions_unmasked_equivariance_and_cached_single_query_offsets(self):
        model=fitted();X=torch.tensor(asset['queries'][0]['standardized'],dtype=torch.float64).reshape(1,14,1);order=torch.arange(13,-1,-1)
        with torch.no_grad():base=model.inspect(X,causal=False,use_position=False);permuted=model.inspect(X[:,order],causal=False,use_position=False)
        torch.testing.assert_close(base['state'][:,order],permuted['state'],atol=1e-11,rtol=1e-11)
        pe=api['positions']();np.testing.assert_allclose(pe[0],[0,1,0,1]);np.testing.assert_allclose(pe[3],[np.sin(3),np.cos(3),np.sin(.03),np.cos(.03)])
        trace=asset['queries'][0]['references'][0]['trace'];Q,K,V=[torch.tensor(trace[k],dtype=torch.float64)[None] for k in ['q','k','v']]
        full=sdpa(Q,K,V,is_causal=True,dropout_p=0.);last=sdpa(Q[:,:,-1:],K,V,dropout_p=0.)
        torch.testing.assert_close(full[:,:,-1:],last);self.assertGreater((last-sdpa(Q[:,:,-1:],K,V,is_causal=True,dropout_p=0.)).abs().max().item(),1e-3)
    def test_shared_attention_gradient_parameter_budget_and_state_buffers(self):
        m=fitted();self.assertEqual(sum(p.numel() for p in m.parameters()),185);self.assertEqual(m.position.numel(),56)
        X=torch.tensor(asset['queries'][1]['standardized'],dtype=torch.float64).reshape(1,14,1);self.assertEqual(m(X).shape,(1,));m(X).square().sum().backward()
        p=m.attn.in_proj_weight;old=p[10,2].item();analytic=p.grad[10,2].item();eps=1e-6
        with torch.no_grad():p[10,2]=old+eps;hi=m(X).square().sum().item();p[10,2]=old-eps;lo=m(X).square().sum().item();p[10,2]=old
        self.assertAlmostEqual(analytic,(hi-lo)/(2*eps),places=6)
        for bad in [torch.zeros(1,13,1,dtype=torch.float64),torch.full((1,14,1),float('nan'),dtype=torch.float64)]:
            with self.assertRaises(ValueError):m(bad)
    def test_independent_metrics_preserve_mae_rmse_tradeoff_and_inference_scope(self):
        model=fitted();_,y,mean,scale=api['prepare'](DATA/'day.csv');X,_,ids=api['windows'](y,mean,scale,365,547)
        with torch.no_grad():pred=model(X).numpy()*scale+mean
        for name,p in [('transformer',pred),('naive',y[ids-1]),('seasonal7',y[ids-7])]:
            self.assertAlmostEqual(np.abs(p-y[ids]).mean(),report['rolling_one_step'][name]['mae'],places=9);self.assertAlmostEqual(np.sqrt(np.mean((p-y[ids])**2)),report['rolling_one_step'][name]['rmse'],places=9)
        self.assertGreater(report['rolling_one_step']['transformer']['mae'],report['rolling_one_step']['naive']['mae']);self.assertLess(report['rolling_one_step']['transformer']['rmse'],report['rolling_one_step']['naive']['rmse'])
    def test_reproducible_artifacts_checksums_and_unchanged_training_recipe(self):
        self.assertEqual(asset,json.loads((DATA/'attention_lab.json').read_text()));self.assertEqual(len(asset['train_history']),81);self.assertLess(report['final_train_mse_scaled'],report['initial_train_mse_scaled'])
        with tempfile.TemporaryDirectory() as temp:
            own,own_asset=api['run_analysis'](DATA/'day.csv',Path(temp));self.assertEqual(own,report);self.assertEqual(own_asset,asset)
            for name,digest in json.loads((Path(temp)/'checksums.json').read_text()).items():self.assertEqual(hashlib.sha256((Path(temp)/name).read_bytes()).hexdigest(),digest)
            m=api['CountTransformer']();m.load_state_dict(torch.load(Path(temp)/'transformer.pt',weights_only=True,map_location='cpu'));self.assertEqual(api['weights'](m),asset['weights']);self.assertEqual(json.loads((Path(temp)/'schema.json').read_text())['parameters'],185)
    def test_import_safe_external_cli_rng_threads_and_source_immutability(self):
        script=DATA/'attention_workflow.py';before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()};out=io.StringIO()
        with contextlib.redirect_stdout(out):module=runpy.run_path(str(script))
        self.assertEqual(out.getvalue(),'');rng=torch.get_rng_state().clone();torch.set_num_threads(2)
        try:own,own_asset=module['run_analysis'](DATA/'day.csv');self.assertEqual(torch.get_num_threads(),2)
        finally:torch.set_num_threads(1)
        torch.testing.assert_close(rng,torch.get_rng_state());self.assertEqual(own,report);self.assertEqual(own_asset,asset)
        with tempfile.TemporaryDirectory() as temp:
            dest=Path(temp)/'report.json';r=subprocess.run([sys.executable,str(script),'--output',str(dest)],cwd=temp,capture_output=True,text=True,check=True,timeout=120)
            self.assertEqual(json.loads(r.stdout),report);self.assertEqual(json.loads(dest.read_text()),report);self.assertFalse(dest.with_name(dest.name+'.tmp').exists())
        self.assertEqual(before,{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()})
if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2,stream=sys.stdout).run(unittest.defaultTestLoader.loadTestsFromTestCase(AttentionBehaviorTests))
    if not result.wasSuccessful():raise SystemExit(1)
    (ROOT/'build/chapter-20-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':len(solutions),'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, {len(solutions)} solutions, {result.testsRun} behavior tests; attention, visibility and full Transformer verified.')
