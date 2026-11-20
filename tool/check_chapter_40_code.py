"""Run all25 walkthroughs/12solutions andindependent final-evidence audits."""
from pathlib import Path
import contextlib,copy,hashlib,importlib.util,io,json,math,os,random,subprocess,sys,tempfile,unittest
import numpy as np
from sklearn.metrics import confusion_matrix,precision_score,recall_score,accuracy_score
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/final_capstone'
spec=importlib.util.spec_from_file_location('portfolio40qa',DATA/'portfolio_workflow.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
lab=m.read(DATA/'portfolio_lab.json');chapter=m.read(ROOT/'assets/content/chapter_40.json')
class QA(unittest.TestCase):
 def test_01_actual_nine_dependency_hashes_exact_source_records_and_no_new_eval_scope(self):
  self.assertEqual(len(lab['report']['dependencies']),9)
  for path,h in lab['report']['dependencies'].items():self.assertEqual(m.digest(ROOT/'assets/datasets'/path),h)
  for flag in ['reserved_outcomes_newly_scored','new_training_runs']:self.assertEqual(lab['report'][flag],0)
  self.assertFalse(lab['report']['production_measured']);self.assertFalse(lab['report']['hiring_outcomes_observed']);red=m.read(ROOT/'assets/datasets/wine_quality/capstone_lab.json');white=m.read(ROOT/'assets/datasets/wine_quality/deep_capstone_lab.json');rec=m.read(ROOT/'assets/datasets/movielens/recommender_capstone_lab.json')
  self.assertEqual(lab['records']['classical'],red['decision_predictions']);self.assertEqual(lab['records']['deep'],white['decision_rows']);self.assertEqual(lab['records']['recommendation'],rec['roles']['audit']);self.assertEqual([len(lab['records'][k])for k in m.FILES],[313,955,74,6]);self.assertEqual(white['selection']['test_rows_in_labs'],0);self.assertEqual(white['selection']['winner'],'mlp');self.assertGreater(lab['summaries']['deep:all']['mean_cost'],white['decision_metrics']['logistic']['mean_cost'])
 def test_02_sklearn_independent_all_six_classifier_slices_counts_cost_and_undefined_metrics(self):
  for project,threshold in [('classical',.3),('deep',.25)]:
   for scope in m.SLICES:
    rows=m.select(lab['records'][project],scope);y=np.array([r['positive']for r in rows]);pred=np.array([r['probability']>=threshold for r in rows]);tn,fp,fn,tp=confusion_matrix(y,pred,labels=[0,1]).ravel();ref=lab['summaries'][project+':'+scope];self.assertEqual([ref[k]for k in ['tp','fp','tn','fn']],[tp,fp,tn,fn]);self.assertEqual(ref['n'],len(rows));self.assertEqual(ref['accuracy'],accuracy_score(y,pred));self.assertEqual(ref['mean_cost'],(fp+4*fn)/len(rows));self.assertEqual(ref['precision'],precision_score(y,pred)if tp+fp else None);self.assertEqual(ref['recall'],recall_score(y,pred)if tp+fn else None)
  self.assertEqual(lab['summaries']['classical:all']['mean_cost'],127/313);self.assertEqual(lab['summaries']['deep:all']['mean_cost'],314/955);self.assertIsNone(lab['summaries']['classical:first5']['recall'])
 def test_03_all_three_recommender_slices_independent_binary_gains_and_macro_denominators(self):
  for scope in m.SLICES:
   rows=m.select(lab['records']['recommendation'],scope);valid=[r for r in rows if r['eligible']];precisions=[];recalls=[];ndcgs=[];hits=0
   for row in valid:
    gold=set(row['eligible']);ranked=row['rankings']['rrf_cf'][:10];self.assertEqual(len(set(ranked)),len(ranked));gains=np.array([i in gold for i in ranked],dtype=float);hit=int(gains.sum());hits+=hit;discount=1/np.log2(np.arange(len(gains))+2);ideal=(1/np.log2(np.arange(min(10,len(gold)))+2)).sum();precisions.append(hit/10);recalls.append(hit/len(gold));ndcgs.append(float(gains@discount/ideal))
   r=lab['summaries']['recommendation:'+scope];self.assertEqual(r['n'],len(rows));self.assertEqual(r['eligible_users'],len(valid));self.assertEqual(r['excluded_users'],len(rows)-len(valid));self.assertEqual(r['hits'],hits)
   for key,v in [('precision',precisions),('recall',recalls),('ndcg',ndcgs)]:self.assertAlmostEqual(r[key],np.mean(v),13)
  self.assertEqual(lab['summaries']['recommendation:all']['n'],74)
 def test_04_all_six_rag_original_quotes_decisions_mixed_roles_and_no_truthclaim(self):
  original=m.read(ROOT/'assets/datasets/scifact_rag/capstone_lab.json');corpus={str(r['doc_id']):r for r in map(json.loads,(ROOT/'assets/datasets/scifact_rag/corpus.jsonl').read_text().splitlines())};self.assertEqual(len(original['samples']),6);self.assertGreater(len({r['role']for r in lab['records']['rag']}),1)
  for row,source in zip(lab['records']['rag'],original['samples']):
   case=source['cases']['retrieved'];chunks=case['pack']['selected'];self.assertEqual(row['id'],source['id']);self.assertEqual(row['text'],case['generation']['text']);self.assertEqual(row['emitted'],case['decision']['emitted']);self.assertEqual(row['format_valid'],case['generation']['format_valid']);self.assertEqual(row['reason'],'unverified_hypothesis');self.assertTrue(chunks)
   for c in chunks:self.assertEqual(' '.join(corpus[c['doc_id']]['abstract'][c['start']:c['end']]),c['text'])
  for scope in m.SLICES:
   r=lab['summaries']['rag:'+scope];self.assertEqual(r['format_valid'],r['n']);self.assertEqual(r['exact_packs'],r['n']);self.assertEqual(r['emitted'],r['n']);self.assertEqual(r['verified_answers'],0);self.assertIsNone(r['truth_accuracy'])
 def test_05_all_sixteen_explicit_metadata_faults_do_not_mutate_originals(self):
  for key,ref in lab['audits'].items():
   project,fault=key.split(':');before=copy.deepcopy(lab['cards'][project]);actual=m.audit(before,fault);self.assertEqual(actual,ref);self.assertEqual(before,lab['cards'][project]);expected=[]if fault=='none'else[{'source_mismatch':'source_sha256','license_missing':'license','production_claim':'production_measured'}[fault]];self.assertEqual(actual['issues'],expected);self.assertEqual(actual['passed'],not expected)
  with self.assertRaises(ValueError):m.audit(lab['cards']['deep'],'unknown')
  for project in m.FILES:self.assertEqual(m.summaries(project,[])['n'],0)
  with self.assertRaises(ValueError):m.summaries('unknown',[])
  with self.assertRaises(ValueError):m.select([],'random')
 def test_06_sixteen_unique_role_specific_prompts_reviewkeys_and_template_ownership_gates(self):
  cards=lab['mock_cards'];self.assertEqual(len(cards),16);self.assertEqual(len({c['prompt']for c in cards.values()}),16)
  for role in ['ml_engineer','data_scientist','recs_engineer','llm_engineer']:
   for stage in ['project','coding','statistics','systems']:
    card=cards[role+':'+stage];self.assertEqual(set(card['review']),set(m.CHECKS));self.assertTrue(card['focus']);self.assertTrue(card['follow_up']);self.assertTrue(card['prompt'])
  template=m.report_markdown(lab);self.assertEqual(template.count('My contribution:'),4);self.assertEqual(template.count('Next validation:'),4);self.assertIn('not personal ownership orproduction achievement',template);self.assertIn('Hashconsistencyrequires trustedexpectedmanifest',template)
 def test_07_external_cwd_six_payload_bundle_actual_notice_bytes_hash_and_semantic_tamper(self):
  with tempfile.TemporaryDirectory()as td:
   fresh=Path(td)/'cli_bundle';subprocess.run([sys.executable,str(DATA/'portfolio_workflow.py'),'--artifact-dir',str(fresh)],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True);self.assertEqual(m.verify_bundle(fresh)['projects'],4)
   out=Path(td)/'bundle';m.export_bundle(out,lab);self.assertEqual(m.verify_bundle(out),dict(verified=True,files=6,projects=4,mock_rounds=16));self.assertEqual((out/'MOVIELENS_SOURCE.txt').read_bytes(),(ROOT/'assets/datasets/movielens/SOURCE_README.txt').read_bytes());self.assertEqual(json.loads(subprocess.check_output([sys.executable,str(DATA/'portfolio_workflow.py'),'--verify-dir',str(out)],cwd=td,text=True))['files'],6)
   file=out/'evidence_contract.json';file.write_bytes(file.read_bytes()+b' ')
   with self.assertRaisesRegex(ValueError,'Checksum mismatch'):m.verify_bundle(out)
   contract=m.read(file);contract['production_measured']=True;file.write_text(json.dumps(contract));checks=m.read(out/'checksums.json');checks[file.name]=m.digest(file);(out/'checksums.json').write_text(json.dumps(checks))
   with self.assertRaisesRegex(ValueError,'Evidence scope mismatch'):m.verify_bundle(out)
   m.export_bundle(out,lab);file=out/'portfolio_lab.json';fake=m.read(file);fake['summaries']['classical:all']['tp']=999;file.write_text(json.dumps(fake));checks=m.read(out/'checksums.json');checks[file.name]=m.digest(file);(out/'checksums.json').write_text(json.dumps(checks))
   with self.assertRaisesRegex(ValueError,'Evidence semantic mismatch'):m.verify_bundle(out)
 def test_08_exact_replay_default_cli_sourceassets_and_global_rng_preservation(self):
  paths=[p for p in DATA.iterdir()if p.is_file()]+[ROOT/'assets/datasets'/p for p in lab['report']['dependencies']];before={str(p):m.digest(p)for p in paths};rng=random.getstate();state=np.random.get_state();self.assertEqual(m.analyse(),lab);self.assertEqual(random.getstate(),rng);np.testing.assert_equal(np.random.get_state()[1],state[1])
  with tempfile.TemporaryDirectory()as td:subprocess.run([sys.executable,str(DATA/'portfolio_workflow.py')],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True)
  self.assertEqual(before,{str(p):m.digest(p)for p in paths})
if __name__=='__main__':
 os.chdir(ROOT);snippets=0
 for lesson in chapter['lessons']:
  for b in lesson['blocks']:
   if b['type']=='code':
    with contextlib.redirect_stdout(io.StringIO()):exec(compile(b['body'],lesson['id'],'exec'),{})
    snippets+=1
 for e in chapter['exercises']:
  scope={}
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(e['solution'],e['id'],'exec'),scope)
  assert abs(scope['result']-e['expected'])<=max(1e-8,abs(e['expected'])*1e-12),e['id']
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA));assert result.wasSuccessful();report=dict(chapter=40,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,projects=4,summary_presets=12,audit_presets=16,mock_rounds=16,new_training_runs=0,reserved_outcomes_newly_scored=0,production_measured=False,hiring_outcomes_observed=False,passed=True);(ROOT/'build/chapter-40-code-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(report)
