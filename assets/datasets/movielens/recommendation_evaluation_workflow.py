"""Chapter33: frozen MovieLens evaluation, paired user bootstrap and MMR.

No retraining or network. Reuses original sources/Chapters30 and32 snapshots.
Online/IPS calculator is a declared mathematical fixture, NOT MovieLens logs.
Default CLI preserves assets; --write-lab derives evaluation JSON explicitly.
"""
from pathlib import Path
import argparse,hashlib,importlib.util,json,math
import numpy as np
DATA=Path(__file__).resolve().parent
LAMBDAS=(1.,.75,.5)
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def sources():
 s=importlib.util.spec_from_file_location('eval33source',DATA/'deep_recommendation_workflow.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def metrics(ranked,gold,k=10):
 gold=set(gold);top=ranked[:k];hits=len(set(top)&gold);dcg=sum(1/math.log2(j+2)for j,i in enumerate(top)if i in gold);ideal=sum(1/math.log2(j+2)for j in range(min(k,len(gold))));return dict(hits=hits,precision=hits/k,recall=hits/len(gold)if gold else None,ndcg=dcg/ideal if ideal else None,mrr=next((1/(j+1)for j,i in enumerate(top)if i in gold),0.)if gold else None)
def cohort(rows,scope):
 if scope=='warm':return[r for r in rows if r['train_count']and r['eligible']]
 if scope=='cold':return[r for r in rows if not r['train_count']and r['positive']]
 if scope=='broad':return[r for r in rows if r['positive']]
 raise ValueError(scope)
def score(rows,method,scope='warm',k=10):
 selected=cohort(rows,scope);vectors=[metrics(r['rankings'][method],r['eligible']if scope=='warm'else r['positive'],k)for r in selected]
 return dict(users=len(selected),**{key:float(np.mean([r[key]for r in vectors]))if vectors else None for key in ['precision','recall','ndcg','mrr']})
def bootstrap(differences,repeats=5000,seed=33):
 x=np.asarray(differences);rng=np.random.default_rng(seed)
 if not len(x):return dict(users=0,mean=None,low=None,high=None)
 draws=x[rng.integers(len(x),size=(repeats,len(x)))].mean(1);low,high=np.quantile(draws,[.025,.975],method='linear');return dict(users=len(x),mean=float(x.mean()),low=float(low),high=float(high),repeats=repeats,seed=seed,replicates=draws.tolist())
def mmr(ids,scores,genres,strength=1.,k=10):
 ids=list(ids);raw=np.asarray(scores);lo=float(raw.min());hi=float(raw.max());relevance=(raw-lo)/(hi-lo)if hi>lo else np.zeros(len(raw));chosen=[];trace=[]
 for step in range(min(k,len(ids))):
  remaining=[j for j in range(len(ids))if j not in chosen];penalty={j:max((float(genres[ids[j]]@genres[ids[s]])for s in chosen),default=0.)for j in remaining};value={j:strength*relevance[j]-(1-strength)*penalty[j]for j in remaining};best=min(remaining,key=lambda j:(-round(value[j],12),ids[j]));chosen.append(best);trace.append(dict(item=ids[best],raw=float(raw[best]),relevance=float(relevance[best]),redundancy=penalty[best],utility=float(value[best])))
 return dict(ranked=[ids[j]for j in chosen],trace=trace)
def list_quality(ranked,genres,pop,total,catalog):
 pairs=[1-float(genres[a]@genres[b])for j,a in enumerate(ranked)for b in ranked[j+1:]];novel=[-math.log2((pop.get(i,0)+1)/(total+catalog))for i in ranked]
 return dict(ild=float(np.mean(pairs))if pairs else None,novelty_bits=float(np.mean(novel))if novel else None)
def diversity_summary(rows,method,genres,pop,catalog):
 selected=cohort(rows,'warm');qualities=[list_quality(r['rankings'][method],genres,pop,sum(pop.values()),catalog)for r in selected];counts={}
 for row in selected:
  for i in row['rankings'][method]:counts[i]=counts.get(i,0)+1
 total=sum(counts.values());prob=np.array(list(counts.values()))/total if total else np.array([]);h=float(-(prob*np.log2(prob)).sum())if total else None
 return dict(users=len(selected),ild=float(np.mean([v['ild']for v in qualities])),novelty_bits=float(np.mean([v['novelty_bits']for v in qualities])),catalog_coverage=len(counts)/catalog,recommendation_entropy_bits=h,distinct_recommended=len(counts))
def propensity_fixture(clip=None):
 # Explicit four-row algebra fixture, not source interactions or an A/B test.
 logged=[dict(context=0,action='A',logging=.8,reward=1,target='A'),dict(context=1,action='B',logging=.2,reward=1,target='B'),dict(context=2,action='A',logging=.8,reward=0,target='B'),dict(context=3,action='B',logging=.2,reward=0,target='A')]
 weights=[min(1/r['logging'],clip)if clip is not None else 1/r['logging'] for r in logged];weights=[w if r['action']==r['target']else 0 for w,r in zip(weights,logged)];weighted=sum(w*r['reward']for w,r in zip(weights,logged));den=sum(weights)
 return dict(rows=logged,weights=weights,naive=sum(r['reward']for r in logged)/4,ips=weighted/4,snips=weighted/den if den else None,ess=den**2/sum(w*w for w in weights)if den else None,clip=clip)
def sample_size(baseline=.1,mde=.01):return math.ceil(2*(1.96+.84)**2*baseline*(1-baseline)/(mde*mde))
def analyse():
 m=sources();base=json.loads((DATA/'recommendation_lab.json').read_text(encoding='utf-8'));deep=json.loads((DATA/'deep_recommendation_lab.json').read_text());raw=np.array(base['train']);movies={i:(title,gs)for i,title,gs in base['movies']};genre_names=base['genres'];g={i:np.array([name in gs for name in genre_names],dtype=float)for i,(title,gs)in movies.items()}
 for i,v in g.items():norm=np.linalg.norm(v);g[i]=v/norm if norm else v
 pop={}
 for u,i,r,t in base['train']:
  if r>=4:pop[i]=pop.get(i,0)+1
 _,_,_,users,items,um,im,u,i,r,mask,genre_matrix=m.load_inputs();stats=m.fit_stats(u,i,r,mask,genre_matrix,len(users),len(items));q=np.array(deep['query_vectors']);v=np.array(deep['item_vectors']);rw=deep['ranker'];mean=np.array(deep['ranker_settings']['feature_mean']);std=np.array(deep['ranker_settings']['feature_std']);rows=[];cases=[]
 for original in deep['rows']:
  uid=original['user'];pool=original['pipelines']['neural100']['candidates'];cold=original['pipelines']['neural100']['fallback'];scores=np.array([pop.get(item,0)for item in pool],dtype=float)if cold else m.rank_numpy(rw,(m.feature_matrix(np.full(len(pool),um[uid]),np.array([im[item]for item in pool]),q,v,genre_matrix,stats)-mean)/std)
  results={f'mmr{strength:g}':mmr(pool,scores,g,strength)for strength in LAMBDAS};row={k:val for k,val in original.items()if k not in ['rankings','pipelines']};row['rankings']={name:original['rankings'][name]for name in ['neural50','neural100','hybrid50','popularity','user_cf']};row['rankings'].update({name:value['ranked']for name,value in results.items()});rows.append(row)
  if uid in [c['user']for c in deep['samples']]:cases.append(dict(user=uid,candidates=pool,scores=scores.tolist(),fallback=cold,results=results))
 methods=list(rows[0]['rankings']);scorecards={method:{scope:score(rows,method,scope)for scope in ['warm','broad','cold']}for method in methods};warm=cohort(rows,'warm');paired={}
 for metric in ['recall','ndcg']:
  for treatment in ['neural50','hybrid50','mmr0.75','mmr0.5']:
   control='user_cf'if treatment in ['neural50','hybrid50']else'mmr1';d=[dict(user=row['user'],treatment=metrics(row['rankings'][treatment],row['eligible'])[metric],control=metrics(row['rankings'][control],row['eligible'])[metric])for row in warm];diff=[v['treatment']-v['control']for v in d];paired[f'{treatment}:{control}:{metric}']=dict(rows=d,bootstrap=bootstrap(diff))
 future=base['future'];timestamps=sorted(row[3]for row in future);mid=timestamps[len(timestamps)//2];windows={}
 for name,predicate in [('early',lambda t:t<=mid),('late',lambda t:t>mid)]:
  positives={}
  for uid,item,r,t in future:
   if r>=4 and predicate(t):positives.setdefault(uid,set()).add(item)
  windowrows=[]
  for row in rows:
   uid=row['user'];gold=positives.get(uid,set());seen={item for user,item,r,t in base['train']if user==uid};windowrows.append(dict(row,positive=sorted(gold),eligible=sorted(gold&set(movies)-seen)))
  windows[name]=dict(rows=windowrows,scorecards={method:score(windowrows,method,'warm')for method in ['neural50','user_cf','mmr1','mmr0.5']},events=sum(predicate(t)for u,i,r,t in future))
 # Pure split audit: this does NOT refit any model under random/per-user roles.
 allrows=np.array(base['train']+base['future']);order=np.random.default_rng(330).permutation(len(allrows));randomfit=allrows[order[:int(.8*len(allrows))]];randomtest=allrows[order[int(.8*len(allrows)):]];peruser_fit=[];peruser_test=[]
 for uid in sorted(set(allrows[:,0])):
  subset=allrows[allrows[:,0]==uid];cut=sorted(subset[:,3])[int(.8*len(subset))-1];peruser_fit.extend(subset[subset[:,3]<=cut].tolist());peruser_test.extend(subset[subset[:,3]>cut].tolist())
 split_audit=dict(global_cutoff=base['report']['cutoff_timestamp'],random_fit_max=int(randomfit[:,3].max()),random_test_min=int(randomtest[:,3].min()),random_fit_after_global_cutoff=int((randomfit[:,3]>base['report']['cutoff_timestamp']).sum()),random_test_before_or_equal_global_cutoff=int((randomtest[:,3]<=base['report']['cutoff_timestamp']).sum()),per_user_fit_max=int(max(r[3]for r in peruser_fit)),per_user_test_min=int(min(r[3]for r in peruser_test)),per_user_fit_rows=len(peruser_fit),per_user_test_rows=len(peruser_test))
 return dict(report=dict(source_hashes={name:digest(DATA/name)for name in ['ratings.csv.gz','movies.csv','SOURCE_README.txt','recommendation_lab.json','deep_recommendation_lab.json']},warm_users=len(warm),broad_users=len(cohort(rows,'broad')),cold_users=len(cohort(rows,'cold')),future_window_boundary=mid,protocol='No model retraining or future feature fitting. Frozen Chapter32 predictions/candidate100 pool and exact saved ranker. MMR relevance minmax ranker logits for warm;full-fit popularity counts for cold,then same MMR policy applied (cold diversity experiment differs from Chapter32 bypass). Genre cosine from full2018 snapshot,not historically versioned. Lambda1/.75/.5 predeclared,no tuning. Paired percentile user bootstrap5000 seed33,linear quantiles95%;conditional on inspected fixed split/models,not training/temporal/exposure uncertainty or causal lift;unadjusted multiple comparisons. Window diagnostics use frozen rankings/no updates;eligible cohorts differ. No MovieLens impression propensities/IPS/online lift measured. IPS/A-B planner algebra fixtures explicitly authored.'),rows=rows,samples=cases,paired=paired,scorecards=scorecards,diversity={name:diversity_summary(rows,name,g,pop,len(movies))for name in ['neural50','user_cf','mmr1','mmr0.75','mmr0.5']},windows=windows,split_audit=split_audit,fixture=propensity_fixture(),fixture_clipped=propensity_fixture(2),planner=dict(baseline=.1,mde=.01,z_alpha=1.96,z_power=.84,per_arm=sample_size()),popularity=[[i,pop.get(i,0)]for i in sorted(movies)])
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--write-lab',action='store_true');parser.add_argument('--artifact-dir',type=Path);args=parser.parse_args();lab=analyse();payload=json.dumps(lab,separators=(',',':'))+'\n'
 if args.write_lab:(DATA/'recommendation_evaluation_lab.json').write_text(payload)
 if args.artifact_dir:
  args.artifact_dir.mkdir(parents=True,exist_ok=True);(args.artifact_dir/'recommendation_evaluation_lab.json').write_text(payload);(args.artifact_dir/'checksums.json').write_text(json.dumps({'recommendation_evaluation_lab.json':digest(args.artifact_dir/'recommendation_evaluation_lab.json')},indent=2)+'\n')
 print(json.dumps(dict(report=lab['report'],paired={k:{kk:vv for kk,vv in v['bootstrap'].items()if kk!='replicates'}for k,v in lab['paired'].items()},diversity=lab['diversity'],scorecards={k:v['warm']for k,v in lab['scorecards'].items()}),indent=2))
if __name__=='__main__':main()
