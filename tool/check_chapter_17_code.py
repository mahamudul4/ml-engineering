"""Execute Chapter17 and audit stateful updates, normalization and recovery."""
import contextlib,copy,hashlib,io,json,math,os,runpy,subprocess,sys,tempfile,types,unittest
from pathlib import Path
import numpy as np
import torch
from torch import nn
import torch.nn.functional as F
ROOT=Path(__file__).resolve().parent.parent;os.chdir(ROOT);torch.set_num_threads(1)
chapter=json.loads((ROOT/'assets/content/chapter_17.json').read_text(encoding='utf-8'))
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
api=scopes['ch17_experiment'];report,asset=api['report'],api['asset'];DATA=ROOT/'assets/datasets/wine_quality'

class ReliableBehaviorTests(unittest.TestCase):
    def test_optimizer_replay_independent_recurrences_and_pytorch_golden(self):
        data=asset['optimizers'];initial=np.array(data['initial']);gradient=np.array(data['gradient'])
        for ref in data['replay']:
            p=initial.copy();m=np.zeros(3);v=np.zeros(3);rows=[p.copy()]
            for step in range(1,4):
                g=gradient+(0 if ref['kind']=='adamw' else .1*p)
                if ref['kind']=='sgd':p=p-.01*g
                elif ref['kind']=='momentum':m=.9*m+g;p=p-.01*m
                else:
                    m=.9*m+.1*g;v=.999*v+.001*g*g
                    if ref['kind']=='adamw':p=p*(1-.01*.1)
                    p=p-.01*(m/(1-.9**step))/(np.sqrt(v/(1-.999**step))+1e-8)
                rows.append(p.copy())
            np.testing.assert_allclose(rows,ref['values'],atol=1e-13,rtol=1e-13)
        self.assertNotEqual(data['replay'][2]['values'],data['replay'][3]['values'])

    def test_normalization_biased_unbiased_axes_running_stats_and_layernorm(self):
        d=asset['normalization'];X=np.array(d['input']);mean=X.mean(0);biased=X.var(0);unbiased=X.var(0,ddof=1)
        np.testing.assert_allclose(d['bn_train'],(X-mean)/np.sqrt(biased+1e-5),atol=1e-12)
        np.testing.assert_allclose(d['running_mean'],.1*mean,atol=1e-13);np.testing.assert_allclose(d['running_var'],.9+.1*unbiased,atol=1e-13)
        np.testing.assert_allclose(d['bn_eval'],(X-d['running_mean'])/np.sqrt(np.array(d['running_var'])+1e-5),atol=1e-12)
        np.testing.assert_allclose(d['layer_norm'],(X-X.mean(1,keepdims=True))/np.sqrt(X.var(1,keepdims=True)+1e-5),atol=1e-12)
        ln=nn.LayerNorm(4,elementwise_affine=False,dtype=torch.float64);xx=torch.tensor(X,dtype=torch.float64);torch.testing.assert_close(ln(xx[:1]),ln(xx)[:1])
        bn=nn.BatchNorm1d(4,affine=False,dtype=torch.float64)
        with self.assertRaises(ValueError):bn(xx[:1])

    def test_dropout_rng_modes_and_bn_no_grad_buffer_mutation(self):
        drop=nn.Dropout(.2);x=torch.ones(16,dtype=torch.float64);state=torch.get_rng_state().clone()
        with torch.no_grad():first=drop(x)
        torch.set_rng_state(state)
        with torch.no_grad():second=drop(x)
        torch.testing.assert_close(first,second);self.assertTrue(set(first.tolist())<={0.,1.25})
        drop.eval();torch.testing.assert_close(drop(x),x)
        bn=nn.BatchNorm1d(4,dtype=torch.float64);xx=torch.tensor(asset['normalization']['input'],dtype=torch.float64);before=bn.running_mean.clone()
        with torch.no_grad():bn(xx)
        self.assertFalse(torch.equal(before,bn.running_mean));bn.eval();before=bn.running_mean.clone()
        with torch.no_grad():bn(xx)
        torch.testing.assert_close(before,bn.running_mean)

    def test_zero_none_decay_clipping_nonfinite_and_scheduler_boundary(self):
        p=nn.Parameter(torch.tensor(2.,dtype=torch.float64));opt=torch.optim.AdamW([p],lr=.1,weight_decay=.2)
        p.grad=None;opt.step();self.assertEqual(p.item(),2);p.grad=torch.zeros_like(p);opt.step();self.assertAlmostEqual(p.item(),1.96)
        p=nn.Parameter(torch.zeros(2,dtype=torch.float64));p.grad=torch.tensor([3.,4.],dtype=torch.float64);norm=nn.utils.clip_grad_norm_([p],1.,foreach=False,error_if_nonfinite=True);self.assertEqual(norm.item(),5);self.assertLessEqual(p.grad.norm().item(),1.)
        p.grad.fill_(float('nan'))
        with self.assertRaises(RuntimeError):nn.utils.clip_grad_norm_([p],1.,error_if_nonfinite=True)
        history=asset['continuous_history'];self.assertEqual(history[20]['used_lr'],.01);self.assertEqual(history[20]['next_lr'],.005);self.assertEqual(history[21]['used_lr'],.005);self.assertEqual(history[40]['next_lr'],.0025)
        self.assertEqual(sum(r['updates'] for r in history[1:]),520)

    def test_actual_source_scope_and_initial_activation_gradient_provenance(self):
        module,prepared,X,y,V,vy=api['source'](DATA/'winequality-red.csv');_,raw,labels,groups,fit,train,val,mean,scale=prepared
        self.assertEqual((len(train),len(val),len(fit)),(776,190,966));self.assertTrue(set(groups[train]).isdisjoint(groups[val]));np.testing.assert_array_equal(mean,raw[train].mean(0));np.testing.assert_array_equal(scale,raw[train].std(0))
        self.assertEqual(asset['source_rows_1based'],(train[:8]+1).tolist());self.assertTrue(set(train[:8]).isdisjoint(val));self.assertFalse(any(k in report for k in ['test_accuracy','outer_test','test_ap']))
        with torch.random.fork_rng(devices=[]):
            torch.manual_seed(17);model,_,_,_=api['setup'](module);model.eval();z=model.hidden(X[:8]);F.binary_cross_entropy_with_logits(model(X[:8]),y[:8]).backward()
            np.testing.assert_allclose(z.detach(),asset['normalization']['input'],atol=1e-13);np.testing.assert_allclose([model.hidden.weight.grad[0,0].item(),model.hidden.weight.grad[1,1].item(),model.output.bias.grad[0].item()],asset['optimizers']['gradient'],atol=1e-13)
        self.assertEqual(asset,json.loads((DATA/'reliable_lab.json').read_text()))

    def test_checkpoint_actual_file_roundtrip_exact_resume_and_warm_divergence(self):
        module,prepared,X,y,V,vy=api['source'](DATA/'winequality-red.csv')
        with tempfile.TemporaryDirectory() as temp:
            own,own_asset=api['run_analysis'](DATA/'winequality-red.csv',Path(temp));self.assertEqual(own,report);self.assertEqual(own_asset,asset)
            state=torch.load(Path(temp)/'epoch-20.pt',weights_only=True,map_location='cpu');self.assertEqual(state['epoch'],20);self.assertEqual(state['scheduler']['last_epoch'],20)
            self.assertEqual(state['optimizer']['param_groups'][0]['lr'],.005);self.assertEqual(state['optimizer']['param_groups'][1]['weight_decay'],0)
            self.assertTrue(all(s['step'].item()==260 for s in state['optimizer']['state'].values()))
            for name,digest in json.loads((Path(temp)/'checksums.json').read_text()).items():self.assertEqual(hashlib.sha256((Path(temp)/name).read_bytes()).hexdigest(),digest)
            with torch.random.fork_rng(devices=[]):
                model,opt,sched,gen=api['restore'](module,state,prepared);tail=api['advance'](model,opt,sched,gen,X,y,V,vy,20,40)
                self.assertEqual(tail,asset['continuous_history'][21:])
                warm,wo,ws,wg=api['restore'](module,state,prepared,weights_only=True);wt=api['advance'](warm,wo,ws,wg,X,y,V,vy,20,40)
                self.assertEqual(wt,asset['weights_only_history'][21:]);self.assertNotEqual(wt,tail)
                difference=max((v-warm.state_dict()[k]).abs().max().item() for k,v in model.state_dict().items());self.assertEqual(difference,report['weights_only_parameter_max_abs'])
            self.assertFalse((Path(temp)/'epoch-20.pt.tmp').exists())

    def test_corrupt_checkpoint_contract_rejects_schema_split_and_recipe(self):
        module,prepared,X,y,V,vy=api['source'](DATA/'winequality-red.csv')
        with torch.random.fork_rng(devices=[]):
            torch.manual_seed(17);m,o,s,g=api['setup'](module);state=api['checkpoint'](m,o,s,g,20,prepared,[])
        api['validate_checkpoint'](state,prepared)
        for key,value in [('format',999),('epoch',21),('feature_names',['wrong']),('source_sha256','bad'),('mean',[0]*11),('train_source_rows',[])]:
            bad=copy.deepcopy(state);bad[key]=value
            with self.assertRaises(ValueError):api['validate_checkpoint'](bad,prepared)
        bad=copy.deepcopy(state);bad['config']['seed']=99
        with self.assertRaises(ValueError):api['validate_checkpoint'](bad,prepared)

    def test_import_safe_external_cli_source_immutability_rng_and_thread_restore(self):
        script=DATA/'reliable_workflow.py';before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()};output=io.StringIO()
        with contextlib.redirect_stdout(output):imported=runpy.run_path(str(script))
        self.assertEqual(output.getvalue(),'');rng=torch.get_rng_state().clone();torch.set_num_threads(2)
        try:own,own_asset=imported['run_analysis'](DATA/'winequality-red.csv');self.assertEqual(torch.get_num_threads(),2)
        finally:torch.set_num_threads(1)
        torch.testing.assert_close(rng,torch.get_rng_state());self.assertEqual(own,report);self.assertEqual(own_asset,asset)
        with tempfile.TemporaryDirectory() as temp:
            out=Path(temp)/'report.json';r=subprocess.run([sys.executable,str(script),'--output',str(out),'--artifact-dir',str(Path(temp)/'artifacts')],cwd=temp,capture_output=True,text=True,check=True,timeout=90)
            self.assertEqual(json.loads(r.stdout),report);self.assertEqual(json.loads(out.read_text()),report);self.assertTrue((Path(temp)/'artifacts/epoch-20.pt').is_file())
        self.assertEqual(before,{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()})

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(ReliableBehaviorTests))
    if not result.wasSuccessful():raise SystemExit(1)
    (ROOT/'build/chapter-17-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':len(solutions),'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, {len(solutions)} solutions, {result.testsRun} behavior tests; actual recovery and state contracts verified.')
