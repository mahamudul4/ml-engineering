"""All Chapter29 code and independent full-source/GRU/protocol checks."""
from pathlib import Path
import contextlib,hashlib,importlib.util,io,json,os,subprocess,sys,tempfile,unittest
import numpy as np
import torch
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/scifact_rag'
s=importlib.util.spec_from_file_location('capstone_qa',DATA/'capstone_workflow.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
lab=json.loads((DATA/'capstone_lab.json').read_text(encoding='utf-8'));chapter=json.loads((ROOT/'assets/content/chapter_29.json').read_text(encoding='utf-8'))
def reload():
 d=m.ResponseDecoder();d.load_state_dict({k:torch.tensor(v,dtype=torch.float64) for k,v in lab['weights'].items()});return d
class QA(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.rag=m.rag_module();cls.system,cls.roles,cls.index=cls.rag.load_inputs();cls.rows=m.prepare(cls.system,cls.roles,cls.rag)
 def test_01_original_hashes_labels_and_case_roles(self):
  r=lab['report']
  for file,key in [('corpus.jsonl','source_sha256'),('claims_train.jsonl','train_sha256'),('claims_dev.jsonl','diagnostic_sha256')]:self.assertEqual(m.digest(DATA/file),r[key])
  self.assertEqual(m.digest(self.index/'retrieval_index.json'),r['index_sha256']);self.assertEqual(len(self.system.source),5183)
  for sample in lab['samples']:
   row=next(r for r in self.rows[sample['role']] if r['id']==sample['id']);self.assertEqual(row['text'],sample['text']);self.assertEqual(row['gold'],sample['gold']);self.assertEqual(row['evidence'],sample['evidence'])
 def test_02_all_packs_exact_quotes_and_independent_fnv_features(self):
  import re,collections,math
  def block(text):
   counts=collections.Counter()
   for word in re.findall('[A-Za-z0-9]+',text.lower()):
    h=2166136261
    for value in word.encode('ascii'):h=((h^value)*16777619)%(2**32)
    counts[h%128]+=1
   x=np.array([math.log(1+counts[i]) for i in range(128)]);norm=np.sqrt((x*x).sum());return x/norm if norm else x
  for sample in lab['samples']:
   for mode,ref in sample['cases'].items():
    run=self.system.run(sample['text'],budget=0 if mode=='empty_budget' else 1024);self.assertEqual(run['context'],ref['pack']['context']);self.assertEqual(run['used_bytes'],len(run['context'].encode()));self.assertTrue(all(self.rag.audit_quote(c,self.system.source)['exact_quote'] for c in run['selected']))
    text='' if mode=='query_only' else m.plain_context(run);np.testing.assert_allclose(np.r_[block(sample['text']),block(text)],ref['features'],atol=1e-13)
 def test_03_all_full_decoder_traces_independent_numpy_gru(self):
  w={k:np.array(v) for k,v in lab['weights'].items()};sig=lambda x:1/(1+np.exp(-x))
  for sample in lab['samples']:
   for case in sample['cases'].values():
    h=np.tanh(w['condition.weight']@case['features']+w['condition.bias']);np.testing.assert_allclose(h,case['generation']['initial_hidden'],atol=1e-13);token=1
    for step in case['generation']['trace']:
     x=w['embedding.weight'][token];i=w['cell.weight_ih']@x+w['cell.bias_ih'];hh=w['cell.weight_hh']@h+w['cell.bias_hh'];r=sig(i[:16]+hh[:16]);z=sig(i[16:32]+hh[16:32]);n=np.tanh(i[32:]+r*hh[32:]);h=(1-z)*n+z*h;logits=w['head.weight']@h+w['head.bias'];p=np.zeros(14);p[2:]=np.exp(logits[2:]-max(logits[2:]));p/=p.sum();self.assertEqual(step['previous'],token);token=int(p.argmax());self.assertEqual(step['chosen'],token);np.testing.assert_allclose(h,step['hidden'],atol=1e-12);np.testing.assert_allclose(p,step['probabilities'],atol=1e-12)
 def test_04_all564_raw_diagnostic_generations_source_order_and_gold(self):
  d=reload();rows=self.rows['test']
  for mode,variant in lab['variants'].items():
   for i,(row,ref) in enumerate(zip(rows,variant['rows'])):
    context=row['context'] if mode=='retrieved' else '' if mode=='query_only' else rows[(i+1)%len(rows)]['context'];g=m.decode(d,m.features(row['text'],context));g={k:v for k,v in g.items() if k not in ['trace','initial_hidden']}
    self.assertEqual(g,ref['generation']);self.assertEqual(row['id'],ref['id']);self.assertEqual(row['gold'],ref['gold']);self.assertEqual(row['rationale_hit'],ref['rationale_hit'])
 def test_05_independent_metrics_thresholds_joint_and_empty_sets(self):
  for variant in lab['variants'].values():
   rows=variant['rows'];gold=np.array([r['gold'] for r in rows]);valid=np.array([r['generation']['format_valid'] for r in rows]);correct=np.array([r['generation']['text'] for r in rows])==gold;hit=np.array([r['rationale_hit'] for r in rows]);confidence=np.array([r['generation']['first_token_confidence'] for r in rows])
   for threshold,key in [(0,'summary'),(.9,'strict')]:
    ref=variant[key];accepted=valid&(confidence>=threshold)&np.array([r['has_context'] for r in rows]);self.assertEqual(ref['correct'],int((valid&correct).sum()));self.assertEqual(ref['joint_hits'],int((valid&correct&(hit==1)).sum()));self.assertEqual(ref['accepted'],int(accepted.sum()));self.assertAlmostEqual(ref['coverage'],accepted.mean());self.assertAlmostEqual(ref['accepted_risk'],1-correct[accepted].mean())
   self.assertIsNone(m.summarize(rows,1)['accepted_risk'])
 def test_06_padding_loss_mask_gradients_runtime_policy_and_tamper(self):
  logits=torch.zeros(2,3,14,dtype=torch.float64,requires_grad=True);target=torch.tensor([[3,2,0],[4,5,2]]);loss=torch.nn.functional.cross_entropy(logits.reshape(-1,14),target.reshape(-1),ignore_index=0);loss.backward();self.assertTrue(torch.equal(logits.grad[0,2],torch.zeros(14,dtype=torch.float64)));self.assertAlmostEqual(loss.item(),np.log(14))
  g=dict(format_valid=True,first_token_confidence=.9);self.assertTrue(m.policy(g,True,True,.9)['emitted']);self.assertEqual(m.policy(g,False,True)['reason'],'citation_mismatch');self.assertEqual(m.policy(g,True,False)['reason'],'no_context')
  quote=dict(lab['samples'][3]['cases']['retrieved']['pack']['selected'][0]);quote['text']+=' [edited]';self.assertEqual(self.rag.audit_quote(quote,self.system.source),dict(resolvable=True,exact_quote=False))
 def test_07_full_retrain_exact_rng_threads_and_canonical_weights_hash(self):
  state=torch.random.get_rng_state().clone();threads=torch.get_num_threads();actual=m.analyse();self.assertEqual(actual,lab);self.assertTrue(torch.equal(state,torch.random.get_rng_state()));self.assertEqual(threads,torch.get_num_threads());self.assertEqual(hashlib.sha256(json.dumps(lab['weights'],sort_keys=True,separators=(',',':')).encode()).hexdigest(),lab['report']['weights_sha256'])
 def test_08_external_cwd_cli_preserves_assets_and_trusted_artifact_reload(self):
  before={p.name:m.digest(p) for p in DATA.iterdir() if p.is_file()}
  with tempfile.TemporaryDirectory() as directory:
   out=Path(directory)/'artifacts';subprocess.run([sys.executable,str(DATA/'capstone_workflow.py'),'--artifact-dir',str(out)],cwd=directory,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True)
   for name,digest in json.loads((out/'checksums.json').read_text()).items():self.assertEqual(m.digest(out/name),digest)
   d=m.ResponseDecoder();d.load_state_dict(torch.load(out/'response_decoder.pt',weights_only=True));self.assertEqual({k:v.tolist() for k,v in d.state_dict().items()},lab['weights'])
  self.assertEqual(before,{p.name:m.digest(p) for p in DATA.iterdir() if p.is_file()})

if __name__=='__main__':
 os.chdir(ROOT);torch.set_num_threads(1);snippets=0
 for lesson in chapter['lessons']:
  for b in lesson['blocks']:
   if b['type']=='code':
    with contextlib.redirect_stdout(io.StringIO()):exec(compile(b['body'],lesson['id'],'exec'),{})
    snippets+=1
 for e in chapter['exercises']:
  scope={}
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(e['solution'],e['id'],'exec'),scope)
  assert abs(scope['result']-e['expected'])<1e-9,e['id']
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA));assert result.wasSuccessful()
 report=dict(chapter=29,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,passed=True)
 (ROOT/'build/chapter-29-code-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
