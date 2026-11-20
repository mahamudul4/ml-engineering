"""Chapter31: deterministic CPU explicit/implicit ALS, BPR and regression FM.

Original MovieLens source and fixed Chapter30 roles are reused. No network.
Default CLI prints results; --write-lab regenerates derived factor_lab.json;
--artifact-dir exports complete weights/diagnostics/checksums. Not resume state.
"""
from pathlib import Path
import argparse,hashlib,importlib.util,json
import numpy as np
import torch
from torch import nn
DATA=Path(__file__).resolve().parent
RANK=8
METHODS=('explicit_als','implicit_als','bpr','fm')
def source():
 spec=importlib.util.spec_from_file_location('rec31source',DATA/'recommendation_workflow.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def explicit_objective(p,q,bu,bi,u,i,r,mu,reg):return float(np.square(r-mu-bu[u]-bi[i]-(p[u]*q[i]).sum(1)).sum()+reg*(np.square(p).sum()+np.square(q).sum()+np.square(bu).sum()+np.square(bi).sum()))
def normal_equation(q,bi,items,ratings,mu,reg):
 x=np.column_stack([np.ones(len(items)),q[items]]);target=ratings-mu-bi[items]
 return x.T@x+reg*np.eye(q.shape[1]+1),x.T@target
def explicit_als(u,i,r,nu,ni,mu):
 rng=np.random.default_rng(31);p=rng.normal(0,.05,(nu,RANK));q=rng.normal(0,.05,(ni,RANK));bu=np.zeros(nu);bi=np.zeros(ni);reg=10.;trace=[]
 byuser=[np.flatnonzero(u==j) for j in range(nu)];byitem=[np.flatnonzero(i==j) for j in range(ni)]
 for epoch in range(17):
  trace.append(explicit_objective(p,q,bu,bi,u,i,r,mu,reg))
  if epoch==16:break
  for j,rows in enumerate(byuser):
   a,b=normal_equation(q,bi,i[rows],r[rows],mu,reg);w=np.linalg.solve(a,b);bu[j]=w[0];p[j]=w[1:]
  for j,rows in enumerate(byitem):
   a,b=normal_equation(p,bu,u[rows],r[rows],mu,reg);w=np.linalg.solve(a,b);bi[j]=w[0];q[j]=w[1:]
 return dict(p=p.tolist(),q=q.tolist(),bu=bu.tolist(),bi=bi.tolist(),mean=mu,reg=reg,trace=trace,epochs=16)
def implicit_objective(p,q,pu,pi,alpha,reg):
 pred=(p[pu]*q[pi]).sum(1);all_square=np.sum((p.T@p)*(q.T@q))
 return float(all_square+np.sum(alpha*pred**2-2*(1+alpha)*pred+(1+alpha))+reg*(np.square(p).sum()+np.square(q).sum()))
def implicit_als(pu,pi,nu,ni):
 rng=np.random.default_rng(310);p=rng.normal(0,.05,(nu,RANK));q=rng.normal(0,.05,(ni,RANK));alpha=20.;reg=.1;trace=[]
 byuser=[pi[pu==j] for j in range(nu)];byitem=[pu[pi==j] for j in range(ni)]
 for epoch in range(13):
  trace.append(implicit_objective(p,q,pu,pi,alpha,reg))
  if epoch==12:break
  for target,other,groups in [(p,q,byuser),(q,p,byitem)]:
   gram=other.T@other
   for j,ids in enumerate(groups):
    liked=other[ids];a=gram+alpha*(liked.T@liked)+reg*np.eye(RANK);b=(1+alpha)*liked.sum(0);target[j]=np.linalg.solve(a,b)
 return dict(p=p.tolist(),q=q.tolist(),alpha=alpha,reg=reg,trace=trace,epochs=12)
class BPR(nn.Module):
 def __init__(self,nu,ni):
  super().__init__();self.p=nn.Parameter(torch.randn(nu,RANK,dtype=torch.float64)*.05);self.q=nn.Parameter(torch.randn(ni,RANK,dtype=torch.float64)*.05)
 def forward(self,u,i):return (self.p[u]*self.q[i]).sum(-1)
class FM(nn.Module):
 def __init__(self,nf,mean):
  super().__init__();self.bias=nn.Parameter(torch.tensor(mean,dtype=torch.float64));self.linear=nn.Parameter(torch.zeros(nf,dtype=torch.float64));self.v=nn.Parameter(torch.randn(nf,RANK,dtype=torch.float64)*.02)
 def forward(self,ids,x):
  vx=self.v[ids]*x[...,None];return self.bias+(self.linear[ids]*x).sum(-1)+.5*((vx.sum(1)**2).sum(-1)-(vx**2).sum((1,2)))
def feature_rows(users,items,genres,movies):
 # Features: user one-hot, item one-hot, normalized movie genre indicators.
 nu=len(users);ni=len(items);genre={g:j for j,g in enumerate(genres)};rows=[]
 for j,item in enumerate(items):
  gs=movies[int(item)]['genres'];rows.append(([nu+j]+[nu+ni+genre[g] for g in gs],[1.]+[1/np.sqrt(len(gs)) for g in gs]))
 return rows
def fm_active(user_index,item_index,rows):
 ids,x=rows[item_index];return [user_index]+ids,[1.]+x
def train_bpr(pu,pi,nu,ni,seen):
 torch.manual_seed(3101);model=BPR(nu,ni);rng=np.random.default_rng(3101);optimizer=torch.optim.Adam(model.parameters(),lr=.01);trace=[];first=None
 allowed=[np.array(sorted(set(range(ni))-s),dtype=int) for s in seen]
 for epoch in range(25):
  negatives=np.array([allowed[u][rng.integers(len(allowed[u]))] for u in pu]);order=rng.permutation(len(pu));total=0.;count=0
  if first is None:first=[int(pu[0]),int(pi[0]),int(negatives[0])]
  for batch in np.array_split(order,int(np.ceil(len(order)/1024))):
   u=torch.as_tensor(pu[batch]);i=torch.as_tensor(pi[batch]);j=torch.as_tensor(negatives[batch]);optimizer.zero_grad();margin=model(u,i)-model(u,j);data=nn.functional.softplus(-margin).mean();penalty=.0005*((model.p[u]**2).sum(1)+(model.q[i]**2).sum(1)+(model.q[j]**2).sum(1)).mean();loss=data+penalty;loss.backward();optimizer.step();total+=data.item()*len(batch);count+=len(batch)
  trace.append(total/count)
 return dict(p=model.p.detach().tolist(),q=model.q.detach().tolist(),epochs=25,trace=trace,first_triplet=first,reg=.001,learning_rate=.01,batch_size=1024),model
def train_fm(u,i,r,users,items,genres,movies,mean):
 torch.manual_seed(3102);rows=feature_rows(users,items,genres,movies);nf=len(users)+len(items)+len(genres);model=FM(nf,mean);rng=np.random.default_rng(3102);optimizer=torch.optim.Adam(model.parameters(),lr=.01)
 active=[fm_active(int(uu),int(ii),rows) for uu,ii in zip(u,i)];width=max(len(ids) for ids,x in active);indices=np.zeros((len(u),width),dtype=np.int64);values=np.zeros((len(u),width))
 for j,(ids,x) in enumerate(active):indices[j,:len(ids)]=ids;values[j,:len(x)]=x
 indices=torch.as_tensor(indices);values=torch.as_tensor(values);targets=torch.as_tensor(r);trace=[]
 for epoch in range(20):
  order=rng.permutation(len(u));total=0.
  for batch in np.array_split(order,int(np.ceil(len(order)/1024))):
   ids=indices[batch];x=values[batch];optimizer.zero_grad();pred=model(ids,x);data=((pred-targets[batch])**2).mean();penalty=.001*((model.v[ids]**2).sum(-1)*x.square()).sum(1).mean()+.0001*(model.linear[ids].square()*x.square()).sum(1).mean();loss=data+penalty;loss.backward();optimizer.step();total+=data.item()*len(batch)
  trace.append(total/len(u))
 return dict(bias=model.bias.item(),linear=model.linear.detach().tolist(),v=model.v.detach().tolist(),epochs=20,trace=trace,learning_rate=.01,batch_size=1024,reg_v=.001,reg_linear=.0001),model,rows
def fm_score(w,ids,x):
 v=np.asarray(w['v'])[ids]*np.array(x)[:,None];return float(w['bias']+np.dot(np.asarray(w['linear'])[ids],x)+.5*(np.square(v.sum(0)).sum()-np.square(v).sum()))
def scores(weights,method,u,users,items,feature_rows_,positive_users,pop):
 if u not in users or method in ('implicit_als','bpr') and u not in positive_users:return pop.copy()
 index=users[u];w=weights[method]
 if method=='fm':
  width=max(len(ids) for ids,x in feature_rows_);ids=np.zeros((len(items),width),dtype=int);x=np.zeros((len(items),width))
  for j,(ii,xx) in enumerate(feature_rows_):ids[j,:len(ii)]=ii;x[j,:len(xx)]=xx
  v=np.asarray(w['v']);linear=np.asarray(w['linear']);vx=v[ids]*x[...,None];z=vx.sum(1)
  return w['bias']+linear[index]+(linear[ids]*x).sum(1)+.5*(np.square(z).sum(1)-np.square(vx).sum((1,2)))+z@v[index]
 raw=np.asarray(w['q'])@np.asarray(w['p'])[index]
 return raw+w['mean']+w['bu'][index]+np.array(w['bi']) if method=='explicit_als' else raw
def analyse():
 old=source();base=json.loads((DATA/'recommendation_lab.json').read_text(encoding='utf-8'));train=np.array(base['train']);movies=old.load()[1];users=np.unique(train[:,0]).astype(int);items=np.unique(train[:,1]).astype(int);um={int(v):j for j,v in enumerate(users)};im={int(v):j for j,v in enumerate(items)};u=np.array([um[int(x)] for x in train[:,0]]);i=np.array([im[int(x)] for x in train[:,1]]);r=train[:,2];positive=r>=4;pu=u[positive];pi=i[positive];mu=float(r.mean());seen=[set(i[u==j]) for j in range(len(users))]
 prior_threads=torch.get_num_threads()
 with torch.random.fork_rng(devices=[]):
  try:
   torch.set_num_threads(1);explicit=explicit_als(u,i,r,len(users),len(items),mu);implicit=implicit_als(pu,pi,len(users),len(items));bpr,bpr_model=train_bpr(pu,pi,len(users),len(items),seen);fm,fm_model,features=train_fm(u,i,r,users,items,base['genres'],movies,mu)
  finally:torch.set_num_threads(prior_threads)
 weights=dict(explicit_als=explicit,implicit_als=implicit,bpr=bpr,fm=fm)
 counts=np.bincount(pi,minlength=len(items));pop=counts.astype(float);pos_users=set(int(users[j]) for j in set(pu));rows=[];samples=[]
 for original in base['rows']:
  row={k:v for k,v in original.items() if k!='rankings'};uid=row['user'];history={int(items[j]) for j in seen[um[uid]]} if uid in um else set();row['rankings']={method:old.top(scores(weights,method,uid,um,items,features,pos_users,pop),items,history) for method in METHODS};row['rankings']['popularity']=original['rankings']['popularity'];row['rankings']['user_cf']=original['rankings']['user_cf'];rows.append(row)
 for c in base['samples']:
  uid=c['user'];samples.append(dict(user=uid,top={method:[[item,float(s[im[item]])] for item in old.top(s,items,dict(c['history']))] for method in METHODS for s in [scores(weights,method,uid,um,items,features,pos_users,pop)]}))
 future=np.array(base['future']);rating_metrics={};fm_numeric=dict(bias=fm['bias'],linear=np.asarray(fm['linear']),v=np.asarray(fm['v']))
 for method in ['explicit_als','fm']:
  predictions=[];warm_errors=[]
  for uid,item,target,t in future:
   uid=int(uid);item=int(item);ui=um.get(uid);ii=im.get(item)
   if method=='explicit_als':prediction=mu+(explicit['bu'][ui] if ui is not None else 0)+(explicit['bi'][ii] if ii is not None else 0)+(float(np.dot(explicit['p'][ui],explicit['q'][ii])) if ui is not None and ii is not None else 0)
   else:prediction=fm_score(fm_numeric,*fm_active(ui,ii,features)) if ui is not None and ii is not None else mu
   error=(prediction-target)**2;predictions.append(error)
   if ui is not None and ii is not None:warm_errors.append(error)
  rating_metrics[method]=dict(all_rmse=float(np.sqrt(np.mean(predictions))),warm_known_rmse=float(np.sqrt(np.mean(warm_errors))),warm_known_count=len(warm_errors),all_count=len(predictions))
 audit_user=base['samples'][0]['user'];au=um[audit_user];rr=np.flatnonzero(u==au);a,b=normal_equation(np.array(explicit['q']),np.array(explicit['bi']),i[rr],r[rr],mu,10.);solution=np.linalg.solve(a,b);triplet=bpr['first_triplet'];tu,ti,tj=triplet;margin=float((bpr_model(torch.tensor([tu]),torch.tensor([ti]))-bpr_model(torch.tensor([tu]),torch.tensor([tj]))).detach()[0]);fu=um[audit_user];fi=im[samples[0]['top']['fm'][0][0]];active,x=fm_active(fu,fi,features)
 report=dict(rank=RANK,source_lab_sha256=digest(DATA/'recommendation_lab.json'),source_hashes=base['report']['source_hashes'],fit_count=len(train),diagnostic_count=len(future),fit_users=len(users),fit_items=len(items),positive_count=int(positive.sum()),cutoff_timestamp=base['report']['cutoff_timestamp'],rating_metrics=rating_metrics,baseline_bayesian_rmse=base['report']['bayesian_rmse'],weights_sha256=hashlib.sha256(json.dumps(weights,sort_keys=True,separators=(',',':')).encode()).hexdigest(),protocol='Same Chapter30 global cutoff,fit catalog,all-seen filtering,28warm eligible/116broad users;inspected diagnostics,not blind confirmation. Fixed rank8 and final epochs,one seed per model,no tuning. Metadata full2018 snapshot not historically versioned. Binary rating>=4 is authored preference,not click logs. BPR uniform unobserved-fit negatives exclude every observed rating,not future positives;one draw per positive per epoch. No exposure correction or measured online/serving benefit. Content cold generalization not evaluated:catalog fit-known only. Ranking cold user -> popularity;implicit/BPR no-positive fit user -> popularity. Explicit RMSE cold retains learned available bias,zero latent;FM RMSE any unknown user/item -> fit global mean;raw unclipped scores.')
 return dict(report=report,users=users.tolist(),items=items.tolist(),genres=base['genres'],weights=weights,samples=samples,rows=rows,scorecards={method:{scope:old.scorecard(rows,method,warm_only=scope=='warm',catalog_size=len(items)) for scope in ['warm','all']} for method in [*METHODS,'popularity','user_cf']},als_audit=dict(user=audit_user,a=a.tolist(),b=b.tolist(),solution=solution.tolist(),items=[int(items[j]) for j in i[rr]],ratings=r[rr].tolist()),pair_audit=dict(user=int(users[tu]),positive=int(items[ti]),unobserved=int(items[tj]),margin=margin,loss=float(np.logaddexp(0,-margin)),derivative=float(-1/(1+np.exp(margin)))),fm_audit=dict(user=audit_user,item=int(items[fi]),indices=active,values=x,score=fm_score(fm,active,x)))
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--write-lab',action='store_true');parser.add_argument('--artifact-dir',type=Path);args=parser.parse_args();lab=analyse();payload=json.dumps(lab,ensure_ascii=False,separators=(',',':'))+'\n'
 if args.write_lab:(DATA/'factor_lab.json').write_text(payload,encoding='utf-8')
 if args.artifact_dir:
  args.artifact_dir.mkdir(parents=True,exist_ok=True);(args.artifact_dir/'factor_lab.json').write_text(payload,encoding='utf-8');(args.artifact_dir/'checksums.json').write_text(json.dumps({'factor_lab.json':digest(args.artifact_dir/'factor_lab.json')},indent=2)+'\n')
 print(json.dumps(dict(report=lab['report'],scorecards=lab['scorecards']),indent=2))
if __name__=='__main__':main()
