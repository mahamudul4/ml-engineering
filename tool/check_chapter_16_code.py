"""Execute every Chapter16 example/solution and independently audit MLP training."""
import contextlib,hashlib,io,json,math,os,runpy,subprocess,sys,tempfile,types,unittest
from pathlib import Path
import numpy as np
import torch
from torch import nn
import torch.nn.functional as F

ROOT=Path(__file__).resolve().parent.parent;os.chdir(ROOT);torch.set_num_threads(1)
chapter=json.loads((ROOT/'assets/content/chapter_16.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons','quizzes','exercises','interviews']]==[20,24,10,10]
scopes={};snippets=0
for lesson in chapter['lessons']:
    module=types.ModuleType(lesson['id']);sys.modules[lesson['id']]=module
    for block in lesson['blocks']:
        if block['type']=='code':
            with contextlib.redirect_stdout(io.StringIO()):exec(compile(block['body'],lesson['id'],'exec'),module.__dict__)
            snippets+=1
    scopes[lesson['id']]=module.__dict__
solutions={}
for e in chapter['exercises']:
    compile(e['starter'],e['id'],'exec');scope={}
    with contextlib.redirect_stdout(io.StringIO()):exec(e['solution'],scope)
    assert math.isclose(float(scope['answer']),e['expected'],abs_tol=1e-10),e['id']
    solutions[e['id']]=scope
api=scopes['ch16_experiment'];report,asset,model=api['report'],api['asset'],api['model'];DATA=ROOT/'assets/datasets/wine_quality'

def independent(p):
    m=nn.Sequential(nn.Linear(11,4,dtype=torch.float64),nn.ReLU(),nn.Linear(4,1,dtype=torch.float64))
    with torch.no_grad():
        m[0].weight.copy_(torch.tensor(p['w1'],dtype=torch.float64));m[0].bias.copy_(torch.tensor(p['b1'],dtype=torch.float64));m[2].weight.copy_(torch.tensor(p['w2'],dtype=torch.float64)[None]);m[2].bias.copy_(torch.tensor([p['b2']],dtype=torch.float64))
    return m

class NeuralBehaviorTests(unittest.TestCase):
    def test_manual_invalid_contracts_and_no_input_mutation(self):
        X=np.array([s['standardized'] for s in asset['samples']]);y=np.array([s['positive'] for s in asset['samples']]);p=asset['checkpoints'][0]['parameters'];before=json.dumps(p)
        api['manual'](X,y,p)
        for xx,yy,pp in [(X[:0],y[:0],p),(X,y[:,None],p),(X[:,:10],y,p),(X,np.full(8,2),p),(X*float('nan'),y,p),(X,y,{**p,'w2':[1,2]})]:
            with self.assertRaises(ValueError):api['manual'](xx,yy,pp)
        for kwargs in [{'reduction':'bad'},{'activation':'bad'}]:
            with self.assertRaises(ValueError):api['manual'](X,y,p,**kwargs)
        self.assertEqual(before,json.dumps(p))

    def test_all_forward_checkpoints_match_independent_module(self):
        X=torch.tensor([s['standardized'] for s in asset['samples']],dtype=torch.float64);y=torch.tensor([s['positive'] for s in asset['samples']],dtype=torch.float64)
        for c in asset['checkpoints']:
            m=independent(c['parameters']);result=api['manual'](X,y,c['parameters'])
            with torch.no_grad():z=m(X).squeeze(-1);h=m[1](m[0](X))
            np.testing.assert_allclose(result['logits'],z,atol=1e-12,rtol=1e-12);np.testing.assert_allclose(result['hidden'],h,atol=1e-12,rtol=1e-12)
            # Single-row serving preserves batch dimension.
            self.assertEqual(m(X[:1]).squeeze(-1).shape,(1,))

    def test_all_chain_rule_refs_mean_sum_activation_and_finite_differences(self):
        X=np.array([s['standardized'] for s in asset['samples']]);y=np.array([s['positive'] for s in asset['samples']])
        for r in asset['backprop_references']:
            p=next(c['parameters'] for c in asset['checkpoints'] if c['epoch']==r['epoch']);own=api['manual'](X,y,p,r['reduction'],r['activation'])
            for k,v in own.items():np.testing.assert_allclose(v,r[k],atol=1e-13)
            # Independently perturb a hidden weight at a smooth point.
            z1=np.array(r['z1']);self.assertGreater(np.min(np.abs(z1)),1e-5)
            eps=1e-6;plus=json.loads(json.dumps(p));minus=json.loads(json.dumps(p));plus['w1'][0][0]+=eps;minus['w1'][0][0]-=eps
            finite=(api['manual'](X,y,plus,r['reduction'],r['activation'])['loss']-api['manual'](X,y,minus,r['reduction'],r['activation'])['loss'])/(2*eps)
            self.assertAlmostEqual(finite,r['dw1'][0][0],places=8)
        for epoch in [0,120]:
            mean=next(r for r in asset['backprop_references'] if r['epoch']==epoch and r['activation']=='relu' and r['reduction']=='mean')
            summed=next(r for r in asset['backprop_references'] if r['epoch']==epoch and r['activation']=='relu' and r['reduction']=='sum')
            for key in ['dw1','db1','dw2','db2']:np.testing.assert_allclose(np.array(mean[key])*8,summed[key],atol=1e-13)

    def test_detached_hidden_none_versus_connected_inactive_zero(self):
        p=asset['checkpoints'][0]['parameters'];m=independent(p);X=torch.tensor([s['standardized'] for s in asset['samples']],dtype=torch.float64);y=torch.tensor([s['positive'] for s in asset['samples']],dtype=torch.float64)
        h=torch.relu(m[0](X));logits=m[2](h.detach()).squeeze(-1);F.binary_cross_entropy_with_logits(logits,y).backward()
        self.assertIsNone(m[0].weight.grad);self.assertIsNotNone(m[2].weight.grad)
        expected=api['manual'](X,y,p);np.testing.assert_allclose(m[2].weight.grad.detach()[0],expected['dw2'],atol=1e-12)
        m.zero_grad(set_to_none=True)
        with torch.no_grad():m[0].weight.zero_();m[0].bias.fill_(-100)
        F.binary_cross_entropy_with_logits(m(X).squeeze(-1),y).backward()
        self.assertIsNotNone(m[0].weight.grad);self.assertEqual(torch.count_nonzero(m[0].weight.grad).item(),0)

    def test_registered_parameters_step_updates_and_loss_semantics(self):
        m=api['WineMLP']();self.assertEqual(sum(p.numel() for p in m.parameters()),53);self.assertEqual(len(list(m.named_parameters())),4)
        X=torch.ones(2,11,dtype=torch.float64);y=torch.tensor([0.,1.],dtype=torch.float64);optimizer=torch.optim.SGD(m.parameters(),lr=.05)
        before=[p.detach().clone() for p in m.parameters()];optimizer.zero_grad(set_to_none=True);loss=F.binary_cross_entropy_with_logits(m(X),y);loss.backward();g=[p.grad.clone() for p in m.parameters()];optimizer.step()
        for old,grad,new in zip(before,g,m.parameters()):torch.testing.assert_close(new,old-.05*grad)
        m.eval();self.assertTrue(m(X).requires_grad)
        with torch.no_grad():self.assertFalse(m(X).requires_grad)
        for z in [-1000.,1000.]:self.assertTrue(torch.isfinite(F.binary_cross_entropy_with_logits(torch.tensor(z),torch.tensor(1.))))

    def test_source_group_roles_preprocessing_and_reference_exclusion(self):
        frame,raw,y,groups,fit,train,val,mean,scale=api['prepare'](DATA/'winequality-red.csv')
        self.assertEqual((len(fit),len(train),len(val)),(966,776,190));self.assertTrue(set(groups[train]).isdisjoint(groups[val]));self.assertEqual(set(train)|set(val),set(fit))
        np.testing.assert_array_equal(mean,raw[train].mean(axis=0));np.testing.assert_array_equal(scale,raw[train].std(axis=0,ddof=0))
        self.assertGreater(np.max(np.abs(mean-raw[fit].mean(axis=0))),.001)
        for j,s in enumerate(asset['samples']):
            i=s['source_row_1based']-1;self.assertEqual(i,train[j]);self.assertNotIn(i,val);np.testing.assert_array_equal(s['raw'],raw[i]);np.testing.assert_allclose(s['standardized'],(raw[i]-mean)/scale,atol=1e-14);self.assertEqual(s['quality'],int(frame.quality.iloc[i]))
        self.assertFalse(any(k in report for k in ['test_accuracy','final_test','test_ap','decision_metrics']))
        self.assertEqual(asset,json.loads((DATA/'neural_lab.json').read_text()))

    def test_independent_full_training_trajectory_fixed_endpoint(self):
        _,raw,y,_,_,train,val,mean,scale=api['prepare'](DATA/'winequality-red.csv');X=torch.tensor((raw[train]-mean)/scale,dtype=torch.float64);V=torch.tensor((raw[val]-mean)/scale,dtype=torch.float64);ty=torch.tensor(y[train],dtype=torch.float64);vy=torch.tensor(y[val],dtype=torch.float64)
        # Float64 copy avoids a silent float32 round-trip in golden reproduction.
        p=asset['checkpoints'][0]['parameters'];m=nn.Sequential(nn.Linear(11,4,dtype=torch.float64),nn.ReLU(),nn.Linear(4,1,dtype=torch.float64))
        with torch.no_grad():
            m[0].weight.copy_(torch.tensor(p['w1'],dtype=torch.float64));m[0].bias.copy_(torch.tensor(p['b1'],dtype=torch.float64));m[2].weight.copy_(torch.tensor(p['w2'],dtype=torch.float64)[None]);m[2].bias.copy_(torch.tensor([p['b2']],dtype=torch.float64))
        opt=torch.optim.SGD(m.parameters(),lr=.05)
        for epoch,ref in enumerate(asset['history']):
            with torch.no_grad():
                self.assertAlmostEqual(F.binary_cross_entropy_with_logits(m(X).squeeze(-1),ty).item(),ref['train_bce'],places=13);self.assertAlmostEqual(F.binary_cross_entropy_with_logits(m(V).squeeze(-1),vy).item(),ref['validation_bce'],places=13)
            if epoch<120:opt.zero_grad(set_to_none=True);F.binary_cross_entropy_with_logits(m(X).squeeze(-1),ty).backward();opt.step()
        self.assertLess(report['final']['train_bce'],report['initial']['train_bce']);self.assertEqual(report['updates'],120)

    def test_import_safe_cli_rng_threads_and_no_implicit_asset_writes(self):
        script=DATA/'neural_workflow.py';before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()};out=io.StringIO()
        with contextlib.redirect_stdout(out):imported=runpy.run_path(str(script))
        self.assertEqual(out.getvalue(),'');rng=torch.get_rng_state().clone();torch.set_num_threads(2)
        try:own,own_asset,_=imported['run_analysis'](DATA/'winequality-red.csv');self.assertEqual(torch.get_num_threads(),2)
        finally:torch.set_num_threads(1)
        torch.testing.assert_close(rng,torch.get_rng_state());self.assertEqual(own,report);self.assertEqual(own_asset,asset)
        with tempfile.TemporaryDirectory() as temp:
            output=Path(temp)/'report.json';r=subprocess.run([sys.executable,str(script),'--output',str(output)],cwd=temp,capture_output=True,text=True,check=True,timeout=60)
            self.assertEqual(json.loads(r.stdout),report);self.assertEqual(json.loads(output.read_text()),report);self.assertFalse(output.with_name('report.json.tmp').exists())
        self.assertEqual(before,{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()})

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(NeuralBehaviorTests))
    if not result.wasSuccessful():raise SystemExit(1)
    (ROOT/'build/chapter-16-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':len(solutions),'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, {len(solutions)} solutions, {result.testsRun} behavior tests; MLP/backprop/history verified.')
