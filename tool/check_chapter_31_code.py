"""Chapter31 executable content plus independent objective/gradient/model checks."""
from pathlib import Path
import contextlib,hashlib,importlib.util,io,json,math,os,subprocess,sys,tempfile,unittest
import numpy as np
import torch
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/movielens'
s=importlib.util.spec_from_file_location('factorqa',DATA/'factor_workflow.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
lab=json.loads((DATA/'factor_lab.json').read_text());base=json.loads((DATA/'recommendation_lab.json').read_text(encoding='utf-8'));chapter=json.loads((ROOT/'assets/content/chapter_31.json').read_text(encoding='utf-8'))
class QA(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.um={u:j for j,u in enumerate(lab['users'])};cls.im={i:j for j,i in enumerate(lab['items'])};cls.train=np.array(base['train']);cls.u=np.array([cls.um[int(u)] for u in cls.train[:,0]]);cls.i=np.array([cls.im[int(i)] for i in cls.train[:,1]]);cls.r=cls.train[:,2];cls.w={name:{k:np.array(v) if k in ['p','q','bu','bi','linear','v'] else v for k,v in row.items()} for name,row in lab['weights'].items()};cls.old=m.source()
 def test_01_original_hashes_source_roles_maps_targets_and_frozen_baselines(self):
  for name,h in lab['report']['source_hashes'].items():self.assertEqual(m.digest(DATA/name),h)
  self.assertEqual(lab['report']['source_lab_sha256'],m.digest(DATA/'recommendation_lab.json'));raw,_=self.old.load();cut=lab['report']['cutoff_timestamp'];self.assertEqual(raw[raw[:,3]<=cut].tolist(),base['train']);self.assertEqual(raw[raw[:,3]>cut].tolist(),base['future']);self.assertEqual(sorted(set(self.train[:,0].astype(int))),lab['users']);self.assertEqual(sorted(set(self.train[:,1].astype(int))),lab['items']);self.assertEqual(sum(self.r>=4),39254)
  for row,orig in zip(lab['rows'],base['rows']):
   for key in ['user','train_count','positive','eligible']:self.assertEqual(row[key],orig[key])
   for method in ['popularity','user_cf']:self.assertEqual(row['rankings'][method],orig['rankings'][method])
 def test_02_real_explicit_normal_equation_objective_and_finite_gradient(self):
  w=self.w['explicit_als'];audit=lab['als_audit'];rows=self.u==self.um[audit['user']];x=np.c_[np.ones(rows.sum()),w['q'][self.i[rows]]];y=self.r[rows]-w['mean']-w['bi'][self.i[rows]];a=x.T@x+10*np.eye(9);b=x.T@y;np.testing.assert_allclose(a,audit['a'],atol=1e-12);np.testing.assert_allclose(b,audit['b'],atol=1e-12);np.testing.assert_allclose(np.linalg.solve(a,b),audit['solution'],atol=1e-12)
  pred=w['mean']+w['bu'][self.u]+w['bi'][self.i]+(w['p'][self.u]*w['q'][self.i]).sum(1);objective=((self.r-pred)**2).sum()+10*sum(np.square(w[k]).sum() for k in ['p','q','bu','bi']);self.assertAlmostEqual(objective,w['trace'][-1],places=7)
  p=w['p'][self.u[0]].copy();q=w['q'][self.i[0]];target=self.r[0]-w['mean']-w['bu'][self.u[0]]-w['bi'][self.i[0]];loss=lambda z:(target-z@q)**2+10*z@z;analytic=-2*(target-p@q)*q+20*p;eps=1e-6;numeric=np.array([(loss(p+eps*np.eye(8)[j])-loss(p-eps*np.eye(8)[j]))/(2*eps) for j in range(8)]);np.testing.assert_allclose(analytic,numeric,atol=1e-7)
 def test_03_implicit_dense_weight_equation_and_full_dense_objective(self):
  w=self.w['implicit_als'];p=w['p'];q=w['q'];positive=self.r>=4;target=np.zeros((len(p),len(q)));target[self.u[positive],self.i[positive]]=1;c=1+20*target;scores=p@q.T;objective=(c*(target-scores)**2).sum()+.1*((p*p).sum()+(q*q).sum());self.assertAlmostEqual(objective,w['trace'][-1],places=7)
  u=self.um[lab['als_audit']['user']];liked=np.flatnonzero(target[u]);dense=q.T@(c[u,:,None]*q)+.1*np.eye(8);fast=q.T@q+20*q[liked].T@q[liked]+.1*np.eye(8);np.testing.assert_allclose(dense,fast,atol=1e-10);np.testing.assert_allclose(q.T@(c[u]*target[u]),21*q[liked].sum(0),atol=1e-10)
  for method in ['explicit_als','implicit_als']:self.assertTrue(np.all(np.diff(lab['weights'][method]['trace'])<=1e-7))
 def test_04_all_training_negative_draws_and_bpr_analytic_autograd_finite_differences(self):
  positive=self.r>=4;pu=self.u[positive];pi=self.i[positive];seen=[set(self.i[self.u==u]) for u in range(len(self.um))];allowed=[np.array(sorted(set(range(len(self.im)))-h)) for h in seen];rng=np.random.default_rng(3101)
  for epoch in range(25):
   negatives=np.array([allowed[u][rng.integers(len(allowed[u]))] for u in pu]);self.assertTrue(all(j not in seen[u] for u,j in zip(pu,negatives)));rng.permutation(len(pu))
   if epoch==0:self.assertEqual([int(pu[0]),int(pi[0]),int(negatives[0])],lab['weights']['bpr']['first_triplet'])
  ref=lab['pair_audit'];w=self.w['bpr'];p=w['p'][self.um[ref['user']]];qi=w['q'][self.im[ref['positive']]];qj=w['q'][self.im[ref['unobserved']]];d=p@(qi-qj);self.assertAlmostEqual(d,ref['margin']);self.assertAlmostEqual(np.logaddexp(0,-d),ref['loss']);g=-1/(1+np.exp(d));self.assertAlmostEqual(g,ref['derivative'])
  pt=torch.tensor(p,requires_grad=True);it=torch.tensor(qi,requires_grad=True);jt=torch.tensor(qj,requires_grad=True);loss=torch.nn.functional.softplus(-((pt*it).sum()-(pt*jt).sum()));loss.backward();np.testing.assert_allclose(pt.grad,g*(qi-qj),atol=1e-12);np.testing.assert_allclose(it.grad,g*p,atol=1e-12);np.testing.assert_allclose(jt.grad,-g*p,atol=1e-12)
  eps=1e-6;fn=lambda v:np.logaddexp(0,-v@(qi-qj));numeric=np.array([(fn(p+eps*np.eye(8)[f])-fn(p-eps*np.eye(8)[f]))/(2*eps) for f in range(8)]);np.testing.assert_allclose(numeric,pt.grad,atol=1e-7)
 def test_05_fm_explicit_pairs_derivative_and_zero_padding(self):
  ref=lab['fm_audit'];w=self.w['fm'];ids=ref['indices'];x=np.array(ref['values']);v=w['v'][ids];slow=sum(v[j]@v[k]*x[j]*x[k] for j in range(len(ids)) for k in range(j+1,len(ids)));self.assertAlmostEqual(w['bias']+w['linear'][ids]@x+slow,ref['score']);vx=v*x[:,None];self.assertAlmostEqual(slow,.5*((vx.sum(0)**2).sum()-(vx**2).sum()))
  model=m.FM(len(w['linear']),0);model.load_state_dict({k:torch.tensor(w[k],dtype=torch.float64) for k in ['bias','linear','v']});it=torch.tensor([ids+[0,0]]);xt=torch.tensor([list(x)+[0.,0.]],dtype=torch.float64);score=model(it,xt);self.assertAlmostEqual(score.item(),ref['score']);score.backward();j=ids[0];np.testing.assert_allclose(model.v.grad[j],x[0]*(vx.sum(0)-v[0]*x[0]),atol=1e-12)
  if 0 not in ids:np.testing.assert_array_equal(model.v.grad[0],np.zeros(8));self.assertEqual(model.linear.grad[0],0)
 def test_06_all464_full_catalog_rankings_and_independent_fm_item_cache(self):
  ids=np.array(lab['items']);features=[];nf=len(lab['users']);ni=len(ids);genres=lab['genres'];meta={i:gs for i,t,gs in base['movies']};w=self.w['fm'];z=[];item_terms=[]
  for j,item in enumerate(ids):
   gs=meta[int(item)];ii=[nf+j]+[nf+ni+genres.index(g) for g in gs];x=np.array([1.]+[1/math.sqrt(len(gs)) for g in gs]);vx=w['v'][ii]*x[:,None];summed=vx.sum(0);z.append(summed);item_terms.append(w['linear'][ii]@x+.5*(summed@summed-(vx*vx).sum()))
  z=np.array(z);item_terms=np.array(item_terms);hist={u:set(i for uid,i,r,t in base['train'] if uid==u) for u in self.um};positive={u for u,i,r,t in base['train'] if r>=4};pop=np.array([sum(uid==item for u,uid,r,t in []) for item in []]);counts=np.bincount(self.i[self.r>=4],minlength=ni)
  for row in lab['rows']:
   user=row['user'];ui=self.um.get(user)
   for method in m.METHODS:
    weights=self.w[method]
    if ui is None or method in ['implicit_als','bpr'] and user not in positive:s=counts
    elif method=='fm':s=w['bias']+w['linear'][ui]+item_terms+z@w['v'][ui]
    else:
     s=weights['q']@weights['p'][ui]
     if method=='explicit_als':s=s+weights['mean']+weights['bu'][ui]+weights['bi']
    order=sorted((j for j,item in enumerate(ids) if item not in hist.get(user,set())),key=lambda j:(-round(float(s[j]),12),int(ids[j])))[:10];actual=[int(ids[j]) for j in order];self.assertEqual(actual,row['rankings'][method])
    for case in lab['samples']:
     if user==case['user']:
      self.assertEqual([i for i,s in case['top'][method]],actual)
      for item,score in case['top'][method]:self.assertAlmostEqual(score,s[self.im[item]])
 def test_07_independent_metrics_cohorts_raw_rating_policies_and_canonical_hash(self):
  for method in [*m.METHODS,'popularity','user_cf']:
   for scope in ['warm','all']:
    rows=[r for r in lab['rows'] if r['train_count'] and r['eligible']] if scope=='warm' else [r for r in lab['rows'] if r['positive']];metrics=[];union=set()
    for row in rows:
     ranked=row['rankings'][method];gold=set(row['eligible' if scope=='warm' else 'positive']);hit=len(set(ranked)&gold);dcg=sum(1/math.log2(j+2) for j,i in enumerate(ranked) if i in gold);ideal=sum(1/math.log2(j+2) for j in range(min(10,len(gold))));metrics.append([hit/10,hit/len(gold),dcg/ideal]);union.update(ranked)
    ref=lab['scorecards'][method][scope];self.assertEqual(ref['users'],len(rows));np.testing.assert_allclose(np.mean(metrics,0),[ref[k] for k in ['precision','recall','ndcg']],atol=1e-12);self.assertAlmostEqual(ref['catalog_coverage'],len(union)/len(self.im))
  _,movies=self.old.load();feature_rows=m.feature_rows(np.array(lab['users']),np.array(lab['items']),lab['genres'],movies)
  for method in ['explicit_als','fm']:
   errors=[];warm=[];w=self.w[method]
   for user,item,r,t in base['future']:
    u=self.um.get(user);i=self.im.get(item)
    if method=='explicit_als':pred=w['mean']+(w['bu'][u] if u is not None else 0)+(w['bi'][i] if i is not None else 0)+(w['p'][u]@w['q'][i] if u is not None and i is not None else 0)
    elif u is None or i is None:pred=float(self.r.mean())
    else:pred=m.fm_score(w,*m.fm_active(u,i,feature_rows))
    error=(r-pred)**2;errors.append(error)
    if u is not None and i is not None:warm.append(error)
   ref=lab['report']['rating_metrics'][method];self.assertEqual(ref['warm_known_count'],len(warm));self.assertAlmostEqual(ref['all_rmse'],np.sqrt(np.mean(errors)));self.assertAlmostEqual(ref['warm_known_rmse'],np.sqrt(np.mean(warm)))
  self.assertEqual(hashlib.sha256(json.dumps(lab['weights'],sort_keys=True,separators=(',',':')).encode()).hexdigest(),lab['report']['weights_sha256'])
 def test_08_full_retrain_exact_rng_restoration_external_cwd_export_preservation(self):
  state=torch.random.get_rng_state().clone();threads=torch.get_num_threads();self.assertEqual(m.analyse(),lab);self.assertTrue(torch.equal(state,torch.random.get_rng_state()));self.assertEqual(threads,torch.get_num_threads());before={p.name:m.digest(p) for p in DATA.iterdir() if p.is_file()}
  with tempfile.TemporaryDirectory() as td:
   out=Path(td)/'export';subprocess.run([sys.executable,str(DATA/'factor_workflow.py'),'--artifact-dir',str(out)],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True);self.assertEqual(json.loads((out/'factor_lab.json').read_text()),lab);self.assertEqual(json.loads((out/'checksums.json').read_text())['factor_lab.json'],m.digest(out/'factor_lab.json'))
  self.assertEqual(before,{p.name:m.digest(p) for p in DATA.iterdir() if p.is_file()})
if __name__=='__main__':
 os.chdir(ROOT);torch.set_num_threads(1);snippets=0
 for lesson in chapter['lessons']:
  for block in lesson['blocks']:
   if block['type']=='code':
    with contextlib.redirect_stdout(io.StringIO()):exec(compile(block['body'],lesson['id'],'exec'),{})
    snippets+=1
 for e in chapter['exercises']:
  scope={}
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(e['solution'],e['id'],'exec'),scope)
  assert abs(scope['result']-e['expected'])<1e-9,e['id']
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA));assert result.wasSuccessful();report=dict(chapter=31,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,passed=True);(ROOT/'build/chapter-31-code-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
