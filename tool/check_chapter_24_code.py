from pathlib import Path
import contextlib,io,json,importlib.util,hashlib,math,sys,subprocess,tempfile,unittest
import numpy as np
from threadpoolctl import threadpool_limits
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/scifact_rag'
spec=importlib.util.spec_from_file_location('rag_qa',DATA/'rag_workflow.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
chapter=json.loads((ROOT/'assets/content/chapter_24.json').read_text(encoding='utf-8'))
lab=json.loads((DATA/'rag_lab.json').read_text(encoding='utf-8'))
system,roles,indexdir=m.load_inputs()
def independent_pack(candidates,budget):
 selected=[];used=0;parents=set()
 for c in candidates:
  text=f"[{c['doc_id']}:{c['start']}-{c['end']}]\n"+c['text']+'\n';cost=len(text.encode('utf-8'))
  if c['score']>=.05 and len(selected)<3 and c['doc_id'] not in parents and used+cost<=budget:
   selected.append(c);used+=cost;parents.add(c['doc_id'])
 return selected,used
class QA(unittest.TestCase):
 def test_01_original_hashes_alignment_and_role_denominators(self):
  self.assertEqual(len(system.source),5183)
  self.assertEqual(sum(len(d['abstract']) for d in system.source.values()),45952)
  self.assertEqual([len(roles[r]) for r in ['train','test']],[809,300])
  self.assertEqual([sum(bool(q['evidence']) for q in roles[r]) for r in ['train','test']],[505,188])
  self.assertEqual(len({q['claim'] for q in roles['train']}&{q['claim'] for q in roles['test']}),2)
  self.assertEqual(m.digest(indexdir/'retrieval_index.json'),lab['report']['frozen_index_sha256'])
 def test_02_all_thirty_complete_traces_and_independent_weights(self):
  with threadpool_limits(1):
   for sample in lab['samples']:
    for name,kwargs in [('rerank',{}),('document_order',{'rerank':False}),('small_budget',{'budget':256}),('empty_budget',{'budget':0}),('shallow',{'count':5})]:
     actual=system.run(sample['text'],**kwargs);gold=sample['cases'][name]
     self.assertEqual(json.loads(json.dumps(actual)),gold)
     for c in actual['candidates']:
      # Independent dense TF-IDF construction for every candidate chunk.
      def encode(text):
       counts={}
       for t in m.tokens(text):counts[t]=counts.get(t,0)+1
       x=np.zeros(4096)
       for t,n in counts.items():
        i=system.vocabulary.get(t)
        if i is not None:x[i]=(1+math.log(n))*system.idf[i]
       norm=np.linalg.norm(x);return x/norm if norm else x
      self.assertAlmostEqual(float(encode(c['text'])@encode(sample['text'])),c['score'],places=12)
     selected,used=independent_pack(actual['candidates'],actual['budget'])
     self.assertEqual(selected,actual['selected']);self.assertEqual(used,actual['used_bytes'])
 def test_03_independent_all_query_diagnostic_aggregation(self):
  rows=[json.loads(line) for line in (ROOT/'build/chapter-24-artifacts/audit_rows.jsonl').read_text().splitlines()]
  self.assertEqual(len(rows),2218)
  for role in ['train','test']:
   for mode in ['document_order','rerank']:
    group=[r for r in rows if r['role']==role and r['mode']==mode]
    expected=lab['report']['evaluation'][role]['modes'][mode]
    self.assertAlmostEqual(np.mean([not r['abstained'] for r in group]),expected['quote_coverage'])
    self.assertAlmostEqual(np.mean([r['used_bytes'] for r in group]),expected['mean_context_bytes'])
    annotated=[r['metrics'] for r in group if r['metrics'] is not None]
    for key in ['sentence_union_recall','complete_rationale_hit','candidate_rationale_available']:
     self.assertAlmostEqual(np.mean([r[key] for r in annotated]),expected[key],places=13)
 def test_04_source_windows_coverage_and_exact_boundaries(self):
  for doc in system.source.values():
   for size,overlap in [(2,1),(3,1)]:
    chunks=m.chunk_document(doc,size,overlap)
    self.assertEqual({i for c in chunks for i in range(c['start'],c['end'])},set(range(len(doc['abstract']))))
    self.assertTrue(all(m.audit_quote(c,system.source)['exact_quote'] for c in chunks))
  c=lab['samples'][0]['cases']['rerank']['selected'][0];cost=len(m.fragment(c).encode('utf-8'))
  self.assertTrue(m.pack_context([c],system.source,budget=cost-1)['abstained'])
  self.assertEqual(m.pack_context([c],system.source,budget=cost)['used_bytes'],cost)
 def test_05_quote_corruption_alternative_rationales_and_missing_labels(self):
  c=lab['samples'][0]['cases']['rerank']['selected'][0]
  self.assertEqual(m.audit_quote({**c,'text':'edited'},system.source),dict(resolvable=True,exact_quote=False))
  self.assertEqual(m.audit_quote({**c,'doc_id':'missing'},system.source),dict(resolvable=False,exact_quote=False))
  source={'7':{'abstract':['one','two','three']}}
  packed=m.pack_context([dict(doc_id='7',start=0,end=1,text='one',score=.5)],source)
  gold={'7':[dict(sentences=[0],label='SUPPORT'),dict(sentences=[1,2],label='SUPPORT')]}
  self.assertEqual(m.evidence_metrics(packed,gold,{'7'}),dict(sentence_union_recall=1/3,complete_rationale_hit=1,candidate_rationale_available=1))
  self.assertIsNone(m.evidence_metrics(packed,{},set()))
 def test_06_invalid_contracts_empty_unicode_and_label_independence(self):
  for args in [dict(size=0),dict(overlap=2),dict(overlap=-1)]:
   with self.assertRaises(ValueError):system.run('',**args)
  for args in [dict(budget=-1),dict(budget=True),dict(count=0),dict(rerank=1)]:
   with self.assertRaises(ValueError):system.run('cell',**args)
  for text in ['', 'বাংলা শেখা','zzzzzzzzzzzzzzzzzzzzzz']:
   r=system.run(text);self.assertTrue(r['abstained']);self.assertEqual(r['used_bytes'],0)
  c=lab['samples'][0]['cases']['rerank']['selected'][0]
  for candidates in [[c,c],[{**c,'score':float('nan')}],[{**c,'text':'tampered'}]]:
   with self.assertRaises(ValueError):m.pack_context(candidates,system.source)
  q=lab['samples'][0];a=system.run(q['text']);q2={**q,'evidence':{}}
  self.assertEqual(system.run(q2['text']),a)
 def test_07_external_cli_artifact_reload_and_no_asset_writes(self):
  before={p.name:m.digest(p) for p in DATA.iterdir() if p.is_file()}
  with tempfile.TemporaryDirectory() as temp:
   folder=Path(temp)
   subprocess.run([sys.executable,str(DATA/'rag_workflow.py'),'--output',str(folder/'report.json'),'--artifact-dir',str(folder/'artifacts')],cwd=folder,check=True,capture_output=True,text=True)
   self.assertEqual(json.loads((folder/'report.json').read_text()),lab['report'])
   self.assertEqual(json.loads((folder/'artifacts/golden.json').read_text(encoding='utf-8')),lab)
   for name,digest in json.loads((folder/'artifacts/checksums.json').read_text()).items():self.assertEqual(m.digest(folder/'artifacts'/name),digest)
  self.assertEqual(before,{p.name:m.digest(p) for p in DATA.iterdir() if p.is_file()})
 def test_08_import_rng_threads_and_report_limitations(self):
  state=np.random.get_state();threads=__import__('threadpoolctl').threadpool_info()
  s=importlib.util.spec_from_file_location('rag_import_safe',DATA/'rag_workflow.py');module=importlib.util.module_from_spec(s);s.loader.exec_module(module)
  np.testing.assert_array_equal(state[1],np.random.get_state()[1]);self.assertEqual(threads,__import__('threadpoolctl').threadpool_info())
  self.assertIn('not fresh independent confirmation',' '.join(lab['report']['limits']))
  self.assertLess(lab['report']['evaluation']['test']['modes']['rerank']['complete_rationale_hit'],.5)
if __name__=='__main__':
 import os;os.chdir(ROOT)
 snippets=[b['body'] for l in chapter['lessons'] for b in l['blocks'] if b['type']=='code']
 for i,code in enumerate(snippets):
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(code,f'chapter24_{i}','exec'),{})
 for exercise in chapter['exercises']:
  namespace={}
  with contextlib.redirect_stdout(io.StringIO()):exec(exercise['solution'],namespace)
  np.testing.assert_allclose(namespace['answer'],exercise['expected'],atol=1e-12,rtol=1e-10)
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA))
 if not result.wasSuccessful():sys.exit(1)
 (ROOT/'build/chapter-24-python-verification.json').write_text(json.dumps(dict(snippets=len(snippets),solutions=len(chapter['exercises']),behavior_tests=result.testsRun,report=lab['report']),indent=2)+'\n')
 print('PASS:22 walkthroughs,10 solutions,8 behavior tests')
