"""Execute the offline tensor chapter and verify numerical/graph/storage contracts."""
import contextlib, hashlib, io, json, math, os, runpy, subprocess, sys, tempfile, types, unittest
from pathlib import Path
import numpy as np
import torch
import torch.nn.functional as F

ROOT=Path(__file__).resolve().parent.parent
os.chdir(ROOT)
chapter=json.loads((ROOT/'assets/content/chapter_15.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons','quizzes','exercises','interviews']]==[20,24,10,10]
scopes={};snippets=0
torch.set_num_threads(1)
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
api=scopes['ch15_experiment'];report=api['report'];asset=api['asset']
DATA=ROOT/'assets/datasets/wine_quality'

class TensorBehaviorTests(unittest.TestCase):
    def test_exact_shape_finite_binary_dtype_contract_and_no_mutation(self):
        X=torch.tensor([[1.,2.],[3.,4.]],dtype=torch.float64);y=torch.tensor([0.,1.],dtype=torch.float64)
        w=torch.zeros(2,dtype=torch.float64,requires_grad=True);b=torch.zeros((),dtype=torch.float64,requires_grad=True)
        originals=[t.clone() for t in [X,y,w,b]]
        self.assertEqual(api['objective'](X,y,w,b).ndim,0)
        for args in [(X,y[:,None],w,b),(X,y,w,b[None]),(X,y.float(),w,b),(X,torch.tensor([0.,2.],dtype=torch.float64),w,b),(X[:0],y[:0],w,b),(X*float('nan'),y,w,b)]:
            with self.assertRaises(ValueError):api['objective'](*args)
        for eps in [0,-1,float('nan')]:
            with self.assertRaises(ValueError):api['finite_gradient'](X,y,w,b,eps)
        api['finite_gradient'](X,y,w,b)
        for a,c in zip([X,y,w,b],originals):torch.testing.assert_close(a,c)

    def test_real_fit_autograd_analytic_finite_difference_and_gradcheck(self):
        _,_,y,_,fit,_,Z=api['load_fit'](DATA/'winequality-red.csv')
        X=torch.tensor(Z,dtype=torch.float64);target=torch.tensor(y[fit],dtype=torch.float64)
        w=torch.zeros(11,dtype=torch.float64,requires_grad=True);b=torch.zeros((),dtype=torch.float64,requires_grad=True)
        g=torch.autograd.grad(api['objective'](X,target,w,b),(w,b))
        for own in [api['analytic_gradient'](X,target,w,b),api['finite_gradient'](X,target,w,b)]:
            for left,right in zip(g,own):torch.testing.assert_close(left,right,atol=1e-8,rtol=1e-8)
        self.assertIsNone(w.grad);self.assertTrue(report['gradcheck_passed'])
        self.assertAlmostEqual(report['zero_parameter_mean_bce'],math.log(2),places=14)
        self.assertLess(report['one_manual_step_mean_bce'],report['zero_parameter_mean_bce'])
        for ref in asset['gradient_references']:
            xx=X[:16][:,[10,1]];p=torch.tensor(ref['parameters'],dtype=torch.float64,requires_grad=True)
            loss=F.binary_cross_entropy_with_logits(xx@p[:2]+p[2],target[:16]);grad=torch.autograd.grad(loss,p)[0]
            self.assertAlmostEqual(float(loss.detach()),ref['loss'],places=14);np.testing.assert_allclose(grad,ref['gradient'],atol=1e-14)

    def test_view_strides_aliasing_copy_and_storage_indices(self):
        base=torch.tensor(asset['layout_storage'],dtype=torch.float64).reshape(4,3)
        views={'original':base,'transpose':base.T,'slice':base[:,::2],'expand':base[:,:1].expand(4,3)}
        for ref in asset['layouts']:
            view=views[ref['name']];self.assertEqual(list(view.shape),ref['shape']);self.assertEqual(list(view.stride()),ref['stride'])
            self.assertEqual(view.is_contiguous(),ref['contiguous']);self.assertEqual(view.tolist(),ref['values'])
            self.assertEqual([[view.storage_offset()+i*view.stride(0)+j*view.stride(1) for j in range(view.shape[1])] for i in range(view.shape[0])],ref['storage_indices'])
            copy=view.contiguous();self.assertEqual(copy.tolist(),view.tolist());self.assertEqual(copy.untyped_storage().data_ptr()==view.untyped_storage().data_ptr(),ref['contiguous_shares_storage'])
        self.assertIs(base.contiguous(),base)
        with self.assertRaises(RuntimeError):base.T.view(-1)
        torch.testing.assert_close(base.T.reshape(-1),base.T.contiguous().view(-1))
        self.assertEqual(views['expand'].stride(1),0)
        self.assertEqual(len(set(sum(asset['layouts'][3]['storage_indices'],[]))),4)

    def test_broadcast_association_singleton_trap_and_bce_rejection(self):
        Z=torch.tensor([s['standardized'] for s in asset['samples']],dtype=torch.float64)
        p=torch.sigmoid(Z[:4]@torch.tensor(asset['reference_weights'],dtype=torch.float64)+asset['reference_bias'])
        y=torch.tensor([s['positive'] for s in asset['samples'][:4]],dtype=torch.float64)
        for ref in asset['broadcast_references']:
            B=ref['batch'];actual=api['mse_shape_audit'](p[:B],y[:B])
            for k,v in actual.items():self.assertEqual(v,ref[k])
            with self.assertRaises(ValueError):F.binary_cross_entropy_with_logits(torch.logit(p[:B]),y[:B,None])
        one=asset['broadcast_references'][0];self.assertEqual(one['correct_mse'],one['wrong_mse']);self.assertNotEqual(one['correct_shape'],one['wrong_shape'])
        self.assertNotEqual(asset['broadcast_references'][-1]['correct_mse'],asset['broadcast_references'][-1]['wrong_mse'])

    def test_graph_accumulation_lifecycle_vjp_and_higher_derivative(self):
        x=torch.tensor(3.,dtype=torch.float64,requires_grad=True)
        for _ in range(2):(x.square()+2*x).backward()
        self.assertEqual(x.grad.item(),16);x.grad=None;(x.square()+2*x).backward();self.assertEqual(x.grad.item(),8)
        old=x.square();old.backward()
        with self.assertRaises(RuntimeError):old.backward()
        g=torch.autograd.grad(x.pow(3),x,create_graph=True)[0];self.assertEqual(torch.autograd.grad(g,x)[0].item(),18)
        u=torch.tensor([1.,2.],requires_grad=True);torch.testing.assert_close(torch.autograd.grad(u.square(),u,torch.tensor([3.,4.]))[0],torch.tensor([6.,16.]))
        a=torch.tensor(2.,requires_grad=True);nonleaf=a*3;nonleaf.retain_grad();nonleaf.square().backward();self.assertEqual(nonleaf.grad.item(),12);self.assertEqual(a.grad.item(),36)

    def test_detach_numpy_sharing_modes_and_integer_grad(self):
        source=np.array([1.,2.]);shared=torch.from_numpy(source);copied=torch.tensor(source);source[0]=9
        self.assertEqual(shared[0].item(),9);self.assertEqual(copied[0].item(),1)
        x=torch.tensor([2.],requires_grad=True);alias=x.detach();independent=x.detach().clone().requires_grad_()
        self.assertEqual(alias.untyped_storage().data_ptr(),x.untyped_storage().data_ptr());self.assertNotEqual(independent.untyped_storage().data_ptr(),x.untyped_storage().data_ptr())
        with torch.no_grad():out=x*3
        self.assertFalse(out.requires_grad);self.assertTrue(x.requires_grad)
        with torch.inference_mode():inferred=x*3
        self.assertTrue(torch.is_inference(inferred))
        with self.assertRaises(RuntimeError):inferred.requires_grad_()
        model=torch.nn.Linear(1,1);model.eval();self.assertTrue(model(x[:,None]).requires_grad)
        with self.assertRaises(RuntimeError):torch.tensor([1,2],requires_grad=True)

    def test_source_fit_only_asset_reproduction_and_loader_identity(self):
        frame,raw,y,groups,fit,reference,Z=api['load_fit'](DATA/'winequality-red.csv')
        self.assertEqual(len(fit),966);self.assertEqual(len(set(groups[fit])),815)
        self.assertEqual(asset,json.loads((DATA/'tensor_lab.json').read_text()))
        for j,s in enumerate(asset['samples']):
            i=s['source_row_1based']-1;self.assertEqual(i,fit[j]);self.assertEqual(s['quality'],int(frame.quality.iloc[i]));self.assertEqual(s['positive'],int(y[i]));np.testing.assert_array_equal(s['raw'],raw[i]);np.testing.assert_array_equal(s['standardized'],Z[j])
        self.assertFalse(any(k in report for k in ['test_ap','test_accuracy','decision_metrics','locked_final_test']))
        self.assertEqual(report['loader_batch_shape'],[16,11]);self.assertEqual(report['loader_target_shape'],[16])
        ds=torch.utils.data.TensorDataset(torch.tensor(fit))
        own=next(iter(torch.utils.data.DataLoader(ds,batch_size=16,shuffle=True,generator=torch.Generator().manual_seed(42),num_workers=0)))[0]+1
        self.assertEqual(own.tolist(),report['first_shuffled_loader_source_rows_1based'])

    def test_import_safe_external_cli_reports_unchanged_source_threads_restored(self):
        script=DATA/'torch_workflow.py';before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()}
        out=io.StringIO()
        with contextlib.redirect_stdout(out):imported=runpy.run_path(str(script))
        self.assertEqual(out.getvalue(),'');torch.set_num_threads(2)
        try:
            own,own_asset=imported['run_analysis'](DATA/'winequality-red.csv');self.assertEqual(torch.get_num_threads(),2)
        finally:torch.set_num_threads(1)
        self.assertEqual(own,report);self.assertEqual(own_asset,asset)
        with tempfile.TemporaryDirectory() as temp:
            destination=Path(temp)/'report.json';result=subprocess.run([sys.executable,str(script),'--output',str(destination)],cwd=temp,capture_output=True,text=True,check=True,timeout=60)
            self.assertEqual(json.loads(result.stdout),report);self.assertEqual(json.loads(destination.read_text()),report);self.assertFalse(destination.with_name('report.json.tmp').exists())
        self.assertEqual(before,{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()})

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(TensorBehaviorTests))
    if not result.wasSuccessful():raise SystemExit(1)
    (ROOT/'build/chapter-15-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':len(solutions),'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, {len(solutions)} solutions, {result.testsRun} behavior tests; real-source assets and CPU autograd agree.')
