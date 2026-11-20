from pathlib import Path
import contextlib,io,json,importlib.util,math,sys,tempfile,subprocess,unittest
import numpy as np
import torch
from sklearn.metrics import brier_score_loss,log_loss,confusion_matrix,accuracy_score
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/scifact_rag'
s=importlib.util.spec_from_file_location('reliability_qa',DATA/'reliability_workflow.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
chapter=json.loads((ROOT/'assets/content/chapter_26.json').read_text(encoding='utf-8'));lab=json.loads((DATA/'reliability_lab.json').read_text(encoding='utf-8'))
class QA(unittest.TestCase):
 def test_01_source_hashes_all564_probabilities_and_paired_roles(self):
  self.assertEqual(m.digest(DATA/'adaptation_lab.json'),lab['report']['adaptation_asset_sha256']);self.assertEqual(m.digest(DATA/'claims_dev.jsonl'),lab['report']['source_claims_sha256'])
  spec=importlib.util.spec_from_file_location('reliability_adaptation_qa',DATA/'adaptation_workflow.py');a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
  source=a.load_rows()['diagnostic'];x,pos,target=a.batch(source);asset=json.loads((DATA/'adaptation_lab.json').read_text());lm=a.lm_module();old=torch.get_num_threads()
  try:
   torch.set_num_threads(1)
   for name in ['base','full','lora']:
    model=lm.ByteDecoder();model.load_state_dict({k:torch.tensor(v,dtype=torch.float64) for k,v in asset['weights'][name].items()})
    with torch.no_grad():p=model(x)[torch.arange(len(source)),pos][:,[83,67]].softmax(-1)[:,0].numpy()
    rows=lab['variants'][name]['rows'];self.assertEqual([r['id'] for r in rows],[q['id'] for q in source]);np.testing.assert_allclose(p,[r['p_support'] for r in rows],atol=1e-13)
    self.assertEqual([r['gold'] for r in rows],[int(q['label']=='SUPPORT') for q in source])
  finally:torch.set_num_threads(old)
 def test_02_independent_sklearn_confusion_brier_logloss_all_variants(self):
  for name,variant in lab['variants'].items():
   rows=variant['rows'];p=np.array([r['p_support'] for r in rows]);y=np.array([r['gold'] for r in rows]);pred=(p>=.5).astype(int);r=variant['audit']
   tn,fp,fn,tp=confusion_matrix(y,pred,labels=[0,1]).ravel();self.assertEqual([r['tp'],r['tn'],r['fp'],r['fn']],[tp,tn,fp,fn])
   self.assertAlmostEqual(r['accuracy'],accuracy_score(y,pred),places=14);self.assertAlmostEqual(r['brier'],brier_score_loss(y,p,scale_by_half=True),places=14);self.assertAlmostEqual(r['binary_nll_clipped'],log_loss(y,p,labels=[0,1]),places=14)
 def test_03_independent_bins_and_inclusive_selective_sweeps(self):
  for variant in lab['variants'].values():
   rows=variant['rows'];p=np.array([r['p_support'] for r in rows]);y=np.array([r['gold'] for r in rows]);confidence=np.maximum(p,1-p);correct=(p>=.5)==y;index=np.minimum(np.floor(confidence*5).astype(int),4);ece=0.
   for i,bin in enumerate(variant['audit']['bins']):
    selected=index==i;self.assertEqual(bin['count'],selected.sum())
    if selected.any():
     gap=abs(correct[selected].mean()-confidence[selected].mean());ece+=selected.mean()*gap;self.assertAlmostEqual(bin['gap'],gap,places=13)
    else:self.assertIsNone(bin['gap']);self.assertIsNone(bin['accuracy'])
   self.assertAlmostEqual(ece,variant['audit']['ece'],places=13)
   for ref in variant['audit']['sweep']:
    selected=confidence>=ref['threshold'];self.assertEqual(ref['accepted'],int(selected.sum()));self.assertAlmostEqual(ref['coverage'],selected.mean())
    if selected.any():self.assertAlmostEqual(ref['risk'],1-correct[selected].mean())
    else:self.assertIsNone(ref['risk']);self.assertIsNone(ref['accuracy'])
 def test_04_null_boundaries_invalid_contracts_and_real_slices(self):
  rows=[dict(id='a',gold=1,p_support=.8),dict(id='b',gold=0,p_support=.2)]
  self.assertEqual(m.selective(rows,.8)['accepted'],2);self.assertIsNone(m.selective(rows,.9)['risk'])
  perfect=m.audit([dict(id='a',gold=1,p_support=1.),dict(id='b',gold=0,p_support=0.)]);self.assertEqual(perfect['bins'][4]['count'],2);self.assertIsNone(perfect['bins'][0]['accuracy'])
  self.assertEqual(sum(len(r['text'].encode('utf-8'))>80 for r in lab['variants']['lora']['rows']),93)
  for invalid in [[],rows+rows,[dict(id='a',gold=2,p_support=.5)],[dict(id='a',gold=1,p_support=float('nan'))]]:
   with self.assertRaises(ValueError):m.audit(invalid)
  for threshold in [.4,1.1,float('nan'),True]:
   with self.assertRaises(ValueError):m.selective(rows,threshold)
  with self.assertRaises(ValueError):m.audit(rows,bins=0)
 def test_05_independent_all120_request_clocks_and_nearest_rank_percentiles(self):
  requests=lab['requests'];self.assertEqual(len(requests),40)
  for size in [1,4,8]:
   finish=0.;latency=[];ref=lab['replay_runs'][str(size)]
   for begin in range(0,40,size):
    group=requests[begin:begin+size];start=max(finish,(begin+len(group)-1)*5.)
    finish=start+2+max(r['input_tokens'] for r in group)*.4+max(r['output_tokens'] for r in group)*1.2
    for i,row in enumerate(group):
     arrival=(begin+i)*5.;r=ref['rows'][begin+i];self.assertEqual(r['id'],row['id']);self.assertAlmostEqual(r['start_ms'],start);self.assertAlmostEqual(r['queue_ms'],start-arrival);self.assertAlmostEqual(r['finish_ms'],finish);self.assertAlmostEqual(r['latency_ms'],finish-arrival);latency.append(finish-arrival)
   self.assertAlmostEqual(ref['p95_ms'],sorted(latency)[math.ceil(.95*40)-1]);self.assertAlmostEqual(ref['throughput_per_second'],40000/finish)
  zero=m.replay([dict(id='a',input_tokens=1,output_tokens=1)],interval=0,prefill=0,decode=0,overhead=0);self.assertIsNone(zero['throughput_per_second'])
 def test_06_cache_scope_unicode_and_replay_invalid_counts(self):
  fields=['বাংলা "query"\n','model','corpus','prompt','scope','greedy'];key=m.cache_key(*fields);self.assertEqual(json.loads(key),fields)
  for i in range(6):
   altered=fields.copy();altered[i]+='-new';self.assertNotEqual(key,m.cache_key(*altered))
  with self.assertRaises(ValueError):m.cache_key('','m','c','p','s','d')
  for kwargs in [dict(batch_size=0),dict(interval=-1),dict(prefill=float('nan'))]:
   with self.assertRaises(ValueError):m.replay(lab['requests'],**kwargs)
  with self.assertRaises(ValueError):m.replay([dict(id='x',input_tokens=0,output_tokens=1)])
 def test_07_external_directory_artifact_reload_and_no_implicit_asset_writes(self):
  before={p.name:m.digest(p) for p in DATA.iterdir() if p.is_file()}
  with tempfile.TemporaryDirectory() as folder:
   folder=Path(folder);subprocess.run([sys.executable,str(DATA/'reliability_workflow.py'),'--output',str(folder/'report.json'),'--artifact-dir',str(folder/'artifacts')],cwd=folder,capture_output=True,text=True,check=True)
   self.assertEqual(json.loads((folder/'report.json').read_text()),lab['report']);self.assertEqual(json.loads((folder/'artifacts/golden.json').read_text(encoding='utf-8')),lab)
   for name,digest in json.loads((folder/'artifacts/checksums.json').read_text()).items():self.assertEqual(m.digest(folder/'artifacts'/name),digest)
  self.assertEqual(before,{p.name:m.digest(p) for p in DATA.iterdir() if p.is_file()})
 def test_08_rng_threads_import_safety_and_limitations(self):
  state=torch.random.get_rng_state().clone();threads=torch.get_num_threads();report=m.workflow();torch.testing.assert_close(torch.random.get_rng_state(),state,rtol=0,atol=0);self.assertEqual(torch.get_num_threads(),threads);self.assertEqual(report,lab['report'])
  self.assertIn('not device/network/GPU latency',' '.join(report['limits']));self.assertEqual(report['variants']['lora']['contradict_recall'],0)
if __name__=='__main__':
 import os;os.chdir(ROOT)
 snippets=[b['body'] for l in chapter['lessons'] for b in l['blocks'] if b['type']=='code']
 for i,code in enumerate(snippets):
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(code,f'chapter26_{i}','exec'),{})
 for exercise in chapter['exercises']:
  namespace={}
  with contextlib.redirect_stdout(io.StringIO()):exec(exercise['solution'],namespace)
  np.testing.assert_allclose(namespace['answer'],exercise['expected'],atol=1e-12,rtol=1e-10)
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA))
 if not result.wasSuccessful():sys.exit(1)
 (ROOT/'build/chapter-26-python-verification.json').write_text(json.dumps(dict(snippets=len(snippets),solutions=len(chapter['exercises']),behavior_tests=result.testsRun,report=lab['report']),indent=2)+'\n')
 print('PASS:16walkthroughs,10solutions,8behavior tests')
