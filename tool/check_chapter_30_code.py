"""Execute Chapter30 snippets and independent source/score/ranking/protocol QA."""
from pathlib import Path
import collections,contextlib,csv,gzip,hashlib,importlib.util,io,json,math,os,subprocess,sys,tempfile,unittest
import numpy as np
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/movielens'
s=importlib.util.spec_from_file_location('rec30qa',DATA/'recommendation_workflow.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
lab=json.loads((DATA/'recommendation_lab.json').read_text(encoding='utf-8'));chapter=json.loads((ROOT/'assets/content/chapter_30.json').read_text(encoding='utf-8'))
class QA(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  with gzip.open(DATA/'ratings.csv.gz','rt',encoding='utf-8') as f:cls.raw=[(int(r['userId']),int(r['movieId']),float(r['rating']),int(r['timestamp'])) for r in csv.DictReader(f)]
  cls.fit=[r for r in cls.raw if r[3]<=lab['report']['cutoff_timestamp']];cls.future=[r for r in cls.raw if r[3]>lab['report']['cutoff_timestamp']]
  cls.hist=collections.defaultdict(dict)
  for u,i,r,t in cls.fit:cls.hist[u][i]=r
  cls.likes={u:{i for i,r in h.items() if r>=4} for u,h in cls.hist.items()}
  cls.model=m.Recommender(np.array(cls.fit),m.load()[1])
 def test_01_source_hashes_exact_rows_no_duplicates_and_temporal_ties(self):
  for file,h in lab['report']['source_hashes'].items():self.assertEqual(hashlib.sha256((DATA/file).read_bytes()).hexdigest(),h)
  self.assertEqual([list(r) for r in self.fit],lab['train']);self.assertEqual([list(r) for r in self.future],lab['future']);self.assertEqual(len(set((u,i) for u,i,r,t in self.raw)),100836)
  cut=sorted(r[3] for r in self.raw)[int(.8*len(self.raw))-1];self.assertEqual(cut,lab['report']['cutoff_timestamp']);self.assertTrue(all(r[3]>cut for r in self.future))
  with (DATA/'movies.csv').open(encoding='utf-8') as f:movies={int(r['movieId']):[r['title'],[] if r['genres']=='(no genres listed)' else r['genres'].split('|')] for r in csv.DictReader(f)}
  self.assertEqual(lab['movies'],[[i,*movies[i]] for i in sorted({i for u,i,r,t in self.fit})])
 def test_02_independent_genre_idf_profiles_and_full_candidate_scores(self):
  ids=[r[0] for r in lab['movies']];g=lab['genres'];raw=np.array([[x in gs for x in g] for i,t,gs in lab['movies']]);idf=1+np.log((1+len(ids))/(1+raw.sum(0)));np.testing.assert_allclose(idf,lab['idf'],atol=1e-12)
  f=raw*idf;norm=np.sqrt((f*f).sum(1));f=np.divide(f,norm[:,None],out=np.zeros_like(f),where=norm[:,None]>0)
  for case in lab['samples']:
   u=case['user'];selected=[j for j,i in enumerate(ids) if i in self.likes.get(u,set())];p=f[selected].sum(0) if selected else np.zeros(len(g));n=np.linalg.norm(p)
   if n:np.testing.assert_allclose(f@(p/n),self.model.scores(u,'content'),atol=1e-12)
 def test_03_independent_neighbors_votes_all116_users_and_all464_lists(self):
  ids=sorted(self.model.item_index);pop=collections.Counter(i for liked in self.likes.values() for i in liked);tot=collections.defaultdict(float);cnt=collections.Counter(i for u,i,r,t in self.fit);mu=sum(r for u,i,r,t in self.fit)/len(self.fit)
  for u,i,r,t in self.fit:tot[i]+=r
  def order(scores,seen):return sorted((i for i in ids if i not in seen),key=lambda i:(-round(scores[i],12),i))[:10]
  for row in lab['rows']:
   u=row['user'];liked=self.likes.get(u,set());ns=[]
   for v,b in self.likes.items():
    co=len(liked&b)
    if u!=v and co>=2:ns.append((v,co/math.sqrt(len(liked)*len(b))*co/(co+10),co))
   ns=sorted(ns,key=lambda n:(-round(n[1],12),n[0]))[:20];den=sum(s for v,s,c in ns);scores={i:sum(s for v,s,c in ns if i in self.likes[v])/den for i in ids} if ns else pop
   self.assertEqual(order(scores,self.hist.get(u,{})),row['rankings']['user_cf']);self.assertEqual(order(pop,self.hist.get(u,{})),row['rankings']['popularity']);self.assertEqual(order({i:(tot[i]+20*mu)/(cnt[i]+20) for i in ids},self.hist.get(u,{})),row['rankings']['bayesian'])
   for method in m.METHODS:self.assertEqual(self.model.recommend(u,method),row['rankings'][method])
 def test_04_gold_eligibility_cohorts_and_independent_metrics_all_defaults(self):
  source_future=collections.defaultdict(set)
  for u,i,r,t in self.future:
   if r>=4:source_future[u].add(i)
  for row in lab['rows']:
   self.assertEqual(row['positive'],sorted(source_future[row['user']]));self.assertEqual(row['eligible'],sorted(source_future[row['user']]&set(self.model.ids)-set(self.hist.get(row['user'],{}))))
  for method in m.METHODS:
   for scope in ['warm','all']:
    rows=[r for r in lab['rows'] if (r['eligible'] and r['train_count'])] if scope=='warm' else [r for r in lab['rows'] if r['positive']];ps=[];rs=[];ns=[];union=set()
    for row in rows:
     gold=set(row['eligible' if scope=='warm' else 'positive']);rank=row['rankings'][method];hits=len(gold&set(rank));ps.append(hits/10);rs.append(hits/len(gold));dcg=sum(1/math.log2(j+2) for j,i in enumerate(rank) if i in gold);ideal=sum(1/math.log2(j+2) for j in range(min(10,len(gold))));ns.append(dcg/ideal);union.update(rank)
    expected=lab['scorecards'][method][scope];self.assertEqual(expected['users'],len(rows))
    for key,values in [('precision',ps),('recall',rs),('ndcg',ns)]:self.assertAlmostEqual(expected[key],sum(values)/len(rows))
    self.assertAlmostEqual(expected['catalog_coverage'],len(union)/len(self.model.ids))
  self.assertIsNone(m.row_metrics([1,2],[],10)['recall']);self.assertIsNone(m.scorecard([], 'user_cf')['ndcg'])
 def test_05_real_item_pairs_and_rating_rmse(self):
  for ref in lab['item_pairs']:
   a={u for u,b in self.likes.items() if ref['a'] in b};b={u for u,b in self.likes.items() if ref['b'] in b};co=len(a&b);cos=co/math.sqrt(len(a)*len(b));self.assertEqual(ref['overlap'],co);self.assertAlmostEqual(ref['cosine'],cos);self.assertAlmostEqual(ref['shrunk'],cos*co/(co+10))
  mu=sum(r for u,i,r,t in self.fit)/len(self.fit);sums=collections.defaultdict(float);counts=collections.Counter(i for u,i,r,t in self.fit)
  for u,i,r,t in self.fit:sums[i]+=r
  mse=sum((((sums[i]+20*mu)/(counts[i]+20) if i in counts else mu)-r)**2 for u,i,r,t in self.future)/len(self.future);self.assertAlmostEqual(math.sqrt(mse),lab['report']['bayesian_rmse'])
 def test_06_full_regeneration_and_external_cwd_asset_preservation(self):
  self.assertEqual(m.analyse(),lab);before={p.name:m.digest(p) for p in DATA.iterdir() if p.is_file()}
  with tempfile.TemporaryDirectory() as td:
   out=Path(td)/'artifacts';subprocess.run([sys.executable,str(DATA/'recommendation_workflow.py'),'--artifact-dir',str(out)],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True);self.assertEqual(json.loads((out/'recommendation_lab.json').read_text(encoding='utf-8')),lab)
   self.assertEqual(json.loads((out/'checksums.json').read_text())['recommendation_lab.json'],m.digest(out/'recommendation_lab.json'))
  self.assertEqual(before,{p.name:m.digest(p) for p in DATA.iterdir() if p.is_file()})
 def test_07_source_cases_cold_fallback_seen_filter_and_neighbor_sensitivity(self):
  for case in lab['samples']:
   self.assertEqual(case['history'],[[i,r] for i,r in sorted(self.hist.get(case['user'],{}).items())]);self.assertEqual(case['neighbours'],[list(n) for n in self.model.neighbours(case['user'])]);seen=set(self.hist.get(case['user'],{}))
   for method in m.METHODS:self.assertTrue(not seen&{i for i,s in case['top'][method]});self.assertEqual(self.model.recommend(case['user'],method,exclude_seen=False),case['unfiltered'][method])
  cold=lab['samples'][-1]['user'];self.assertNotIn(cold,self.hist);self.assertEqual(self.model.recommend(cold,'user_cf'),self.model.recommend(cold,'popularity'));self.assertEqual(self.model.recommend(cold,'content'),self.model.recommend(cold,'popularity'))
  u=lab['samples'][0]['user'];self.assertFalse(np.allclose(self.model.scores(u,'user_cf'),self.model.scores(u,'user_cf',shrink=0,neighbours=5)))

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
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA));assert result.wasSuccessful();report=dict(chapter=30,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,passed=True)
 (ROOT/'build/chapter-30-code-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
