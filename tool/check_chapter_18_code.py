"""Execute Chapter18 and independently check real-image CNN/transfer contracts."""
import contextlib,hashlib,io,json,math,os,runpy,subprocess,sys,tempfile,types,unittest
from pathlib import Path
import numpy as np
import torch
from torch import nn
import torch.nn.functional as F
ROOT=Path(__file__).resolve().parent.parent;os.chdir(ROOT);torch.set_num_threads(1)
chapter=json.loads((ROOT/'assets/content/chapter_18.json').read_text(encoding='utf-8'))
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
api=scopes['ch18_experiment'];report,asset=api['report'],api['asset'];DATA=ROOT/'assets/datasets/digits'

def rebuild(weights):
    model=api['DigitCNN']()
    with torch.no_grad():
        for name,value in [('backbone.0.weight',weights['conv1_weight']),('backbone.0.bias',weights['conv1_bias']),('backbone.3.weight',weights['conv2_weight']),('backbone.3.bias',weights['conv2_bias']),('head.weight',weights['head_weight']),('head.bias',weights['head_bias'])]:
            dict(model.named_parameters())[name].copy_(torch.tensor(value,dtype=torch.float64))
    return model

class VisionBehaviorTests(unittest.TestCase):
    def test_source_original_packaged_bytes_groups_roles_and_no_writer_claim(self):
        raw,y,groups,roles=api['load_source'](DATA/'digits.csv.gz')
        self.assertEqual(raw.shape,(1797,8,8));self.assertEqual(len(np.unique(groups)),1797)
        self.assertEqual({k:len(v) for k,v in roles.items()},report['roles'])
        for left in roles:
            for right in roles:
                if left!=right:self.assertTrue(set(groups[roles[left]]).isdisjoint(groups[roles[right]]))
        for key,ids in roles.items():self.assertTrue(np.all(y[ids]<5) if key.startswith('source') else np.all(y[ids]>=5))
        for s in asset['samples']:
            i=s['source_row_1based']-1;self.assertIn(i,roles['target_train']);self.assertNotIn(i,roles['target_validation']);self.assertEqual(s['digit'],int(y[i]));np.testing.assert_array_equal(s['pixels'],raw[i])
        manifest=json.loads((DATA/'source_manifest.json').read_text())
        for name,digest in manifest['sha256'].items():self.assertEqual(hashlib.sha256((DATA/name).read_bytes()).hexdigest(),digest)
        with tempfile.TemporaryDirectory() as temp:
            bad=Path(temp)/'digits.csv.gz';bad.write_bytes(b'bad')
            with self.assertRaises(ValueError):api['load_source'](bad)

    def test_all_cross_correlations_against_independent_explicit_windows(self):
        for ref in asset['convolution_references']:
            raw=next(s['pixels'] for s in asset['samples'] if s['source_row_1based']==ref['source_row_1based']);X=np.array(raw)/16;K=np.array(asset['kernels'][ref['kernel']]);s,p=ref['stride'],ref['padding'];padded=np.pad(X,p);h=(8+2*p-3)//s+1
            expected=np.array([[np.sum(padded[i*s:i*s+3,j*s:j*s+3]*K) for j in range(h)] for i in range(h)])
            np.testing.assert_allclose(ref['output'],expected,atol=1e-14)
        self.assertEqual(len(asset['convolution_references']),18)

    def test_pooling_and_zero_fill_shift_references_not_roll(self):
        for ref in asset['pool_references']:
            raw=np.array(next(s['pixels'] for s in asset['samples'] if s['source_row_1based']==ref['source_row_1based']))/16
            X=raw.copy()
            if ref['shift_right']:X[:,1:]=raw[:,:-1];X[:,0]=0
            np.testing.assert_array_equal(ref['input'],X)
            expected=[[float(X[2*i:2*i+2,2*j:2*j+2].max() if ref['mode']=='max' else X[2*i:2*i+2,2*j:2*j+2].mean()) for j in range(4)] for i in range(4)]
            np.testing.assert_array_equal(expected,ref['output'])
        self.assertEqual(len(asset['pool_references']),12)

    def test_all_exported_weights_roundtrip_features_logits_probabilities(self):
        X=torch.tensor([s['pixels'] for s in asset['samples']],dtype=torch.float64)[:,None]/16
        for b in asset['branches']:
            m=rebuild(b['weights']);m.eval()
            with torch.no_grad():logits=m(X);features=m.backbone(X)
            np.testing.assert_allclose(logits,b['logits'],atol=1e-12);np.testing.assert_allclose(logits.softmax(-1),b['probabilities'],atol=1e-12);np.testing.assert_allclose(features,b['features'],atol=1e-12)
            torch.testing.assert_close(m(X[:1]),m(X)[:1]);self.assertEqual(m(X[:1]).shape,(1,5))
            self.assertEqual(sum(p.numel() for p in m.parameters()),501)
            with self.assertRaises(ValueError):m(torch.zeros(1,8,8,dtype=torch.float64))

    def test_frozen_values_gradients_and_finetune_changes(self):
        branches={b['name']:b for b in asset['branches']}
        for name in ['conv1_weight','conv1_bias','conv2_weight','conv2_bias']:
            np.testing.assert_array_equal(branches['initial']['weights'][name],branches['frozen']['weights'][name])
        self.assertFalse(np.array_equal(branches['initial']['weights']['head_weight'],branches['frozen']['weights']['head_weight']))
        self.assertGreater(report['finetune_backbone_max_abs'],0)
        raw,y,_,roles=api['load_source'](DATA/'digits.csv.gz');ids=roles['target_train'][:8];X=api['tensor_images'](raw[ids]);Y=torch.tensor(y[ids]-5)
        m=rebuild(branches['initial']['weights']);before={k:v.clone() for k,v in m.backbone.state_dict().items()};api['train'](m,X,Y,X,Y,1,'frozen')
        self.assertEqual(sum(p.numel() for p in m.parameters() if p.requires_grad),165)
        for k,v in before.items():torch.testing.assert_close(v,m.backbone.state_dict()[k],atol=0,rtol=0)
        self.assertTrue(all(p.grad is None for p in m.backbone.parameters()));self.assertIsNotNone(m.head.weight.grad)

    def test_convolution_gradient_shape_parameter_counts_and_invalid_class_mapping(self):
        X=torch.arange(1,10,dtype=torch.float64).reshape(1,1,3,3);W=torch.tensor([[[[.1,.2],[.3,.4]]]],dtype=torch.float64,requires_grad=True)
        loss=F.conv2d(X,W).square().mean();g=torch.autograd.grad(loss,W)[0];eps=1e-6;plus=W.detach().clone();minus=plus.clone();plus[0,0,0,0]+=eps;minus[0,0,0,0]-=eps
        numeric=(F.conv2d(X,plus).square().mean()-F.conv2d(X,minus).square().mean())/(2*eps);self.assertAlmostEqual(g[0,0,0,0].item(),numeric.item(),places=7)
        model=api['DigitCNN']();self.assertEqual(sum(p.numel() for p in model.backbone.parameters()),336);self.assertEqual(sum(p.numel() for p in model.head.parameters()),165)
        with self.assertRaises((IndexError,RuntimeError)):F.cross_entropy(torch.zeros(1,5),torch.tensor([9]))
        raw=np.zeros((1,8,8),dtype=np.uint8);raw[0,0,0]=16;self.assertEqual(api['tensor_images'](raw)[0,0,0,0].item(),1)

    def test_validation_confusion_fixed_endpoints_artifacts_and_no_universal_ranking(self):
        for key,count in [('source_validation',180),('frozen_validation',179),('finetune_validation',179)]:
            r=report[key];C=np.array(r['confusion']);self.assertEqual(C.shape,(5,5));self.assertEqual(C.sum(),count);self.assertEqual(C.trace()/C.sum(),r['accuracy'])
        self.assertEqual(asset,json.loads((DATA/'vision_lab.json').read_text()));self.assertEqual(len(asset['source_history']),31);self.assertEqual(len(asset['frozen_history']),21);self.assertEqual(len(asset['finetune_history']),21)
        with tempfile.TemporaryDirectory() as temp:
            own,own_asset=api['run_analysis'](DATA/'digits.csv.gz',Path(temp));self.assertEqual(own,report);self.assertEqual(own_asset,asset)
            for name,digest in json.loads((Path(temp)/'checksums.json').read_text()).items():self.assertEqual(hashlib.sha256((Path(temp)/name).read_bytes()).hexdigest(),digest)
            m=api['DigitCNN']();m.load_state_dict(torch.load(Path(temp)/'frozen.pt',weights_only=True,map_location='cpu'));self.assertEqual(api['weights'](m),asset['branches'][1]['weights'])

    def test_import_safe_external_cli_rng_thread_restore_and_source_immutability(self):
        script=DATA/'vision_workflow.py';before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()};out=io.StringIO()
        with contextlib.redirect_stdout(out):module=runpy.run_path(str(script))
        self.assertEqual(out.getvalue(),'');rng=torch.get_rng_state().clone();torch.set_num_threads(2)
        try:own,own_asset=module['run_analysis'](DATA/'digits.csv.gz');self.assertEqual(torch.get_num_threads(),2)
        finally:torch.set_num_threads(1)
        torch.testing.assert_close(rng,torch.get_rng_state());self.assertEqual(own,report);self.assertEqual(own_asset,asset)
        with tempfile.TemporaryDirectory() as temp:
            dest=Path(temp)/'report.json';r=subprocess.run([sys.executable,str(script),'--output',str(dest)],cwd=temp,capture_output=True,text=True,check=True,timeout=90)
            self.assertEqual(json.loads(r.stdout),report);self.assertEqual(json.loads(dest.read_text()),report);self.assertFalse(dest.with_name(dest.name+'.tmp').exists())
        self.assertEqual(before,{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()})

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(VisionBehaviorTests))
    if not result.wasSuccessful():raise SystemExit(1)
    (ROOT/'build/chapter-18-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':len(solutions),'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, {len(solutions)} solutions, {result.testsRun} behavior tests; actual images, CNN and local transfer verified.')
