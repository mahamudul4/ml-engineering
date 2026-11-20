from pathlib import Path
import json,hashlib,importlib.util,contextlib,io,sys,tempfile,subprocess,copy,unittest
import numpy as np
import torch
from torch import nn
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/scifact_rag'
s=importlib.util.spec_from_file_location('adaptation_qa',DATA/'adaptation_workflow.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
chapter=json.loads((ROOT/'assets/content/chapter_25.json').read_text(encoding='utf-8'));lab=json.loads((DATA/'adaptation_lab.json').read_text());lm=m.lm_module();torch.set_num_threads(1)
class QA(unittest.TestCase):
 def test_01_actual_source_roles_prefixes_and_class_counts(self):
  rows=m.load_rows();self.assertEqual([len(rows['train']),len(rows['diagnostic'])],[505,188]);self.assertEqual(rows['excluded_train_ids'],[])
  self.assertFalse({r['text'] for r in rows['train']}&{r['text'] for r in rows['diagnostic']})
  for sample in lab['samples']:self.assertEqual(m.prefix(sample['text']),sample['ids'])
  self.assertEqual(m.digest(DATA.parent/'alice/llm_lab.json'),lab['report']['base_asset_sha256'])
 def test_02_every_complete_actual_forward_independent_numpy(self):
  # Reuse the independent NumPy architecture already validated for Chapter22.
  spec=importlib.util.spec_from_file_location('llm_qa_helpers',ROOT/'tool/check_chapter_22_code.py');helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
  for name,weights in lab['weights'].items():
   model=lm.ByteDecoder();model.load_state_dict({k:torch.tensor(v,dtype=torch.float64) for k,v in weights.items()})
   for sample in lab['samples']:
    with torch.no_grad():trace=model.inspect(torch.tensor([sample['ids']]))
    expected=sample['references'][name]
    np.testing.assert_allclose(trace['logits'][0,-1],expected['logits'],atol=1e-11)
    np.testing.assert_allclose(trace['normalized'][0,-1],expected['normalized'],atol=1e-12)
    # Independently reconstruct the complete output head from normalized hidden state.
    logits=np.asarray(expected['normalized'])@np.asarray(weights['head.weight']).T+np.asarray(weights['head.bias'])
    np.testing.assert_allclose(logits,expected['logits'],atol=1e-12)
 def test_03_freeze_init_nonzero_gradient_finite_difference(self):
  with torch.random.fork_rng(devices=[]):
   torch.manual_seed(25);head=nn.Linear(8,259,dtype=torch.float64);adapter=m.LoRAHead(head)
   before={k:v.detach().clone() for k,v in head.state_dict().items()};x=torch.arange(8,dtype=torch.float64).reshape(1,8)/8
   torch.testing.assert_close(adapter(x),head(x))
   objective=adapter(x).square().mean();objective.backward();self.assertEqual(adapter.A.grad.abs().sum().item(),0);self.assertGreater(adapter.B.grad.abs().sum().item(),0)
   index=np.unravel_index(adapter.B.grad.abs().argmax().item(),adapter.B.shape);analytic=adapter.B.grad[index].item();eps=1e-6
   with torch.no_grad():
    adapter.B[index]+=eps;plus=adapter(x).square().mean().item();adapter.B[index]-=2*eps;minus=adapter(x).square().mean().item();adapter.B[index]+=eps
   self.assertAlmostEqual((plus-minus)/(2*eps),analytic,places=8)
   optimizer=torch.optim.AdamW([adapter.A,adapter.B],lr=.01,weight_decay=0.);optimizer.step()
   for k,v in head.state_dict().items():torch.testing.assert_close(v,before[k],rtol=0,atol=0)
   self.assertTrue(all(p.grad is None for p in head.parameters()))
 def test_04_response_only_gradients_loss_classes_and_invalid_inputs(self):
  logits=torch.zeros(2,4,259,dtype=torch.float64,requires_grad=True);pos=torch.tensor([1,3]);target=torch.tensor([83,67]);loss=m.response_loss(logits,pos,target);loss.backward()
  self.assertAlmostEqual(loss.item(),np.log(257));self.assertEqual(logits.grad[0,0].abs().sum().item(),0);self.assertGreater(logits.grad[0,1].abs().sum().item(),0)
  self.assertEqual(logits.grad[:,:,256:258].abs().sum().item(),0)
  with self.assertRaises(ValueError):m.response_loss(torch.zeros(1,2,258),torch.tensor([1]),torch.tensor([83]))
  with self.assertRaises(ValueError):m.response_loss(torch.zeros(1,2,259),torch.tensor([1]),torch.tensor([0]))
  with self.assertRaises(ValueError):m.quantize([[float('nan')]])
 def test_05_merge_quantization_and_storage(self):
  a=np.array(lab['adapter']['A']);b=np.array(lab['adapter']['B']);base=np.array(lab['weights']['base']['head.weight']);merged=np.array(lab['weights']['lora']['head.weight'])
  np.testing.assert_allclose(base+b@a,merged,atol=1e-12)
  codes,scales,reconstructed=m.quantize(merged)
  np.testing.assert_array_equal(codes,lab['quantization']['codes']);np.testing.assert_allclose(reconstructed,lab['weights']['int8_head_demo']['head.weight'],atol=1e-12)
  self.assertEqual(codes.numel()+scales.numel()*8,4144)
  z,s,r=m.quantize([[0.]*8]);self.assertEqual(s.item(),1);self.assertEqual(r.abs().sum().item(),0)
 def test_06_deterministic_external_cli_artifact_reload_and_state_restoration(self):
  before={p.name:m.digest(p) for p in DATA.iterdir() if p.is_file()};state=torch.random.get_rng_state().clone();threads=torch.get_num_threads()
  with tempfile.TemporaryDirectory() as folder:
   folder=Path(folder);report=m.workflow(output=folder/'report.json',artifact_dir=folder/'artifacts')
   self.assertEqual(report,lab['report']);self.assertEqual(torch.get_num_threads(),threads);torch.testing.assert_close(torch.random.get_rng_state(),state,rtol=0,atol=0)
   for name,sha in json.loads((folder/'artifacts/checksums.json').read_text()).items():self.assertEqual(m.digest(folder/'artifacts'/name),sha)
   for name,mode in [('full.pt','full'),('lora_merged.pt','lora')]:
    state_dict=torch.load(folder/'artifacts'/name,map_location='cpu',weights_only=True)
    for key,value in state_dict.items():np.testing.assert_allclose(value,lab['weights'][mode][key],atol=1e-12)
   result=subprocess.run([sys.executable,str(DATA/'adaptation_workflow.py'),'--output',str(folder/'external.json')],cwd=folder,check=True,capture_output=True,text=True)
   self.assertEqual(json.loads((folder/'external.json').read_text()),lab['report'])
  self.assertEqual(before,{p.name:m.digest(p) for p in DATA.iterdir() if p.is_file()})
 def test_07_majority_failure_baselines_and_full_diagnostic_recalculation(self):
  rows=m.load_rows();majority=max(['SUPPORT','CONTRADICT'],key=lambda c:sum(r['label']==c for r in rows['train']))
  self.assertEqual(majority,'SUPPORT');baseline=sum(r['label']==majority for r in rows['diagnostic'])/188
  for mode in ['base','full','lora','int8_head_demo']:
   model=lm.ByteDecoder();model.load_state_dict({k:torch.tensor(v,dtype=torch.float64) for k,v in lab['weights'][mode].items()})
   self.assertEqual(m.evaluate(model,rows['diagnostic']),lab['report']['runs'][mode]['diagnostic'])
  self.assertEqual(lab['report']['runs']['lora']['diagnostic']['accuracy'],baseline)
 def test_08_artifact_hashes_frozen_nonhead_and_limits(self):
  for key,value in lab['weights']['base'].items():
   if key!='head.weight':np.testing.assert_array_equal(value,lab['weights']['lora'][key])
  folder=ROOT/'build/chapter-25-artifacts'
  for name,sha in json.loads((folder/'checksums.json').read_text()).items():self.assertEqual(m.digest(folder/name),sha)
  self.assertIn('not QLoRA',' '.join(lab['report']['limits']))
if __name__=='__main__':
 import os;os.chdir(ROOT)
 snippets=[b['body'] for l in chapter['lessons'] for b in l['blocks'] if b['type']=='code']
 for i,code in enumerate(snippets):
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(code,f'chapter25_{i}','exec'),{})
 for exercise in chapter['exercises']:
  namespace={}
  with contextlib.redirect_stdout(io.StringIO()):exec(exercise['solution'],namespace)
  np.testing.assert_allclose(namespace['answer'],exercise['expected'],atol=1e-12,rtol=1e-10)
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA))
 if not result.wasSuccessful():sys.exit(1)
 (ROOT/'build/chapter-25-python-verification.json').write_text(json.dumps(dict(snippets=len(snippets),solutions=len(chapter['exercises']),behavior_tests=result.testsRun,report=lab['report']),indent=2)+'\n')
 print('PASS:',len(snippets),'walkthroughs,10 solutions,8 behavior tests')
