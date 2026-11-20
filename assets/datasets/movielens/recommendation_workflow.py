"""Chapter 30: offline, deterministic MovieLens neighborhood recommendation.

Default run only prints a report. --write-lab explicitly derives the bundled lab;
--artifact-dir exports the complete experiment without modifying source assets.
Requires NumPy/SciPy (see tool/requirements-pytorch-qa.txt), no network or GPU.
"""
from pathlib import Path
import argparse,csv,gzip,hashlib,json,math
from datetime import datetime,timezone
import numpy as np
from scipy.sparse import csr_matrix

DATA=Path(__file__).resolve().parent
METHODS=('popularity','bayesian','content','user_cf')
def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def load():
 with gzip.open(DATA/'ratings.csv.gz','rt',encoding='utf-8',newline='') as f:
  ratings=np.array([[int(r['userId']),int(r['movieId']),float(r['rating']),int(r['timestamp'])] for r in csv.DictReader(f)])
 with (DATA/'movies.csv').open(encoding='utf-8',newline='') as f:
  movies={int(r['movieId']):dict(title=r['title'],genres=[] if r['genres']=='(no genres listed)' else r['genres'].split('|')) for r in csv.DictReader(f)}
 return ratings,movies

def top(scores,ids,seen=(),k=10):
 """Round only the ranking key to 12 decimals; numeric movie ID breaks ties."""
 keep=~np.isin(ids,list(seen));ii=np.flatnonzero(keep)
 order=np.lexsort((ids[ii],-np.round(np.asarray(scores)[ii],12)))
 return [int(ids[i]) for i in ii[order[:k]]]

class Recommender:
 def __init__(self,train,movies):
  self.train=train;self.movies=movies;self.ids=np.unique(train[:,1]).astype(int);self.users=np.unique(train[:,0]).astype(int)
  self.item_index={int(i):j for j,i in enumerate(self.ids)};self.user_index={int(u):j for j,u in enumerate(self.users)}
  self.hist={int(u):{} for u in self.users}
  for u,i,r,t in train:self.hist[int(u)][int(i)]=float(r)
  self.genres=sorted({g for i in self.ids for g in movies[int(i)]['genres']})
  raw=np.array([[g in movies[int(i)]['genres'] for g in self.genres] for i in self.ids],dtype=float)
  self.idf=np.log((1+len(self.ids))/(1+raw.sum(0)))+1;features=raw*self.idf
  norms=np.linalg.norm(features,axis=1,keepdims=True);self.features=np.divide(features,norms,out=np.zeros_like(features),where=norms>0)
  self.mean=float(train[:,2].mean());self.count=np.bincount([self.item_index[int(i)] for i in train[:,1]],minlength=len(self.ids));self.total=np.bincount([self.item_index[int(i)] for i in train[:,1]],weights=train[:,2],minlength=len(self.ids))
  self.bayes=(self.total+20*self.mean)/(self.count+20)
  pos=train[train[:,2]>=4];self.binary=csr_matrix((np.ones(len(pos)),([self.user_index[int(u)] for u in pos[:,0]],[self.item_index[int(i)] for i in pos[:,1]])),shape=(len(self.users),len(self.ids)))
  self.pop=np.asarray(self.binary.sum(0)).ravel();self.norms=np.sqrt(np.asarray(self.binary.sum(1)).ravel())
  self.overlap=(self.binary@self.binary.T).toarray()
 def neighbours(self,user,shrink=10,k=20):
  if user not in self.user_index:return []
  u=self.user_index[user];co=self.overlap[u];den=self.norms[u]*self.norms
  numerator=np.divide(co,den,out=np.zeros_like(co),where=den>0)*co
  sim=np.divide(numerator,co+shrink,out=np.zeros_like(co),where=co+shrink>0)
  sim[co<2]=0;sim[u]=0
  order=np.lexsort((self.users,-np.round(sim,12)))
  return [(int(self.users[v]),float(sim[v]),int(co[v])) for v in order if sim[v]>0][:k]
 def scores(self,user,method,shrink=10,neighbours=20):
  if method=='popularity':return self.pop.copy()
  if method=='bayesian':return self.bayes.copy()
  if method=='content':
   liked=[self.item_index[i] for i,r in self.hist.get(user,{}).items() if r>=4];p=self.features[liked].sum(0) if liked else np.zeros(len(self.genres));n=np.linalg.norm(p)
   return self.features@(p/n) if n>0 else self.pop.copy()
  if method!='user_cf':raise ValueError(method)
  ns=self.neighbours(user,shrink,neighbours)
  if not ns:return self.pop.copy()
  v=np.zeros(len(self.users))
  for uid,s,_ in ns:v[self.user_index[uid]]=s
  return np.asarray(self.binary.T@v).ravel()/v.sum()
 def recommend(self,user,method,k=10,exclude_seen=True,**kwargs):
  return top(self.scores(user,method,**kwargs),self.ids,self.hist.get(user,{}) if exclude_seen else (),k)
 def item_similarity(self,a,b,shrink=10):
  a=self.item_index[a];b=self.item_index[b];co=float((self.binary[:,a].T@self.binary[:,b]).toarray()[0,0]);den=math.sqrt(self.pop[a]*self.pop[b]);return dict(overlap=int(co),cosine=co/den if den else 0,shrunk=(co/den)*co/(co+shrink) if den and co+shrink else 0)

def row_metrics(ranked,targets,k):
 targets=set(targets);ranked=ranked[:k];hits=sum(i in targets for i in ranked);dcg=sum((1/math.log2(j+2)) for j,i in enumerate(ranked) if i in targets);ideal=sum(1/math.log2(j+2) for j in range(min(k,len(targets))))
 return dict(hits=hits,precision=hits/k,recall=hits/len(targets) if targets else None,ndcg=dcg/ideal if ideal else None)

def scorecard(rows,method,k=10,warm_only=True,catalog_size=None):
 cohort=[r for r in rows if r['eligible'] and r['train_count']>0] if warm_only else [r for r in rows if r['positive']]
 if not cohort:return dict(users=0,precision=None,recall=None,ndcg=None,catalog_coverage=None)
 metrics=[row_metrics(r['rankings'][method],r['eligible'] if warm_only else r['positive'],k) for r in cohort]
 return dict(users=len(cohort),precision=float(np.mean([m['precision'] for m in metrics])),recall=float(np.mean([m['recall'] for m in metrics])),ndcg=float(np.mean([m['ndcg'] for m in metrics])),catalog_coverage=len({i for r in cohort for i in r['rankings'][method][:k]})/catalog_size if catalog_size else None)

def analyse():
 ratings,movies=load();cut=int(np.sort(ratings[:,3])[int(.8*len(ratings))-1]);train=ratings[ratings[:,3]<=cut];future=ratings[ratings[:,3]>cut];m=Recommender(train,movies)
 rows=[]
 for user in sorted(set(future[:,0].astype(int))):
  observed=future[future[:,0]==user];positive=sorted(set(observed[observed[:,2]>=4,1].astype(int)));seen=m.hist.get(user,{})
  eligible=[int(i) for i in positive if int(i) in m.item_index and int(i) not in seen]
  rows.append(dict(user=int(user),train_count=len(seen),positive=[int(i) for i in positive],eligible=eligible,rankings={method:m.recommend(int(user),method) for method in METHODS}))
 warm=[r['user'] for r in rows if r['train_count'] and r['eligible']];cold=[r['user'] for r in rows if not r['train_count'] and r['positive']];samples=warm[:3]+cold[:1]
 cases=[]
 for u in samples:
  ref=next(r for r in rows if r['user']==u);cases.append(dict(user=u,history=[[i,r] for i,r in sorted(m.hist.get(u,{}).items())],neighbours=[list(n) for n in m.neighbours(u)],top={method:[[i,float(m.scores(u,method)[m.item_index[i]])] for i in ref['rankings'][method]] for method in METHODS},unfiltered={method:m.recommend(u,method,exclude_seen=False) for method in METHODS}))
 pred=np.array([m.bayes[m.item_index[int(i)]] if int(i) in m.item_index else m.mean for i in future[:,1]])
 report=dict(dataset='MovieLens latest-small 2018-09-26 pinned snapshot',source_ratings=len(ratings),source_movies=len(movies),source_users=len(set(ratings[:,0])),fit_count=len(train),diagnostic_count=len(future),cutoff_timestamp=cut,cutoff_utc=datetime.fromtimestamp(cut,timezone.utc).isoformat(),fit_catalog=len(m.ids),fit_users=len(m.users),future_users=len(rows),warm_eligible_users=len(warm),cold_positive_users=len(cold),future_cold_items=len(set(future[:,1])-set(m.ids)),global_mean=m.mean,bayesian_rmse=float(np.sqrt(np.mean((pred-future[:,2])**2))),global_mean_rmse=float(np.sqrt(np.mean((m.mean-future[:,2])**2))),fit_sparsity=1-len(train)/(len(m.users)*len(m.ids)),source_hashes={name:digest(DATA/name) for name in ['ratings.csv.gz','movies.csv','SOURCE_README.txt']},protocol='Global timestamp cutoff from sorted 80% boundary; all ties stay in fit. Freeze one model; no updates within future window. Metadata is full 2018 snapshot, not historically versioned; fit-observed IDs only. Fixed hyperparameters without search. Repeatedly inspected diagnostics, not a blind benchmark. No exposure/impression or availability logs; missing is unknown. Binary rating>=4 is an authored preference transformation, not an original click log.')
 return dict(report=report,genres=m.genres,idf=m.idf.tolist(),movies=[[int(i),movies[int(i)]['title'],movies[int(i)]['genres']] for i in m.ids],train=[[int(u),int(i),float(r),int(t)] for u,i,r,t in train],future=[[int(u),int(i),float(r),int(t)] for u,i,r,t in future],samples=cases,rows=rows,scorecards={method:{scope:scorecard(rows,method,warm_only=scope=='warm',catalog_size=len(m.ids)) for scope in ['warm','all']} for method in METHODS},item_pairs=[dict(a=int(a),b=int(b),**m.item_similarity(int(a),int(b))) for a,b in [(m.ids[0],m.ids[1]),(m.ids[0],m.ids[2]),(m.ids[0],m.ids[0])]])

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--write-lab',action='store_true');parser.add_argument('--artifact-dir',type=Path);args=parser.parse_args();lab=analyse();payload=json.dumps(lab,ensure_ascii=False,separators=(',',':'))+'\n'
 if args.write_lab:(DATA/'recommendation_lab.json').write_text(payload,encoding='utf-8')
 if args.artifact_dir:
  args.artifact_dir.mkdir(parents=True,exist_ok=True);(args.artifact_dir/'recommendation_lab.json').write_text(payload,encoding='utf-8');(args.artifact_dir/'checksums.json').write_text(json.dumps({'recommendation_lab.json':digest(args.artifact_dir/'recommendation_lab.json')},indent=2)+'\n')
 print(json.dumps(dict(report=lab['report'],scorecards=lab['scorecards']),indent=2))
if __name__=='__main__':main()
