"""Chapter32 snippets and independent source,forward,gradient,pipeline QA."""
from pathlib import Path
import contextlib,hashlib,importlib.util,io,json,math,os,subprocess,sys,tempfile,unittest
import numpy as np
import torch
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/movielens'
s=importlib.util.spec_from_file_location('deep32qa',DATA/'deep_recommendation_workflow.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
lab=json.loads((DATA/'deep_recommendation_lab.json').read_text());base=json.loads((DATA/'recommendation_lab.json').read_text(encoding='utf-8'));chapter=json.loads((ROOT/'assets/content/chapter_32.json').read_text(encoding='utf-8'))
class QA(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.um={u:j for j,u in enumerate(lab['users'])};cls.im={i:j for j,i in enumerate(lab['items'])};cls.raw=np.array(base['train']);cls.u=np.array([cls.um[int(u)]for u in cls.raw[:,0]]);cls.i=np.array([cls.im[int(i)]for i in cls.raw[:,1]]);cls.r=cls.raw[:,2];cls.role=np.array([int.from_bytes(hashlib.sha256(f'{int(u)}:{int(i)}'.encode()).digest()[:8],'big')%5!=0 for u,i,r,t in cls.raw]);cls.genres=np.array([[g in row[2]for g in base['genres']]for row in base['movies']],dtype=float);cls.genres/=np.maximum(np.linalg.norm(cls.genres,axis=1,keepdims=True),1e-12)
  cls.hist={u:{}for u in cls.um};cls.likes=np.zeros((len(cls.um),len(cls.im)),dtype=bool);cls.uc=np.zeros(len(cls.um));cls.ic=np.zeros(len(cls.im));cls.ip=np.zeros(len(cls.im));cls.sums=np.zeros(len(cls.im))
  for j,(u,i,r,t)in enumerate(cls.raw):
   cls.hist[int(u)][int(i)]=r
   if cls.role[j]:
    ui=cls.um[int(u)];ii=cls.im[int(i)];cls.uc[ui]+=1;cls.ic[ii]+=1;cls.sums[ii]+=r
    if r>=4:cls.likes[ui,ii]=True;cls.ip[ii]+=1
  cls.mu=cls.r[cls.role].mean();cls.bayes=(cls.sums+20*cls.mu)/(cls.ic+20);cls.profiles=cls.likes.astype(float)@cls.genres;cls.profiles/=np.maximum(np.linalg.norm(cls.profiles,axis=1,keepdims=True),1e-12)
  cls.q=np.array(lab['query_vectors']);cls.v=np.array(lab['item_vectors']);cls.rw={k:np.array(v)for k,v in lab['ranker'].items()};cls.mean=np.array(lab['ranker_settings']['feature_mean']);cls.std=np.array(lab['ranker_settings']['feature_std'])
 @classmethod
 def features(cls,u,i):return np.array([np.dot(cls.q[u],cls.v[i]),np.log1p(cls.uc[u]),np.log1p(cls.ip[i]),cls.bayes[i],np.dot(cls.profiles[u],cls.genres[i])])
 @classmethod
 def rank(cls,x):
  z=(x-cls.mean)/cls.std;return np.maximum(0,z@cls.rw['net.0.weight'].T+cls.rw['net.0.bias'])@cls.rw['net.2.weight'][0]+cls.rw['net.2.bias'][0]
 def test_01_original_sources_hash_partition_disjoint_roles_and_frozen_baselines(self):
  for name,h in lab['report']['source_hashes'].items():self.assertEqual(m.digest(DATA/name),h)
  self.assertEqual(m.digest(DATA/'recommendation_lab.json'),lab['report']['source_lab_sha256']);raw,_=m.source().load();cut=lab['report']['cutoff_timestamp'];self.assertEqual(raw[raw[:,3]<=cut].tolist(),base['train']);self.assertEqual(raw[raw[:,3]>cut].tolist(),base['future']);self.assertEqual(np.flatnonzero(self.role).tolist(),lab['retrieval_indices']);self.assertEqual(np.flatnonzero(~self.role).tolist(),lab['ranking_indices']);self.assertEqual(self.role.sum(),64411);self.assertEqual(sum(self.role&(self.r>=4)),31330)
  for row,orig in zip(lab['rows'],base['rows']):
   for key in ['user','train_count','positive','eligible']:self.assertEqual(row[key],orig[key])
   for name in ['popularity','user_cf']:self.assertEqual(row['rankings'][name],orig['rankings'][name])
 def test_02_independent_all8389_tower_vectors_and_torch_parity(self):
  w={k:np.array(v)for k,v in lab['tower'].items()}
  for side,ref in [('user',self.q),('item',self.v)]:
   x=w[side+'_embedding.weight'];x=x if side=='user'else np.c_[x,self.genres];h=x@w[side+'_net.0.weight'].T+w[side+'_net.0.bias'];h[h<0]=0;z=h@w[side+'_net.2.weight'].T+w[side+'_net.2.bias'];z/=np.maximum(np.linalg.norm(z,axis=1,keepdims=True),1e-12);np.testing.assert_allclose(z,ref,atol=1e-12);np.testing.assert_allclose(np.linalg.norm(ref,axis=1),1,atol=1e-12)
  model=m.TwoTower(522,7867,19);model.load_state_dict({k:torch.tensor(v,dtype=torch.float64)for k,v in lab['tower'].items()})
  with torch.no_grad():np.testing.assert_allclose(model.query(torch.arange(522)),self.q,atol=1e-12);np.testing.assert_allclose(model.item(torch.arange(7867),torch.tensor(self.genres)),self.v,atol=1e-12)
  self.assertEqual(sum(p.numel()for p in model.parameters()),135344)
 def test_03_exact_first_sampler_batch_masks_loss_and_independent_gradient(self):
  positive=self.role&(self.r>=4);uu=self.u[positive];ii=self.i[positive];order=np.random.default_rng(3200).permutation(len(uu));batch=order[:256];uniform=np.random.default_rng(3201).integers(7867,size=64);c=np.unique(np.r_[ii[batch],uniform]);b=lab['first_batch'];self.assertEqual([lab['users'][j]for j in uu[batch]],b['users']);self.assertEqual([lab['items'][j]for j in ii[batch]],b['targets']);self.assertEqual([lab['items'][j]for j in c],b['candidates']);self.assertEqual([lab['items'][j]for j in uniform],b['uniform']);mask=self.likes[uu[batch]][:,c];self.assertEqual([np.flatnonzero(r).tolist()for r in mask],b['positive_columns']);self.assertTrue(np.any(mask.sum(1)>1));z=self.q[uu[batch]]@self.v[c].T/.2;logp=z-np.logaddexp.reduce(z,axis=1)[:,None];target=mask/mask.sum(1,keepdims=True);loss=-(target*logp).sum(1);np.testing.assert_allclose(loss,b['loss'],atol=1e-12);self.assertAlmostEqual(loss.mean(),b['mean_loss'])
  query=torch.tensor(self.q[uu[batch[0]]],requires_grad=True);v=torch.tensor(self.v[c]);logits=query@v.T/.2;ce=-(torch.log_softmax(logits,0)*torch.tensor(target[0])).sum();ce.backward();p=np.exp(z[0]-np.logaddexp.reduce(z[0]));analytic=(p-target[0])@self.v[c]/.2;np.testing.assert_allclose(query.grad,analytic,atol=1e-12)
  eps=1e-6;fn=lambda x:np.logaddexp.reduce(x@self.v[c].T/.2)-np.mean((x@self.v[c].T/.2)[mask[0]]);numeric=np.array([(fn(query.detach().numpy()+eps*np.eye(8)[j])-fn(query.detach().numpy()-eps*np.eye(8)[j]))/(2*eps)for j in range(8)]);np.testing.assert_allclose(analytic,numeric,atol=1e-7)
 def test_04_all_ranker_features_scaler_real_logits_gradient_and_label_boundary(self):
  x=np.array([self.features(u,i)for u,i in zip(self.u[~self.role],self.i[~self.role])]);np.testing.assert_allclose(x.mean(0),self.mean,atol=1e-12);np.testing.assert_allclose(x.std(0),self.std,atol=1e-12);self.assertEqual(int((self.r[~self.role]>=4).sum()),7924)
  for sample in lab['samples']:
   for ref in sample['scores']:
    f=self.features(self.um[sample['user']],self.im[ref['item']]);np.testing.assert_allclose(f,ref['features'],atol=1e-12);np.testing.assert_allclose((f-self.mean)/self.std,ref['standardized'],atol=1e-12);self.assertAlmostEqual(float(self.rank(f)),ref['logit'])
  z=torch.tensor((x[0]-self.mean)/self.std,requires_grad=True);w=self.rw;w1=torch.tensor(w['net.0.weight']);b1=torch.tensor(w['net.0.bias']);w2=torch.tensor(w['net.2.weight'][0]);pre=w1@z+b1;logit=w2@pre.relu()+float(w['net.2.bias'][0]);y=torch.tensor(float(self.r[~self.role][0]>=4));loss=torch.nn.functional.binary_cross_entropy_with_logits(logit,y);loss.backward();analytic=w1.T@((torch.sigmoid(logit.detach())-y)*w2*(pre.detach()>0));np.testing.assert_allclose(z.grad,analytic,atol=1e-12)
  eps=1e-6;fn=lambda v:np.logaddexp(0,self.rank(v))-float(y)*self.rank(v);raw_gradient=np.array([(fn(x[0]+eps*np.eye(5)[j])-fn(x[0]-eps*np.eye(5)[j]))/(2*eps)for j in range(5)]);np.testing.assert_allclose(raw_gradient,analytic.numpy()/self.std,atol=1e-6)
 def test_05_all464_independent_exact_candidate_unions_ranked_lists_and_cold_policy(self):
  ids=lab['items'];pop=np.zeros(len(ids))
  for u,i,r,t in base['train']:
   if r>=4:pop[self.im[i]]+=1
  for row in lab['rows']:
   user=row['user'];ui=self.um.get(user);seen=self.hist.get(user,{});available=[j for j,i in enumerate(ids)if i not in seen];cold=ui is None or not self.likes[ui].any();po=sorted(available,key=lambda j:(-pop[j],ids[j]));dot=self.v@self.q[ui]if not cold else pop;neural=sorted(available,key=lambda j:(-round(float(dot[j]),12),ids[j]))
   for config,(budget,hybrid)in m.CONFIGS.items():
    candidates=(po if cold else neural)[:budget]
    if hybrid and not cold:candidates+= [j for j in po[:budget]if j not in candidates]
    if cold:ranked=candidates[:10]
    else:
     features=np.array([self.features(ui,j)for j in candidates]);scores=self.rank(features);ranked=[candidates[j]for j in sorted(range(len(candidates)),key=lambda j:(-round(float(scores[j]),12),ids[candidates[j]]))[:10]]
    ref=row['pipelines'][config];self.assertEqual(ref['fallback'],cold);self.assertEqual(ref['candidates'],[ids[j]for j in candidates]);self.assertEqual(ref['ranked'],[ids[j]for j in ranked]);self.assertEqual(ref['ranked'],row['rankings'][config]);self.assertTrue(not set(ref['candidates'])&set(seen))
 def test_06_independent_both_cohorts_metrics_candidate_oracle_bounds_and_actual_tradeoff(self):
  for config in [*m.CONFIGS,'popularity','user_cf']:
   for scope in ['warm','all']:
    cohort=[r for r in lab['rows']if r['train_count']and r['eligible']]if scope=='warm'else[r for r in lab['rows']if r['positive']];values=[];union=set();candidate=[]
    for row in cohort:
     gold=set(row['eligible'if scope=='warm'else'positive']);ranked=row['rankings'][config];hits=len(set(ranked)&gold);dcg=sum(1/math.log2(j+2)for j,i in enumerate(ranked)if i in gold);ideal=sum(1/math.log2(j+2)for j in range(min(10,len(gold))));values.append([hits/10,hits/len(gold),dcg/ideal]);union.update(ranked)
     if config in m.CONFIGS:
      c=row['pipelines'][config]['candidates'];h=len(set(c)&gold);candidate.append([h/len(gold),min(10,h)/len(gold),len(c)]);self.assertLessEqual(hits,min(10,h))
    ref=lab['scorecards'][config][scope];self.assertEqual(ref['users'],len(cohort));np.testing.assert_allclose(np.mean(values,0),[ref[k]for k in ['precision','recall','ndcg']],atol=1e-12);self.assertAlmostEqual(ref['catalog_coverage'],len(union)/7867)
    if candidate:np.testing.assert_allclose(np.mean(candidate,0),[ref[k]for k in ['candidate_recall','oracle_recall10','mean_candidates']],atol=1e-12)
  self.assertGreater(lab['scorecards']['neural100']['warm']['candidate_recall'],lab['scorecards']['neural50']['warm']['candidate_recall']);self.assertLess(lab['scorecards']['neural100']['warm']['recall'],lab['scorecards']['neural50']['warm']['recall'])
 def test_07_full_retraining_exact_torch_rng_thread_restoration(self):
  before=torch.random.get_rng_state().clone();threads=torch.get_num_threads();actual=m.analyse();self.assertEqual(actual,lab);self.assertTrue(torch.equal(before,torch.random.get_rng_state()));self.assertEqual(threads,torch.get_num_threads())
 def test_08_external_cwd_export_checksums_and_source_asset_preservation(self):
  before={p.name:m.digest(p)for p in DATA.iterdir()if p.is_file()}
  with tempfile.TemporaryDirectory()as td:
   out=Path(td)/'artifacts';subprocess.run([sys.executable,str(DATA/'deep_recommendation_workflow.py'),'--artifact-dir',str(out)],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True);self.assertEqual(json.loads((out/'deep_recommendation_lab.json').read_text()),lab);self.assertEqual(json.loads((out/'checksums.json').read_text())['deep_recommendation_lab.json'],m.digest(out/'deep_recommendation_lab.json'))
  self.assertEqual(before,{p.name:m.digest(p)for p in DATA.iterdir()if p.is_file()})
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
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA));assert result.wasSuccessful();report=dict(chapter=32,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,passed=True);(ROOT/'build/chapter-32-code-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
