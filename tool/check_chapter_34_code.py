"""Execute capstone teaching code; independently audit roles, sources and serving."""
from pathlib import Path
import contextlib,importlib.util,io,json,hashlib,math,os,subprocess,sys,tempfile,unittest
import numpy as np
from scipy.sparse import csr_matrix
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/movielens'
spec=importlib.util.spec_from_file_location('capstone34qa',DATA/'recommender_capstone_workflow.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
lab=json.loads((DATA/'recommender_capstone_lab.json').read_text(encoding='utf-8'));chapter=json.loads((ROOT/'assets/content/chapter_34.json').read_text(encoding='utf-8'))

def independent_metrics(ranked,gold):
 gold=set(gold);h=len(gold.intersection(ranked[:10]));dcg=sum(1/math.log2(j+2)for j,i in enumerate(ranked[:10])if i in gold);ideal=sum(1/math.log2(j+2)for j in range(min(10,len(gold))))
 return [h/10,h/len(gold),dcg/ideal]
def independent_fuse(sources,weights,budget=50):
 ranks={s:{i:j+1 for j,i in enumerate(sources[s][:budget])}for s in m.SOURCES};pool=list(dict.fromkeys(i for s in m.SOURCES for i in sources[s][:budget]));contrib={i:[w/(60+ranks[s][i])if i in ranks[s]else 0 for s,w in zip(m.SOURCES,weights)]for i in pool};scores={i:sum(contrib[i])for i in pool};ranked=sorted(pool,key=lambda i:(-round(scores[i],12),i))[:10];return pool,ranked,contrib,scores
class QA(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.raw,cls.movies=m.source().load();cls.fit=cls.raw[cls.raw[:,3]<=1458635162];cls.ids=np.unique(cls.fit[:,1]).astype(int);cls.users=np.unique(cls.fit[:,0]).astype(int);cls.im={i:j for j,i in enumerate(cls.ids)};cls.um={u:j for j,u in enumerate(cls.users)};cls.hist={u:{}for u in cls.users}
  for u,i,r,t in cls.fit:cls.hist[int(u)][int(i)]=float(r)
  positive=cls.fit[cls.fit[:,2]>=4];cls.b=csr_matrix((np.ones(len(positive)),([cls.um[int(u)]for u in positive[:,0]],[cls.im[int(i)]for i in positive[:,1]])),shape=(522,7867));cls.pop=np.asarray(cls.b.sum(0)).ravel();cls.norms=np.sqrt(np.asarray(cls.b.sum(1)).ravel());cls.overlap=(cls.b@cls.b.T).toarray();cls.names=sorted({g for i in cls.ids for g in cls.movies[i]['genres']});x=np.array([[g in cls.movies[i]['genres']for g in cls.names]for i in cls.ids],dtype=float);cls.idf=1+np.log((1+len(cls.ids))/(1+x.sum(0)));x*=cls.idf;cls.features=np.divide(x,np.linalg.norm(x,axis=1,keepdims=True),out=np.zeros_like(x),where=np.linalg.norm(x,axis=1,keepdims=True)>0)
 def test_01_original_sources_exact_disjoint_timestamp_roles_and_gold_joins(self):
  for name,h in lab['report']['source_hashes'].items():self.assertEqual(m.digest(DATA/name),h)
  r=lab['report'];self.assertEqual([len(self.fit),len(self.raw)], [80668,100836]);np.testing.assert_equal(self.fit,lab['model']['train']);self.assertEqual(r['validation_cutoff'],1498029445)
  for role,events in [('validation',self.raw[(self.raw[:,3]>1458635162)&(self.raw[:,3]<=1498029445)]),('audit',self.raw[self.raw[:,3]>1498029445])]:
   self.assertEqual(len(events),10084);self.assertEqual([r['user']for r in lab['roles'][role]],sorted(set(events[:,0].astype(int))))
   for row in lab['roles'][role]:
    gold=set(int(i)for u,i,r,t in events if u==row['user']and r>=4);seen=self.hist.get(row['user'],{});self.assertEqual(row['positive'],sorted(gold));self.assertEqual(row['eligible'],sorted(gold.intersection(self.im)-set(seen)));self.assertEqual(row['history_sha256'],hashlib.sha256(m.payload(sorted(seen.items())).encode()).hexdigest())
 def test_02_independent_fit_only_idf_profiles_cf_and_all_source_top100(self):
  np.testing.assert_allclose(self.idf,lab['model']['idf'],atol=1e-12);self.assertEqual(self.ids.tolist(),[r[0]for r in lab['model']['movies']]);cache={}
  for rows in lab['roles'].values():
   for row in rows:
    uid=row['user']
    if uid not in cache:
     seen=self.hist.get(uid,{});positive=[self.im[i]for i,r in seen.items()if r>=4];profile=self.features[positive].sum(0)if positive else np.zeros(len(self.names));norm=np.linalg.norm(profile);content=self.features@(profile/norm)if norm else self.pop.copy();cf=self.pop.copy();no_neighbor=True
     if uid in self.um:
      ui=self.um[uid];co=self.overlap[ui];den=self.norms[ui]*self.norms;sim=np.divide(co,den,out=np.zeros_like(co),where=den>0)*co/(co+10);sim[co<2]=0;sim[ui]=0;order=np.lexsort((self.users,-np.round(sim,12)));neighbors=[j for j in order if sim[j]>0][:20]
      if neighbors:
       no_neighbor=False;v=np.zeros(522);v[neighbors]=sim[neighbors];cf=np.asarray(self.b.T@v).ravel()/v.sum()
     source={}
     for name,scores in [('popularity',self.pop),('content',content),('user_cf',cf)]:
      available=[j for j,i in enumerate(self.ids)if i not in seen];available.sort(key=lambda j:(-round(float(scores[j]),12),int(self.ids[j])));source[name]=[int(self.ids[j])for j in available[:100]]
     cache[uid]=(source,no_neighbor,not positive)
    source,no_neighbor,no_positive=cache[uid];self.assertEqual(source,row['sources']);self.assertEqual(no_neighbor,row['cf_fallback']);self.assertEqual(no_positive,row['cold_fallback'])
 def test_03_independent_all_rrf_unions_ranks_contributions_and_seen_filters(self):
  for rows in lab['roles'].values():
   for row in rows:
    for name,weights in m.POLICIES.items():
     pool,ranked,contrib,scores=independent_fuse(row['sources'],weights);ref=row['pipelines'][name];self.assertEqual(pool,ref['candidates']);self.assertEqual(ranked,ref['ranked']);self.assertEqual(ranked,row['rankings'][name]);self.assertFalse(set(pool)&set(self.hist.get(row['user'],{})))
     for value in ref['trace']:np.testing.assert_allclose(value['contributions'],contrib[value['item']],atol=1e-15);self.assertAlmostEqual(value['score'],scores[value['item']])
    for budget in [25,100]:
     pool,ranked,_,_=independent_fuse(row['sources'],[1,1,2],budget);actual=m.fuse(row['sources'],'rrf_cf',budget);self.assertEqual(actual['candidates'],pool);self.assertEqual(actual['ranked'],ranked);self.assertLessEqual(len(pool),3*budget)
 def test_04_independent_all_scorecards_ceilings_and_baseline_limits(self):
  for role,rows in lab['roles'].items():
   for method,scopes in lab['scorecards'][role].items():
    for scope,ref in scopes.items():
     selected=[r for r in rows if r['train_count']and r['eligible']]if scope=='warm'else[r for r in rows if r['positive']and(scope!='cold'or not r['train_count'])];values=[];union=set()
     for row in selected:
      gold=set(row['eligible'if scope=='warm'else'positive']);ranked=row['rankings'][method];pool=row['pipelines'][method]['candidates']if method in m.POLICIES else row['sources'][method][:10];h=len(set(pool)&gold);metric=independent_metrics(ranked,gold);values.append(metric+[h/len(gold),min(10,h)/len(gold),len(pool)]);union.update(ranked);self.assertLessEqual(metric[1],min(10,h)/len(gold)+1e-12)
     self.assertEqual(ref['users'],len(selected));np.testing.assert_allclose(np.mean(values,axis=0),[ref[k]for k in ['precision','recall','ndcg','candidate_recall','oracle_recall10','mean_candidates']],atol=1e-12);self.assertAlmostEqual(ref['catalog_coverage'],len(union)/7867)
   self.assertGreater(lab['scorecards'][role]['user_cf']['warm']['ndcg'],lab['scorecards'][role]['rrf_cf']['warm']['ndcg'])
 def test_05_validation_only_selector_and_paired_bootstrap_are_conditional(self):
  cards=lab['scorecards']['validation'];names=list(m.POLICIES);selected=sorted(names,key=lambda p:(-round(cards[p]['warm']['ndcg'],12),-round(cards[p]['warm']['recall'],12),names.index(p)))[0];self.assertEqual(selected,'rrf_cf');self.assertEqual(m.select(cards),selected)
  tie={p:dict(warm=dict(ndcg=.1,recall=.2))for p in names};self.assertEqual(m.select(tie),names[0]);rows=[r for r in lab['roles']['audit']if r['train_count']and r['eligible']];x=np.array([independent_metrics(r['rankings'][selected],r['eligible'])[1]-independent_metrics(r['rankings']['popularity'],r['eligible'])[1]for r in rows]);samples=x[np.random.default_rng(34).integers(len(x),size=(5000,len(x)))].mean(1);self.assertEqual(len(x),18);self.assertAlmostEqual(x.mean(),lab['paired']['mean']);np.testing.assert_allclose(np.quantile(samples,[.025,.975]),[lab['paired']['low'],lab['paired']['high']],atol=1e-15)
 def test_06_artifact_contract_all_faults_and_guarded_cache_responses(self):
  expected=lab['manifest'];self.assertFalse(m.contract_errors(expected,dict(expected)))
  row=lab['roles']['audit'][0];signature=m.cache_signature(row,expected,'rrf_cf')
  for key in expected:
   wrong=dict(expected);wrong[key]='declared software fault';self.assertEqual(m.contract_errors(expected,wrong),[key]);wrong.pop(key);self.assertEqual(m.contract_errors(expected,wrong),[key])
   self.assertNotEqual(m.cache_signature(row,dict(expected,**{key:'new-generation'}),'rrf_cf'),signature)
  for mode in ['complete','shared_user','omit_policy']:
   replay=m.replay(lab['roles']['audit'],expected,mode);self.assertEqual(replay,lab['cache'][mode])
   for request in replay['trace']:
    row=next(r for r in lab['roles']['audit']if r['user']==request['user']);_,ranked,_,_=independent_fuse(row['sources'],m.POLICIES[request['policy']]);self.assertEqual(ranked,request['ranked'])
  self.assertEqual(lab['cache']['complete']['hits'],2);self.assertEqual(lab['cache']['shared_user']['rejected'],1);self.assertEqual(lab['cache']['omit_policy']['rejected'],3)
 def test_07_complete_artifact_actual_bytes_verification_and_tamper_rejection(self):
  with tempfile.TemporaryDirectory()as td:
   out=Path(td)/'bundle';subprocess.run([sys.executable,str(DATA/'recommender_capstone_workflow.py'),'--artifact-dir',str(out)],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True);self.assertTrue(m.verify_bundle(out)['verified']);self.assertEqual(json.loads((out/'recommender_capstone_lab.json').read_text(encoding='utf-8')),lab)
   result=subprocess.check_output([sys.executable,str(DATA/'recommender_capstone_workflow.py'),'--verify-dir',str(out)],cwd=td,text=True);self.assertTrue(json.loads(result)['verified'])
   self.assertEqual((out/'SOURCE_README.txt').read_bytes(),(DATA/'SOURCE_README.txt').read_bytes());self.assertEqual(m.verify_bundle(out)['files'],4)
   model=out/'capstone_model.json';self.assertEqual(m.digest(model),lab['manifest']['model_sha256']);model.write_bytes(model.read_bytes()+b' ')
   with self.assertRaisesRegex(ValueError,'Checksum mismatch'):m.verify_bundle(out)
 def test_08_exact_full_reproduction_rng_and_source_asset_preservation(self):
  before={p.name:m.digest(p)for p in DATA.iterdir()if p.is_file()};state=np.random.get_state();self.assertEqual(m.analyse(),lab);after=np.random.get_state();np.testing.assert_equal(state[1],after[1]);self.assertEqual(state[0],after[0]);self.assertEqual(state[2:],after[2:]);self.assertEqual(before,{p.name:m.digest(p)for p in DATA.iterdir()if p.is_file()})

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
  assert abs(scope['result']-e['expected'])<1e-9,e['id']
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA));assert result.wasSuccessful()
 report=dict(chapter=34,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,passed=True);(ROOT/'build/chapter-34-code-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
