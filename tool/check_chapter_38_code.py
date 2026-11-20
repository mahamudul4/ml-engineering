"""Execute every Chapter38 snippet and independently audit source-backed cases."""
from pathlib import Path
import contextlib,copy,hashlib,importlib.util,io,json,math,os,random,subprocess,sys,tempfile,unittest
from unittest.mock import patch
import numpy as np
from scipy.special import expit
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import GroupShuffleSplit
from sklearn.preprocessing import StandardScaler

ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/system_design'
spec=importlib.util.spec_from_file_location('design38qa',DATA/'design_workflow.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
lab=json.loads((DATA/'design_lab.json').read_text(encoding='utf-8'));chapter=json.loads((ROOT/'assets/content/chapter_38.json').read_text(encoding='utf-8'))

class QA(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.raw=np.loadtxt(ROOT/'assets/datasets/spambase/spambase.data',delimiter=',');cls.x=cls.raw[:,:57];cls.y=cls.raw[:,57].astype(int)
 def test_01_original_bytes_profile_groups_roles_and_frozen_dependencies(self):
  manifest=json.loads((ROOT/'assets/datasets/spambase/source_manifest.json').read_text())
  self.assertEqual(manifest['license'],'CC BY 4.0');self.assertIn('Erik',manifest['citation']);self.assertEqual(self.raw.shape,(4601,58));self.assertTrue(np.isfinite(self.raw).all());self.assertTrue((self.x>=0).all())
  for name,h in m.SPAM_HASHES.items():self.assertEqual(m.digest(ROOT/'assets/datasets/spambase'/name),h)
  _,groups=np.unique(self.x,axis=0,return_inverse=True);np.testing.assert_equal(groups,lab['spam']['groups']);self.assertEqual(len(set(groups)),4207)
  fit,other=next(GroupShuffleSplit(n_splits=1,train_size=.7,random_state=38).split(self.x,groups=groups));v,t=next(GroupShuffleSplit(n_splits=1,train_size=.5,random_state=380).split(self.x[other],groups=groups[other]));roles=dict(train=sorted(fit.tolist()),validation=sorted(other[v].tolist()),reserved=sorted(other[t].tolist()))
  self.assertEqual(roles,lab['spam']['roles']);self.assertEqual([len(roles[k])for k in roles],[3183,738,680]);self.assertEqual(sorted(sum(roles.values(),[])),list(range(4601)))
  for a,b in [('train','validation'),('train','reserved'),('validation','reserved')]:self.assertFalse(set(groups[roles[a]])&set(groups[roles[b]]))
  self.assertEqual([r['index']for r in lab['spam']['validation']],roles['validation']);self.assertFalse(set(roles['reserved'])&{r['index']for r in lab['spam']['validation']});self.assertEqual(lab['report']['reserved_outcomes_scored'],0)
  for name,h in lab['dependencies'].items():self.assertEqual(m.digest(ROOT/'assets/datasets'/name),h)
  bike=json.loads((ROOT/'assets/datasets/bike_sharing/serving_lab.json').read_text());self.assertEqual(bike['report']['reserved_outcomes_used'],0)
 def test_02_independent_fixed_train_only_refit_and_all738_scores(self):
  roles=lab['spam']['roles'];fit=roles['train'];v=roles['validation'];scaler=StandardScaler().fit(self.x[fit]);model=LogisticRegression(C=1,solver='lbfgs',max_iter=2000,tol=1e-9,random_state=38).fit(scaler.transform(self.x[fit]),self.y[fit]);p=lab['spam']['model']
  np.testing.assert_allclose(scaler.mean_,self.x[fit].mean(0),atol=1e-12);np.testing.assert_allclose(p['mean'],scaler.mean_,atol=1e-12);np.testing.assert_allclose(p['scale'],scaler.scale_,atol=1e-12);np.testing.assert_allclose(p['weights'],model.coef_[0],atol=1e-12);self.assertEqual(p['intercept'],model.intercept_[0]);self.assertEqual(p['fit_rows'],3183)
  scores=expit(((self.x[v]-np.array(p['mean']))/p['scale'])@np.array(p['weights'])+p['intercept']);np.testing.assert_allclose(scores,model.predict_proba(scaler.transform(self.x[v]))[:,1],atol=1e-14)
  for j,r in enumerate(lab['spam']['validation']):np.testing.assert_equal(r['features'],self.x[v[j]]);self.assertEqual(r['label'],self.y[v[j]]);self.assertAlmostEqual(r['score'],scores[j],13);self.assertAlmostEqual(m.spam_predict(p,r['features']),scores[j],13)
  self.assertEqual(lab['spam']['fit_iterations'],int(model.n_iter_[0]))
  for key in ['scale','weights','mean']:
   bad=copy.deepcopy(p);bad[key].pop();self.assertFalse(m.valid_spam_model(bad));self.assertIsNone(m.spam_predict(bad,self.x[v[0]].tolist()))
  bad=copy.deepcopy(p);bad['scale'][0]=0;self.assertFalse(m.valid_spam_model(bad))
  for features in [[float('nan')]*57,[-1]*57,[0]*56]:self.assertIsNone(m.spam_predict(p,features))
 def test_03_independent_validation_confusion_counts_and_denominators(self):
  rows=lab['spam']['validation'];y=np.array([r['label']for r in rows]);p=np.array([r['score']for r in rows])
  for threshold,counts in [(.2,[248,72,410,8]),(.5,[226,20,462,30]),(.8,[178,10,472,78])]:
   predicted=p>=threshold;actual=[int(np.sum(predicted&(y==1))),int(np.sum(predicted&(y==0))),int(np.sum(~predicted&(y==0))),int(np.sum(~predicted&(y==1)))];self.assertEqual(actual,counts);r=lab['spam']['metrics'][str(threshold)];self.assertEqual([r[k]for k in ['tp','fp','tn','fn']],counts);tp,fp,tn,fn=counts;self.assertEqual(r['precision'],tp/(tp+fp));self.assertEqual(r['recall'],tp/(tp+fn));self.assertEqual(r['fpr'],fp/(fp+tn));self.assertEqual(r['accuracy'],(tp+tn)/738)
 def test_04_all72_review_policies_label_independence_and_precompute_guard(self):
  rows=lab['spam']['validation']
  for r in lab['policies'].values():
   middle=sorted([j for j,x in enumerate(rows)if r['low']<=x['score']<r['high']],key=lambda j:(int(np.floor(abs(rows[j]['score']-.5)*1e12+.5)),rows[j]['index']));admitted=set(middle[:r['budget']]);routes=['review'if j in admitted else 'allow'if x['score']<r['low']else'block'if x['score']>=r['high']else r['overflow']for j,x in enumerate(rows)];self.assertEqual(r['routes'],routes);self.assertEqual(r['review_ids'],[rows[j]['index']for j in middle[:r['budget']]])
   fp=sum(route=='block'and x['label']==0 for route,x in zip(routes,rows));fn=sum(route=='allow'and x['label']==1 for route,x in zip(routes,rows));decided=routes.count('allow')+routes.count('block');self.assertEqual(r['false_blocks'],fp);self.assertEqual(r['missed_spam'],fn);self.assertEqual(r['automatic_cost'],fp*r['fp_cost']+fn);self.assertEqual(r['pending'],738-decided);self.assertEqual(r['coverage'],decided/738);self.assertEqual(r['conditional_accuracy'],(decided-fp-fn)/decided)
  default=m.review_policy(rows);self.assertEqual([default[k]for k in ['allow','block','review','defer','pending','false_blocks','missed_spam']],[418,188,50,82,132,10,8]);flipped=[dict(r,label=1-r['label'])for r in rows];self.assertEqual(m.review_policy(flipped)['routes'],default['routes']);self.assertEqual(m.review_policy(rows,fp_cost=10)['routes'],default['routes'])
  with patch.object(m,'spam_predict',side_effect=AssertionError('inference must not run')):
   blocked=m.guarded_review(lab,fault=True);self.assertEqual(blocked['contract_blocked'],738);self.assertIsNone(blocked['conditional_accuracy']);bad=copy.deepcopy(lab);bad['spam']['model']['scale'][0]=0;self.assertEqual(m.guarded_review(bad)['pending'],738)
  self.assertEqual(m.review_policy([dict(index=2,score=.5,label=1),dict(index=1,score=.5,label=0)],budget=1)['review_ids'],[1])
 def test_05_all1215_capacity_assumptions_and_stability_boundaries(self):
  self.assertEqual(len(lab['capacity']),1215)
  for key,r in lab['capacity'].items():
   case=lab['cases'][key.split(':')[0]];critical=sum(max(s['ms']for s in g)for g in case['stages'])*r['scale'];serial=sum(s['ms']for g in case['stages']for s in g)*r['scale'];load=r['qps']*(1-r['hit']);cap=4*r['replicas']*1000/critical;rho=load/cap;self.assertEqual(r['critical_ms'],critical);self.assertEqual(r['serial_work_ms'],serial);self.assertEqual(r['parallel_saved_ms'],serial-critical);self.assertEqual(r['ideal_capacity'],cap);self.assertEqual(r['utilization'],rho);self.assertEqual(r['stable'],rho<1);self.assertEqual(r['in_service'],load*critical/1000 if rho<1 else None);self.assertEqual(r['deadline_slack'],r['deadline']-critical);self.assertEqual(r['state'],'OVERLOAD'if rho>=1 else'LOW HEADROOM'if rho>.7 else'WITHIN ASSUMPTION')
  case=lab['cases']['recommendation'];r=m.capacity(case);self.assertEqual([r[k]for k in ['critical_ms','serial_work_ms','backend_qps','ideal_capacity','utilization','in_service']],[20,31,500,800,.625,10]);self.assertIsNone(m.capacity(case,qps=1600)['in_service']);self.assertEqual(m.capacity(case,hit=1)['utilization'],0)
  for kw in [dict(hit=float('nan')),dict(replicas=0),dict(qps=-1),dict(scale=0)]:
   with self.assertRaises(ValueError):m.capacity(case,**kw)
 def test_06_fifteen_case_responses_match_frozen_sources_and_preflight(self):
  d=m.deps();rec=next(r for r in d['movielens/recommender_capstone_lab.json']['roles']['audit']if r['user']==15);search=d['scifact/retrieval_lab.json']['samples'][0];rag=d['scifact_rag/capstone_lab.json']['samples'][0];forecast=d['bike_sharing/serving_lab.json']
  for case in m.CASE_IDS:
   for fault in ['none','model_mismatch','upstream']:self.assertEqual(m.response(lab,case,fault),lab['responses'][case][fault])
   with patch.object(m,'deps',side_effect=AssertionError('preflight before dependency compute')):self.assertEqual(m.response(lab,case,'model_mismatch')['status'],'BLOCKED')
   for field in ['case_version','model_identity','source_identity','input_schema','policy_identity']:
    wrong=dict(lab['manifests'][case]);wrong[field]='mismatch';self.assertEqual(m.contract_errors(lab['manifests'][case],wrong),[field]);del wrong[field];self.assertEqual(m.contract_errors(lab['manifests'][case],wrong),[field])
  self.assertEqual(lab['responses']['recommendation']['none']['output']['items'],rec['rankings']['rrf_cf']);self.assertEqual(lab['responses']['recommendation']['upstream']['output']['items'],rec['sources']['popularity'][:10])
  for method,fault in [('hybrid','none'),('tfidf','upstream')]:self.assertEqual(lab['responses']['search'][fault]['output']['documents'],[r[0]for r in search['rankings'][method][:5]])
  r=lab['responses']['spam']['none']['output'];self.assertAlmostEqual(r['probability'],lab['spam']['validation'][0]['score'],13);self.assertEqual(r['decision'],'block'if r['probability']>=.5 else'allow');self.assertIsNone(lab['responses']['spam']['upstream']['output'])
  actual=next(r['cnt']for r in forecast['events']['on_time']if r['event_day']==368);self.assertEqual(lab['responses']['forecast']['upstream']['output']['prediction'],actual);self.assertEqual(actual,2368)
  generated=rag['cases']['retrieved'];self.assertEqual(lab['responses']['rag']['none']['output']['hypothesis'],generated['generation']['text']);self.assertEqual(lab['responses']['rag']['none']['reason'],'unverified_hypothesis')
  corpus={str(r['doc_id']):r for r in map(json.loads,(ROOT/'assets/datasets/scifact_rag/corpus.jsonl').read_text().splitlines())}
  for c in generated['pack']['selected']:self.assertEqual(' '.join(corpus[c['doc_id']]['abstract'][c['start']:c['end']]),c['text'])
  with patch.object(m,'rag_word',side_effect=AssertionError('empty context must abstain before generation')):self.assertEqual(m.response(lab,'rag','upstream')['status'],'ABSTAIN')
  for case in m.CASE_IDS:
   for r in lab['responses'][case].values():self.assertFalse({'label','gold','target','outcome'}&set(r.get('output')or{}))
 def test_07_six_payload_bundle_actual_bytes_crosslinks_and_semantic_tamper(self):
  with tempfile.TemporaryDirectory()as td:
   out=Path(td)/'bundle';m.export_bundle(out,lab);self.assertEqual(m.verify_bundle(out),dict(verified=True,files=6,cases=5,validation_rows=738));self.assertEqual((out/'SPAM_SOURCE.txt').read_bytes(),(ROOT/'assets/datasets/spambase/spambase.DOCUMENTATION').read_bytes());self.assertEqual((out/'MOVIELENS_SOURCE.txt').read_bytes(),(ROOT/'assets/datasets/movielens/SOURCE_README.txt').read_bytes());self.assertEqual(json.loads(subprocess.check_output([sys.executable,str(DATA/'design_workflow.py'),'--verify-dir',str(out)],cwd=td,text=True))['files'],6)
   file=out/'design_contract.json';file.write_bytes(file.read_bytes()+b' ')
   with self.assertRaisesRegex(ValueError,'Checksum mismatch'):m.verify_bundle(out)
   contract=json.loads(file.read_text());contract['reserved_outcomes_scored']=680;file.write_text(json.dumps(contract));checks=json.loads((out/'checksums.json').read_text());checks[file.name]=m.digest(file);(out/'checksums.json').write_text(json.dumps(checks))
   with self.assertRaisesRegex(ValueError,'Design contract mismatch'):m.verify_bundle(out)
 def test_08_exact_reproduction_default_cli_assets_and_global_rng_preservation(self):
  before={str(p):m.digest(p)for folder in [DATA,ROOT/'assets/datasets/spambase']for p in folder.iterdir()if p.is_file()};rng=random.getstate();npstate=np.random.get_state();self.assertEqual(m.analyse(),lab);self.assertEqual(random.getstate(),rng);np.testing.assert_equal(np.random.get_state()[1],npstate[1])
  with tempfile.TemporaryDirectory()as td:subprocess.run([sys.executable,str(DATA/'design_workflow.py')],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True)
  self.assertEqual(before,{str(p):m.digest(p)for folder in [DATA,ROOT/'assets/datasets/spambase']for p in folder.iterdir()if p.is_file()})

if __name__=='__main__':
 os.chdir(ROOT);snippets=0
 for lesson in chapter['lessons']:
  for block in lesson['blocks']:
   if block['type']=='code':
    with contextlib.redirect_stdout(io.StringIO()):exec(compile(block['body'],lesson['id'],'exec'),{})
    snippets+=1
 for exercise in chapter['exercises']:
  scope={}
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(exercise['solution'],exercise['id'],'exec'),scope)
  assert abs(scope['result']-exercise['expected'])<=max(1e-8,abs(exercise['expected'])*1e-12),exercise['id']
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA));assert result.wasSuccessful();report=dict(chapter=38,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,source_cases=5,validation_rows=738,reserved_outcomes_scored=0,production_performance_measured=False,passed=True);(ROOT/'build/chapter-38-code-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(report)
