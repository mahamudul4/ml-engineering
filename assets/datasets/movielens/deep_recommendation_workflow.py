"""Chapter32: offline CPU two-tower retrieval -> observed-preference MLP ranking.

Same pinned MovieLens outer roles; disjoint hashed pre-cutoff labels for towers
and ranker. No network, GPU or external model required. Default run preserves
assets. --write-lab explicitly regenerates; --artifact-dir exports JSON/checksum.
"""
from pathlib import Path
import argparse,hashlib,importlib.util,json,math
import numpy as np
import torch
from torch import nn
DATA=Path(__file__).resolve().parent
CONFIGS={'neural20':(20,False),'neural50':(50,False),'neural100':(100,False),'hybrid50':(50,True)}
FEATURES=['tower_dot','log_user_observations','log_item_positives','shrunk_item_mean','genre_affinity']
def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def source():
 s=importlib.util.spec_from_file_location('deep32source',DATA/'recommendation_workflow.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def role(user,item):return int.from_bytes(hashlib.sha256(f'{user}:{item}'.encode('ascii')).digest()[:8],'big')%5
def normalize(x):
 n=np.linalg.norm(x,axis=-1,keepdims=True);return x/np.maximum(n,1e-12)
class TwoTower(nn.Module):
 def __init__(self,nu,ni,ng):
  super().__init__();self.user_embedding=nn.Embedding(nu,16,dtype=torch.float64);self.item_embedding=nn.Embedding(ni,16,dtype=torch.float64);nn.init.normal_(self.user_embedding.weight,0,.05);nn.init.normal_(self.item_embedding.weight,0,.05)
  self.user_net=nn.Sequential(nn.Linear(16,16,dtype=torch.float64),nn.ReLU(),nn.Linear(16,8,dtype=torch.float64));self.item_net=nn.Sequential(nn.Linear(16+ng,16,dtype=torch.float64),nn.ReLU(),nn.Linear(16,8,dtype=torch.float64))
 def query(self,u):return nn.functional.normalize(self.user_net(self.user_embedding(u)),dim=-1,eps=1e-12)
 def item(self,i,g):return nn.functional.normalize(self.item_net(torch.cat([self.item_embedding(i),g],dim=-1)),dim=-1,eps=1e-12)
class Ranker(nn.Module):
 def __init__(self):super().__init__();self.net=nn.Sequential(nn.Linear(5,16,dtype=torch.float64),nn.ReLU(),nn.Linear(16,1,dtype=torch.float64))
 def forward(self,x):return self.net(x).squeeze(-1)
def batch_loss(q,c,mask,temperature=.2):
 logits=q@c.T/temperature;logp=nn.functional.log_softmax(logits,dim=1);target=mask.to(logp.dtype)/mask.sum(1,keepdim=True);return -(target*logp).sum(1)
def state(model):return {k:v.detach().tolist() for k,v in model.state_dict().items()}
def tower_numpy(w,indices,genres=None):
 name='user' if genres is None else 'item';embedding=np.asarray(w[name+'_embedding.weight'])[indices]
 x=embedding if genres is None else np.concatenate([embedding,genres],axis=-1);h=np.maximum(0,x@np.asarray(w[name+'_net.0.weight']).T+np.asarray(w[name+'_net.0.bias']));return normalize(h@np.asarray(w[name+'_net.2.weight']).T+np.asarray(w[name+'_net.2.bias']))
def rank_numpy(w,features):return np.maximum(0,features@np.asarray(w['net.0.weight']).T+np.asarray(w['net.0.bias']))@np.asarray(w['net.2.weight'])[0]+w['net.2.bias'][0]
def load_inputs():
 old=source();base=json.loads((DATA/'recommendation_lab.json').read_text(encoding='utf-8'));rows=np.array(base['train']);users=np.array(sorted(set(rows[:,0].astype(int))));items=np.array([r[0] for r in base['movies']]);um={int(u):j for j,u in enumerate(users)};im={int(i):j for j,i in enumerate(items)};u=np.array([um[int(v)] for v in rows[:,0]]);i=np.array([im[int(v)] for v in rows[:,1]]);rating=rows[:,2];retrieval=np.array([role(int(a),int(b))!=0 for a,b,r,t in rows]);g=np.array([[genre in gs for genre in base['genres']] for item,title,gs in base['movies']],dtype=float);g=normalize(g)
 return old,base,rows,users,items,um,im,u,i,rating,retrieval,g
def fit_stats(u,i,r,mask,genres,nu,ni):
 countu=np.bincount(u[mask],minlength=nu);counti=np.bincount(i[mask],minlength=ni);sumi=np.bincount(i[mask],weights=r[mask],minlength=ni);positive=mask&(r>=4);likes=np.zeros((nu,ni),dtype=bool);likes[u[positive],i[positive]]=True;pop=likes.sum(0);mean=float(r[mask].mean());bayes=(sumi+20*mean)/(counti+20);profiles=normalize(likes.astype(float)@genres)
 return dict(user_count=countu,item_count=counti,item_positive=pop,mean=mean,bayes=bayes,profiles=profiles,likes=likes)
def feature_matrix(u,i,q,v,g,stats):return np.column_stack([(q[u]*v[i]).sum(-1),np.log1p(stats['user_count'][u]),np.log1p(stats['item_positive'][i]),stats['bayes'][i],(stats['profiles'][u]*g[i]).sum(-1)])
def train_towers(u,i,positive,stats,g,nu,ni):
 torch.manual_seed(32);model=TwoTower(nu,ni,g.shape[1]);optimizer=torch.optim.AdamW(model.parameters(),lr=.003,weight_decay=.0001);shuffle=np.random.default_rng(3200);negatives=np.random.default_rng(3201);uu=u[positive];ii=i[positive];genre=torch.tensor(g);liked=torch.tensor(stats['likes']);trace=[];first=None;updates=0
 for epoch in range(25):
  order=shuffle.permutation(len(uu));total=0.
  for start in range(0,len(order),256):
   batch=order[start:start+256];bu=torch.tensor(uu[batch]);target=torch.tensor(ii[batch]);uniform=negatives.integers(ni,size=64);c=torch.unique(torch.cat([target,torch.tensor(uniform)]),sorted=True);mask=liked[bu][:,c]
   if first is None:first=dict(users=bu.tolist(),targets=target.tolist(),candidates=c.tolist(),uniform=uniform.tolist())
   optimizer.zero_grad();loss=batch_loss(model.query(bu),model.item(c,genre[c]),mask).mean();loss.backward();optimizer.step();total+=loss.item()*len(batch);updates+=1
  trace.append(total/len(uu))
 return model,dict(epochs=25,batch_size=256,uniform_draws_per_batch=64,temperature=.2,learning_rate=.003,weight_decay=.0001,updates=updates,positive_rows=len(uu),trace=trace,seed=32,shuffle_seed=3200,uniform_seed=3201),first
def train_ranker(features,labels):
 mean=features.mean(0);std=features.std(0);std=np.where(std>1e-12,std,1.);x=torch.tensor((features-mean)/std);y=torch.tensor(labels,dtype=torch.float64);torch.manual_seed(3202);model=Ranker();opt=torch.optim.AdamW(model.parameters(),lr=.003,weight_decay=.0001);rng=np.random.default_rng(3202);trace=[];updates=0
 for epoch in range(40):
  order=rng.permutation(len(y));total=0.
  for start in range(0,len(order),256):
   ids=order[start:start+256];opt.zero_grad();loss=nn.functional.binary_cross_entropy_with_logits(model(x[ids]),y[ids]);loss.backward();opt.step();total+=loss.item()*len(ids);updates+=1
  trace.append(total/len(y))
 return model,dict(epochs=40,batch_size=256,learning_rate=.003,weight_decay=.0001,seed=3202,updates=updates,rows=len(labels),positives=int(labels.sum()),feature_mean=mean.tolist(),feature_std=std.tolist(),trace=trace)
def pipeline(user,budget,hybrid,base,um,im,items,q,v,g,stats,rankw,rank_settings):
 history={i for u,i,r,t in base['train'] if u==user};available=np.array([j for j,item in enumerate(items) if int(item) not in history]);outerpop=np.zeros(len(items))
 # Full-fit popularity baseline is frozen from Chapter30, not a ranking feature.
 for uid,item,r,t in base['train']:
  if r>=4:outerpop[im[item]]+=1
 def ordered(scores,which):return sorted(which,key=lambda j:(-round(float(scores[j]),12),int(items[j])))
 cold=user not in um or not stats['likes'][um[user]].any()
 if cold:
  candidates=ordered(outerpop,available)[:budget];ranked=candidates[:10];return dict(candidates=[int(items[j]) for j in candidates],ranked=[int(items[j]) for j in ranked],fallback=True)
 ui=um[user];similarity=v@q[ui];neural=ordered(similarity,available)[:budget];candidates=list(neural)
 if hybrid:
  for j in ordered(outerpop,available)[:budget]:
   if j not in candidates:candidates.append(j)
 f=feature_matrix(np.full(len(candidates),ui),np.array(candidates),q,v,g,stats);z=(f-np.array(rank_settings['feature_mean']))/np.array(rank_settings['feature_std']);logits=rank_numpy(rankw,z);order=sorted(range(len(candidates)),key=lambda j:(-round(float(logits[j]),12),int(items[candidates[j]])));return dict(candidates=[int(items[j]) for j in candidates],ranked=[int(items[candidates[j]]) for j in order[:10]],fallback=False)
def analyse():
 old,base,raw,users,items,um,im,u,i,r,retrieval,g=load_inputs();stats=fit_stats(u,i,r,retrieval,g,len(users),len(items));threads=torch.get_num_threads()
 with torch.random.fork_rng(devices=[]):
  try:
   torch.set_num_threads(1);tower,tower_settings,first=train_towers(u,i,retrieval&(r>=4),stats,g,len(users),len(items))
   with torch.no_grad():q=tower.query(torch.arange(len(users))).numpy();v=tower.item(torch.arange(len(items)),torch.tensor(g)).numpy()
   features=feature_matrix(u[~retrieval],i[~retrieval],q,v,g,stats);ranker,rank_settings=train_ranker(features,r[~retrieval]>=4);weights=state(tower);rankw=state(ranker)
  finally:torch.set_num_threads(threads)
 rows=[]
 for original in base['rows']:
  uid=original['user'];row={k:val for k,val in original.items() if k!='rankings'};row['pipelines']={name:pipeline(uid,*config,base,um,im,items,q,v,g,stats,rankw,rank_settings) for name,config in CONFIGS.items()};row['rankings']={name:p['ranked'] for name,p in row['pipelines'].items()};row['rankings'].update({name:original['rankings'][name] for name in ['popularity','user_cf']});rows.append(row)
 summaries={name:{scope:old.scorecard(rows,name,warm_only=scope=='warm',catalog_size=len(items)) for scope in ['warm','all']} for name in [*CONFIGS,'popularity','user_cf']}
 for name in CONFIGS:
  for scope in ['warm','all']:
   cohort=[row for row in rows if row['train_count'] and row['eligible']] if scope=='warm' else [row for row in rows if row['positive']];recalls=[];oracle=[];counts=[]
   for row in cohort:
    gold=set(row['eligible' if scope=='warm' else 'positive']);c=row['pipelines'][name]['candidates'];hits=len(set(c)&gold);recalls.append(hits/len(gold));oracle.append(min(10,hits)/len(gold));counts.append(len(c))
   summaries[name][scope].update(candidate_recall=float(np.mean(recalls)),oracle_recall10=float(np.mean(oracle)),mean_candidates=float(np.mean(counts)))
 batch_users=np.array(first['users']);batch_candidates=np.array(first['candidates']);mask=stats['likes'][batch_users][:,batch_candidates];logits=q[batch_users]@v[batch_candidates].T/.2;logp=logits-np.logaddexp.reduce(logits,axis=1)[:,None];loss=-(logp*mask/mask.sum(1,keepdims=True)).sum(1)
 first=dict(users=[int(users[j]) for j in batch_users],targets=[int(items[j]) for j in first['targets']],candidates=[int(items[j]) for j in batch_candidates],uniform=[int(items[j]) for j in first['uniform']],positive_columns=[np.flatnonzero(row).tolist() for row in mask],loss=loss.tolist(),mean_loss=float(loss.mean()))
 samples=[]
 for case in base['samples']:
  uid=case['user'];row=next(row for row in rows if row['user']==uid);sample=dict(user=uid,cases=row['pipelines'],scores=[])
  if uid in um:
   for item in row['pipelines']['neural50']['candidates'][:5]:
    ii=im[item];f=feature_matrix(np.array([um[uid]]),np.array([ii]),q,v,g,stats)[0];z=(f-rank_settings['feature_mean'])/rank_settings['feature_std'];sample['scores'].append(dict(item=item,features=f.tolist(),standardized=z.tolist(),logit=float(rank_numpy(rankw,z[None,:])[0])))
  samples.append(sample)
 report=dict(source_lab_sha256=digest(DATA/'recommendation_lab.json'),source_hashes=base['report']['source_hashes'],fit_rows=len(raw),future_rows=len(base['future']),retrieval_rows=int(retrieval.sum()),ranking_rows=int((~retrieval).sum()),retrieval_positive_rows=int((retrieval&(r>=4)).sum()),cutoff_timestamp=base['report']['cutoff_timestamp'],feature_names=FEATURES,stats_mean=stats['mean'],tower_parameters=sum(p.numel() for p in tower.parameters()),ranker_parameters=sum(p.numel() for p in ranker.parameters()),cold_policy='No retrieval-positive history -> full-fit popularity;no fabricated user vector. Cold fallback does not neural-rerank. Genre metadata full2018 snapshot,not historically versioned.',protocol='Outer Chapter30 temporal split/catalog/gold/all-seen policy unchanged. Pre-cutoff user-item SHA256 first8bytes big-endian mod5:0 ranker labels,1-4 retrieval labels. Shared label-free outer catalog/genre schema. Retriever statistics/positive masks use retrieval role only. Ranker sees disjoint observed-rating>=4 labels,not exposure/clicks and not sampled negatives. No post-ranker retriever refit. Ranker features use frozen retrieval-role statistics;feature scaler fits ranker role only. In-batch unique candidate IDs plus64uniform catalog draws;known retrieval-role positives share target probability mass uniformly;no logQ correction/full-softmax-unbiased claim. Exact full-catalog scan,not ANN;no measured latency. Fixed final epochs/one seed,no tuning/CI/freshblind/online lift claim.')
 return dict(report=report,users=users.tolist(),items=items.tolist(),retrieval_indices=np.flatnonzero(retrieval).tolist(),ranking_indices=np.flatnonzero(~retrieval).tolist(),tower=weights,ranker=rankw,tower_settings=tower_settings,ranker_settings=rank_settings,query_vectors=q.tolist(),item_vectors=v.tolist(),first_batch=first,samples=samples,rows=rows,scorecards=summaries)
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--write-lab',action='store_true');parser.add_argument('--artifact-dir',type=Path);args=parser.parse_args();lab=analyse();payload=json.dumps(lab,separators=(',',':'))+'\n'
 if args.write_lab:(DATA/'deep_recommendation_lab.json').write_text(payload,encoding='utf-8')
 if args.artifact_dir:
  args.artifact_dir.mkdir(parents=True,exist_ok=True);(args.artifact_dir/'deep_recommendation_lab.json').write_text(payload);(args.artifact_dir/'checksums.json').write_text(json.dumps({'deep_recommendation_lab.json':digest(args.artifact_dir/'deep_recommendation_lab.json')},indent=2)+'\n')
 print(json.dumps(dict(report=lab['report'],tower_settings={k:v for k,v in lab['tower_settings'].items() if k!='trace'},ranker_settings={k:v for k,v in lab['ranker_settings'].items() if k!='trace'},scorecards=lab['scorecards']),indent=2))
if __name__=='__main__':main()
