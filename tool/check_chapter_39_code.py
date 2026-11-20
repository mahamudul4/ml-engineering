"""Execute every teaching snippet and independently audit algorithms/SQLite/ML."""
from pathlib import Path
from collections import Counter,defaultdict
import bisect,contextlib,copy,hashlib,heapq,importlib.util,io,json,math,os,random,sqlite3,subprocess,sys,tempfile,unittest
import numpy as np
import torch
from scipy.special import expit
from scipy.stats import binomtest
from sklearn.metrics import confusion_matrix,precision_score,recall_score,log_loss
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/interview_practice'
spec=importlib.util.spec_from_file_location('interview39qa',DATA/'interview_workflow.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
lab=m.read(DATA/'interview_lab.json');chapter=m.read(ROOT/'assets/content/chapter_39.json')
torch.set_num_threads(1)
class QA(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.rec,cls.design=m.sources();cls.raw=cls.rec['model']['train'];cls.movie={r[0]:r for r in cls.rec['model']['movies']}
 def test_01_exact_original_fit_rows_metadata_schema_cutoff_integrity_and_readonly(self):
  for name,h in lab['report']['dependencies'].items():self.assertEqual(m.digest(ROOT/'assets/datasets'/name),h)
  self.assertEqual(m.digest(DATA/'interview.sqlite'),lab['report']['database_sha256']);self.assertEqual(lab['report']['reserved_outcomes_scored'],0);self.assertEqual(len(self.raw),80668)
  with contextlib.closing(m.connect())as db:
   actual=[tuple(r)for r in db.execute('SELECT user_id,movie_id,rating,ts FROM ratings ORDER BY user_id,movie_id')];self.assertEqual(actual,sorted(map(tuple,self.raw)));self.assertEqual(len(set((r[0],r[1])for r in actual)),80668);self.assertEqual(len({r[0]for r in actual}),522);self.assertTrue(all(r[3]<=1458635162 and .5<=r[2]<=5 for r in actual));self.assertEqual(db.execute('PRAGMA integrity_check').fetchone()[0],'ok');self.assertEqual(db.execute('PRAGMA foreign_key_check').fetchall(),[])
   self.assertEqual([tuple(r)for r in db.execute('SELECT * FROM movies ORDER BY movie_id')],[(r[0],r[1])for r in sorted(self.movie.values())]);self.assertEqual([tuple(r)for r in db.execute('SELECT * FROM movie_genres ORDER BY movie_id,genre')],sorted((r[0],g)for r in self.movie.values()for g in r[2]))
   with self.assertRaises(sqlite3.OperationalError):db.execute('DELETE FROM ratings')
 def test_02_independent_counter_sort_heapq_oracles_all18_selection_presets(self):
  counts=Counter(r[1]for r in self.raw);sums=defaultdict(float)
  for u,i,r,t in self.raw:sums[i]+=r
  self.assertEqual(lab['catalog'],[dict(id=i,title=self.movie[i][1],n=counts[i],total=sums[i])for i in sorted(counts)])
  for minimum in [1,10,50]:
   eligible=[i for i in counts if counts[i]>=minimum];key=lambda i:(int(np.floor(sums[i]/counts[i]*1e12+.5)),-i)
   for k in [5,10,20]:
    oracle=sorted(eligible,key=key,reverse=True)[:k];self.assertEqual(heapq.nlargest(k,eligible,key=key),oracle)
    for method in ['heap','merge']:
     ref=lab['algorithms'][f'{minimum}:{k}:{method}'];self.assertEqual(ref['ids'],oracle);self.assertEqual(ref['eligible'],len(eligible));self.assertEqual(ref['selection_slots'],min(k,len(eligible))if method=='heap'else len(eligible));self.assertEqual(m.top_k(lab['catalog'],k,minimum,method),ref)
  fixture=[dict(id=2,n=2,total=8.),dict(id=1,n=2,total=8.)]
  self.assertEqual(m.top_k(fixture,k=20,minimum=1)['ids'],[1,2]);self.assertEqual(m.top_k(fixture,k=0,minimum=1)['ids'],[])
  for kw in [dict(k=-1),dict(minimum=0),dict(method='unknown')]:
   with self.assertRaises(ValueError):m.top_k(fixture,**kw)
 def test_03_all104_sql_results_against_independent_python_relational_oracle(self):
  self.assertEqual(len(lab['sql']),104)
  with contextlib.closing(m.connect())as db:
   for key,expected in lab['sql'].items():
    task,variant,genre,minimum,k=key.split(':');minimum=int(minimum);k=int(k);rows=[]
    for r in self.raw:
     gs=self.movie[r[1]][2]
     if variant=='fixed':copies=int(genre=='All'or genre in gs)
     else:copies=len(gs)if genre=='All'else int(genre in gs)
     rows.extend([r]*copies)
    if task=='summary':oracle=[dict(n=len(rows),users=len({r[0]for r in rows}),movies=len({r[1]for r in rows}),mean=sum(r[2]for r in rows)/len(rows))]
    elif task=='top_movies':
     groups=defaultdict(list)
     for r in rows:groups[r[1]].append(r[2])
     items=[dict(movie_id=i,n=len(v),mean=sum(v)/len(v))for i,v in groups.items()if len(v)>=minimum];oracle=sorted(items,key=lambda r:(-round(r['mean'],12),r['movie_id']))[:k]
    else:
     latest={}
     for r in rows:
      if r[0]not in latest or(r[3],r[1])>(latest[r[0]][3],latest[r[0]][1]):latest[r[0]]=r
     oracle=[dict(zip(['user_id','movie_id','rating','ts'],latest[u]))for u in sorted(latest)[:k]]
    self.assertEqual(expected,oracle,key);self.assertEqual(m.run_sql(db,task=task,variant=variant,genre=genre,minimum=minimum,k=k),oracle,key)
  self.assertEqual(lab['sql']['summary:fixed:All:10:10'][0]['n'],80668);self.assertEqual(lab['sql']['summary:fanout:All:10:10'][0]['n'],217203)
 def test_04_all738_raw_feature_logits_scores_stable_bce_autograd_and_no_updates(self):
  s=self.design['spam'];params=s['model'];x=np.array([r['features']for r in s['validation']]);y=np.array([r['label']for r in s['validation']]);z=((x-params['mean'])/params['scale'])@np.array(params['weights'])+params['intercept'];p=expit(z)
  np.testing.assert_allclose(z,[r['logit']for r in lab['diagnostics']],atol=1e-12);np.testing.assert_allclose(p,[r['score']for r in lab['diagnostics']],atol=1e-14);self.assertEqual([r['index']for r in lab['diagnostics']],[r['index']for r in s['validation']]);self.assertEqual([r['label']for r in lab['diagnostics']],y.tolist())
  loss=np.maximum(z,0)-z*y+np.log1p(np.exp(-np.abs(z)));np.testing.assert_allclose(loss,np.logaddexp(0,z)-z*y,atol=1e-13)
  tz=torch.tensor(z,dtype=torch.float64,requires_grad=True);ty=torch.tensor(y,dtype=torch.float64);objective=torch.nn.BCEWithLogitsLoss()(tz,ty);objective.backward();self.assertAlmostEqual(objective.item(),loss.mean(),13);np.testing.assert_allclose(tz.grad.numpy(),(p-y)/738,atol=1e-16);self.assertAlmostEqual(loss.mean(),.22277269030786706,13)
  step=1e-5;f=lambda b:np.mean(np.logaddexp(0,z+b)-(z+b)*y);self.assertAlmostEqual((f(step)-f(-step))/(2*step),np.mean(p-y),9)
 def test_05_all27_diagnostic_presets_against_sklearn_and_direct_cost_oracles(self):
  rows=lab['diagnostics'];y=np.array([r['label']for r in rows]);p=np.array([r['score']for r in rows]);z=np.array([r['logit']for r in rows]);fixed=m.metrics(rows)
  for ref in lab['metrics'].values():
   predicted=(z if ref['bug']=='logit_threshold'else p)>=ref['threshold'];tn,fp,fn,tp=confusion_matrix(y,predicted,labels=[0,1]).ravel();self.assertEqual([ref[k]for k in ['tp','fp','tn','fn']],[tp,fp,tn,fn]);precision=precision_score(y,predicted);recall=recall_score(y,predicted);self.assertEqual(ref['precision'],precision);self.assertEqual(ref['recall'],recall);self.assertEqual(ref['reported_precision'],recall if ref['bug']=='precision_swap'else precision);self.assertEqual(ref['symbolic_cost'],ref['fp_cost']*fp+fn);self.assertEqual(ref['accuracy'],np.mean(predicted==y));self.assertEqual(ref['bce'],fixed['bce'])
  self.assertNotEqual(m.metrics(rows,bug='logit_threshold')['fn'],30);self.assertEqual(m.metrics(rows,bug='precision_swap')['reported_precision'],226/256)
  for kw in [dict(threshold=float('nan')),dict(threshold=2),dict(bug='unknown'),dict(fp_cost=-1)]:
   with self.assertRaises(ValueError):m.metrics(rows,**kw)
 def test_06_independent_stream_boundary_mse_gradient_and_paired_statistics(self):
  ratings=np.array([r[2]for r in self.raw]);n=0;mean=m2=0.
  for x in ratings:n+=1;delta=x-mean;mean+=delta/n;m2+=delta*(x-mean)
  self.assertAlmostEqual(mean,ratings.mean(),12);self.assertAlmostEqual(m2/(n-1),ratings.var(ddof=1),12)
  times=sorted(r[3]for r in self.raw);self.assertEqual(bisect.bisect_right(times,1262304000),sum(t<=1262304000 for t in times));self.assertEqual(bisect.bisect_right(times,1262304000),61151)
  raw=np.array(sorted(self.raw)[:64]);x=(raw[:,3]-raw[:,3].mean())/raw[:,3].std();y=raw[:,2];b=y.mean();analytic=np.mean(2*x*(b-y));eps=1e-5;loss=lambda w:np.mean((x*w+b-y)**2);self.assertAlmostEqual((loss(eps)-loss(-eps))/(2*eps),analytic,8)
  truth=np.array([r['label']for r in lab['diagnostics']]);scores=np.array([r['score']for r in lab['diagnostics']]);a=(scores>=.2)==truth;c=(scores>=.8)==truth;left=int(np.sum(a&~c));right=int(np.sum(c&~a));self.assertEqual(left-right,int(np.sum(a)-np.sum(c)));self.assertTrue(0<=binomtest(left,left+right,.5).pvalue<=1)
 def test_07_external_cwd_six_payload_bundle_notices_sql_and_tamper_gates(self):
  with tempfile.TemporaryDirectory()as td:
   out=Path(td)/'bundle';m.export_bundle(out,lab);self.assertEqual(m.verify_bundle(out),dict(verified=True,files=6,fit_rows=80668,validation_rows=738));self.assertEqual((out/'MOVIELENS_SOURCE.txt').read_bytes(),(ROOT/'assets/datasets/movielens/SOURCE_README.txt').read_bytes());self.assertEqual(json.loads(subprocess.check_output([sys.executable,str(DATA/'interview_workflow.py'),'--verify-dir',str(out)],cwd=td,text=True))['files'],6)
   file=out/'source_contract.json';file.write_bytes(file.read_bytes()+b' ')
   with self.assertRaisesRegex(ValueError,'Checksum mismatch'):m.verify_bundle(out)
   contract=json.loads(file.read_text());contract['reserved_outcomes_scored']=680;file.write_text(json.dumps(contract));checks=m.read(out/'checksums.json');checks[file.name]=m.digest(file);(out/'checksums.json').write_text(json.dumps(checks))
   with self.assertRaisesRegex(ValueError,'Practice contract mismatch'):m.verify_bundle(out)
 def test_08_exact_reproduction_default_cli_assets_and_rng_preservation(self):
  files=[p for p in DATA.iterdir()if p.is_file()]+[ROOT/'assets/datasets'/p for p in m.DEPENDENCIES];before={str(p):m.digest(p)for p in files};rng=random.getstate();state=np.random.get_state();self.assertEqual(m.analyse(),lab);self.assertEqual(random.getstate(),rng);np.testing.assert_equal(np.random.get_state()[1],state[1])
  with tempfile.TemporaryDirectory()as td:subprocess.run([sys.executable,str(DATA/'interview_workflow.py')],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True)
  self.assertEqual(before,{str(p):m.digest(p)for p in files})
if __name__=='__main__':
 os.chdir(ROOT);snippets=0
 for lesson in chapter['lessons']:
  for block in lesson['blocks']:
   if block['type']=='code':
    with contextlib.redirect_stdout(io.StringIO()):exec(compile(block['body'],lesson['id'],'exec'),{})
    snippets+=1
 for e in chapter['exercises']:
  scope={}
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(e['solution'],e['id'],'exec'),scope)
  assert abs(scope['result']-e['expected'])<=max(1e-8,abs(e['expected'])*1e-12),e['id']
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA));assert result.wasSuccessful();report=dict(chapter=39,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,fit_rows=80668,validation_rows=738,sql_presets=104,algorithm_presets=18,diagnostic_presets=27,reserved_outcomes_scored=0,production_timing_measured=False,interview_outcomes_observed=False,passed=True);(ROOT/'build/chapter-39-code-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(report)
