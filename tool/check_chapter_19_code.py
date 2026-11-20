"""Execute Chapter19 and audit causal sequences, PyTorch gates and packed lengths."""
import contextlib,hashlib,io,json,math,os,runpy,subprocess,sys,tempfile,types,unittest
from pathlib import Path
import numpy as np
import pandas as pd
import torch
from torch import nn
from torch.nn.utils.rnn import pack_padded_sequence,pad_sequence
ROOT=Path(__file__).resolve().parent.parent;os.chdir(ROOT);torch.set_num_threads(1)
chapter=json.loads((ROOT/'assets/content/chapter_19.json').read_text(encoding='utf-8'))
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
api=scopes['ch19_experiment'];report,asset=api['report'],api['asset'];DATA=ROOT/'assets/datasets/bike_sharing'
def rebuild(entry):
    cell={'rnn':nn.RNN,'gru':nn.GRU,'lstm':nn.LSTM}[entry['kind']](1,3,batch_first=True,dtype=torch.float64)
    with torch.no_grad():
        for attr,key in [('weight_ih_l0','w_ih'),('weight_hh_l0','w_hh'),('bias_ih_l0','b_ih'),('bias_hh_l0','b_hh')]:getattr(cell,attr).copy_(torch.tensor(entry['parameters'][key],dtype=torch.float64))
    return cell
def fitted():
    m=api['SequenceGRU']();entry=asset['cells'][2];m.recurrent=rebuild(entry)
    with torch.no_grad():m.head.weight.copy_(torch.tensor([entry['parameters']['head_weight']],dtype=torch.float64));m.head.bias.fill_(entry['parameters']['head_bias'])
    return m
class SequenceBehaviorTests(unittest.TestCase):
    def test_original_source_calendar_roles_and_train_only_scaling(self):
        self.assertEqual(hashlib.sha256((DATA/'day.csv').read_bytes()).hexdigest(),report['sha256'])
        dates,y,mean,scale=api['prepare'](DATA/'day.csv');original=pd.read_csv(DATA/'day.csv')
        self.assertEqual(len(original),731);self.assertEqual(len(y),547);self.assertEqual(dates[-1],'2012-06-30')
        self.assertEqual(mean,original.cnt.iloc[:365].mean());self.assertEqual(scale,original.cnt.iloc[:365].std(ddof=0))
        self.assertEqual(report['reserved_outcomes_used'],0)
        for q in asset['queries']:
            t=q['target_index'];self.assertEqual(q['history_dates'],dates[t-14:t]);np.testing.assert_array_equal(q['counts'],y[t-14:t]);np.testing.assert_array_equal(q['future_counts'],y[t:t+7]);self.assertLessEqual(t+7,547)
    def test_causal_windows_prefix_invariance_and_invalid_contracts(self):
        _,y,mean,scale=api['prepare'](DATA/'day.csv');X,z,ids=api['windows'](y,mean,scale,14,365)
        self.assertEqual(X.shape,(351,14,1));self.assertEqual(z.shape,(351,));np.testing.assert_array_equal(ids,np.arange(14,365))
        for k,t in enumerate(ids):np.testing.assert_allclose(X[k,:,0],(y[t-14:t]-mean)/scale)
        changed=y.copy();changed[400:]=999999
        A,_,_=api['windows'](y,mean,scale,400,401);B,_,_=api['windows'](changed,mean,scale,400,401);torch.testing.assert_close(A,B)
        for args in [(y,mean,0,14,365),(y,mean,scale,13,365),(y,mean,scale,365,365),(y,mean,scale,14,548),(np.array([np.nan]*547),mean,scale,14,365)]:
            with self.assertRaises(ValueError):api['windows'](*args)
    def test_all_cells_hidden_cell_states_gates_and_gru_bias_placement(self):
        for entry in asset['cells']:
            cell=rebuild(entry)
            for q in asset['queries']:
                seq=torch.tensor(q['standardized'],dtype=torch.float64).reshape(1,14,1);trace=api['manual'](q['standardized'],entry['parameters'],entry['kind'])
                with torch.no_grad():output,last=cell(seq)
                np.testing.assert_allclose([r['hidden'] for r in trace],output[0],rtol=1e-12,atol=1e-12)
                if entry['kind']=='lstm':np.testing.assert_allclose(trace[-1]['cell'],last[1][0,0],rtol=1e-12,atol=1e-12)
                # Independent framework cell, advancing one timestep at a time.
                step={'rnn':nn.RNNCell,'gru':nn.GRUCell,'lstm':nn.LSTMCell}[entry['kind']](1,3,dtype=torch.float64)
                with torch.no_grad():
                    for attr in ['weight_ih','weight_hh','bias_ih','bias_hh']:getattr(step,attr).copy_(getattr(cell,attr+'_l0'))
                    h=torch.zeros(1,3,dtype=torch.float64);c=h.clone()
                    for t in range(14):
                        if entry['kind']=='lstm':h,c=step(seq[:,t],(h,c));np.testing.assert_allclose(trace[t]['cell'],c[0],atol=1e-12)
                        else:h=step(seq[:,t],h)
                        np.testing.assert_allclose(trace[t]['hidden'],h[0],atol=1e-12)
        p={'w_ih':np.zeros((9,1)).tolist(),'w_hh':np.zeros((9,3)).tolist(),'b_ih':[0.]*9,'b_hh':[0.]*6+[2.]*3}
        h=api['manual']([0.],p,'gru')[0]['hidden'];np.testing.assert_allclose(h,[.5*np.tanh(1)]*3);self.assertGreater(abs(h[0]-.5*np.tanh(2)),.05)
    def test_shared_bptt_gradient_parameter_budget_and_batch_one(self):
        m=fitted();self.assertEqual(sum(p.numel() for p in m.parameters()),58)
        X=torch.tensor(asset['queries'][0]['standardized'],dtype=torch.float64).reshape(1,14,1);self.assertEqual(m(X).shape,(1,))
        loss=m(X).square().sum();loss.backward();parameter=m.recurrent.weight_hh_l0;analytic=parameter.grad[7,1].item();old=parameter[7,1].item();eps=1e-6
        with torch.no_grad():
            parameter[7,1]=old+eps;hi=m(X).square().sum().item();parameter[7,1]=old-eps;lo=m(X).square().sum().item();parameter[7,1]=old
        self.assertAlmostEqual(analytic,(hi-lo)/(2*eps),places=7)
        with self.assertRaises(ValueError):m(torch.zeros(1,13,1,dtype=torch.float64))
    def test_packing_unsorted_lengths_valid_index_and_loss_mask_distinction(self):
        cell=rebuild(asset['cells'][2]);lengths=torch.tensor([5,14,9]);seq=[torch.tensor(q['standardized'][:n],dtype=torch.float64)[:,None] for q,n in zip(asset['queries'],lengths.tolist())];padded=pad_sequence(seq,batch_first=True)
        with torch.no_grad():_,h=cell(pack_padded_sequence(padded,lengths,batch_first=True,enforce_sorted=False));out,dense=cell(padded)
        for i,s in enumerate(seq):
            with torch.no_grad():_,single=cell(s[None])
            torch.testing.assert_close(h[:,i],single[:,0]);torch.testing.assert_close(h[0,i],out[i,lengths[i]-1])
            if lengths[i]<14:self.assertGreater((h[0,i]-dense[0,i]).abs().max().item(),1e-5)
        # Multiplying a loss by a padding mask cannot change an already computed hidden state.
        before=dense.clone();mask=torch.arange(14)[None]<lengths[:,None];masked=(out.square().sum(-1)*mask).sum()/mask.sum();self.assertTrue(torch.isfinite(masked));torch.testing.assert_close(before,dense)
        with self.assertRaises(ValueError):api['manual']([1],asset['cells'][2]['parameters'],'gru',0)
    def test_forecast_recursion_and_protocol_metrics_are_independently_recomputed(self):
        model=fitted();_,y,mean,scale=api['prepare'](DATA/'day.csv')
        for q in asset['queries']:
            history=list(q['counts']);got=[]
            with torch.no_grad():
                for _ in range(7):
                    prediction=model(torch.tensor((np.array(history[-14:])-mean)/scale,dtype=torch.float64).reshape(1,14,1)).item()*scale+mean;got.append(prediction);history.append(prediction)
            np.testing.assert_allclose(got,q['recursive_gru'],atol=1e-10);np.testing.assert_allclose(api['recursive'](model,q['counts'],mean,scale,7),got)
            np.testing.assert_array_equal(q['seasonal7_fixed_origin'],y[q['target_index']-7:q['target_index']])
        X,_,ids=api['windows'](y,mean,scale,365,547)
        with torch.no_grad():pred=model(X).numpy()*scale+mean
        for name,p in [('gru',pred),('naive',y[ids-1]),('seasonal7',y[ids-7])]:
            self.assertAlmostEqual(np.abs(p-y[ids]).mean(),report['rolling_one_step'][name]['mae'],places=9);self.assertAlmostEqual(np.sqrt(np.mean((p-y[ids])**2)),report['rolling_one_step'][name]['rmse'],places=9)
        self.assertGreater(report['rolling_one_step']['gru']['mae'],report['rolling_one_step']['naive']['mae'])
    def test_reproducible_recipe_artifacts_hashes_and_honest_training_improvement(self):
        self.assertEqual(asset,json.loads((DATA/'sequence_lab.json').read_text()));self.assertEqual(len(asset['train_history']),81);self.assertLess(report['final_train_mse_scaled'],report['initial_train_mse_scaled'])
        with tempfile.TemporaryDirectory() as temp:
            own,own_asset=api['run_analysis'](DATA/'day.csv',Path(temp));self.assertEqual(own,report);self.assertEqual(own_asset,asset)
            for name,digest in json.loads((Path(temp)/'checksums.json').read_text()).items():self.assertEqual(hashlib.sha256((Path(temp)/name).read_bytes()).hexdigest(),digest)
            m=api['SequenceGRU']();m.load_state_dict(torch.load(Path(temp)/'gru.pt',weights_only=True,map_location='cpu'));self.assertEqual(api['parameters'](m.recurrent,m.head),asset['cells'][2]['parameters']);self.assertEqual(json.loads((Path(temp)/'schema.json').read_text())['input'],['B',14,1])
    def test_import_safe_external_cli_rng_threads_and_unchanged_assets(self):
        script=DATA/'sequence_workflow.py';before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()};out=io.StringIO()
        with contextlib.redirect_stdout(out):module=runpy.run_path(str(script))
        self.assertEqual(out.getvalue(),'');rng=torch.get_rng_state().clone();torch.set_num_threads(2)
        try:own,own_asset=module['run_analysis'](DATA/'day.csv');self.assertEqual(torch.get_num_threads(),2)
        finally:torch.set_num_threads(1)
        torch.testing.assert_close(rng,torch.get_rng_state());self.assertEqual(own,report);self.assertEqual(own_asset,asset)
        with tempfile.TemporaryDirectory() as temp:
            dest=Path(temp)/'report.json';r=subprocess.run([sys.executable,str(script),'--output',str(dest)],cwd=temp,capture_output=True,text=True,check=True,timeout=90)
            self.assertEqual(json.loads(r.stdout),report);self.assertEqual(json.loads(dest.read_text()),report);self.assertFalse(dest.with_name(dest.name+'.tmp').exists())
        self.assertEqual(before,{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()})
if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2,stream=sys.stdout).run(unittest.defaultTestLoader.loadTestsFromTestCase(SequenceBehaviorTests))
    if not result.wasSuccessful():raise SystemExit(1)
    (ROOT/'build/chapter-19-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':len(solutions),'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, {len(solutions)} solutions, {result.testsRun} behavior tests; recurrent states, packing and causal forecasts verified.')
