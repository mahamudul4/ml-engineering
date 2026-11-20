"""Chapter34: offline fit/validation/audit recommender project.

Historical development diagnostic, NOT a new blind test or online experiment.
Default import/CLI preserves assets. CPU NumPy/SciPy only, no network/training GPU.
"""
from pathlib import Path
import argparse, hashlib, importlib.util, json, math
import numpy as np

DATA = Path(__file__).resolve().parent
SOURCES = ('popularity', 'content', 'user_cf')
POLICIES = {'rrf_equal': [1., 1., 1.], 'rrf_cf': [1., 1., 2.], 'rrf_content': [1., 2., 1.]}
VERSION = 'capstone34-v1'

def payload(value): return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))+'\n'
def sha(value): return hashlib.sha256(value).hexdigest()
def digest(path): return sha(Path(path).read_bytes())
def source():
    spec = importlib.util.spec_from_file_location('capstone34source', DATA/'recommendation_workflow.py')
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m

def fuse(sources, policy='rrf_equal', budget=50, k=10):
    if policy not in POLICIES or budget not in (25, 50, 100): raise ValueError('Unknown preset')
    candidates = list(dict.fromkeys(i for name in SOURCES for i in sources[name][:budget]))
    positions = {name: {i: rank+1 for rank, i in enumerate(sources[name][:budget])} for name in SOURCES}
    scores = {i: sum(w/(60+positions[name][i]) for name, w in zip(SOURCES, POLICIES[policy]) if i in positions[name]) for i in candidates}
    ranked = sorted(candidates, key=lambda i: (-round(scores[i], 12), i))[:k]
    trace = [dict(item=i, score=scores[i], contributions=[w/(60+positions[name][i]) if i in positions[name] else 0. for name,w in zip(SOURCES,POLICIES[policy])], ranks=[positions[name].get(i) for name in SOURCES]) for i in ranked]
    return dict(candidates=candidates, ranked=ranked, trace=trace)

def metrics(ranked, gold, k=10):
    gold=set(gold); top=ranked[:k]; hits=len(gold.intersection(top)); dcg=sum(1/math.log2(j+2)for j,i in enumerate(top)if i in gold); ideal=sum(1/math.log2(j+2)for j in range(min(k,len(gold))))
    return dict(precision=hits/k,recall=hits/len(gold)if gold else None,ndcg=dcg/ideal if ideal else None)

def score(rows, method, scope='warm', catalog=1):
    selected=[r for r in rows if r['eligible'] and r['train_count']]if scope=='warm'else[r for r in rows if r['positive'] and (scope!='cold'or not r['train_count'])]
    if scope not in ('warm','broad','cold'): raise ValueError(scope)
    values=[metrics(r['rankings'][method],r['eligible']if scope=='warm'else r['positive'])for r in selected]
    pools=[r['pipelines'][method]['candidates']if method in POLICIES else r['sources'][method][:10]for r in selected]
    candidate=[];oracle=[]
    for row,pool in zip(selected,pools):
        gold=set(row['eligible']if scope=='warm'else row['positive']);h=len(gold.intersection(pool));candidate.append(h/len(gold));oracle.append(min(10,h)/len(gold))
    mean=lambda x:float(np.mean(x))if x else None
    return dict(users=len(selected),**{key:mean([v[key]for v in values])for key in ('precision','recall','ndcg')},candidate_recall=mean(candidate),oracle_recall10=mean(oracle),mean_candidates=mean([len(p)for p in pools]),catalog_coverage=len({i for r in selected for i in r['rankings'][method]})/catalog)

def select(validation_cards):
    # Only validation metrics are accepted; audit labels cannot enter selection.
    return min(POLICIES, key=lambda name:(-round(validation_cards[name]['warm']['ndcg'],12),-round(validation_cards[name]['warm']['recall'],12),list(POLICIES).index(name)))

def contract_errors(expected, loaded):
    return [key for key in ('model_version','model_sha256','catalog_sha256','feature_schema','policy_sha256')if expected.get(key)!=loaded.get(key)]

def cache_signature(row, manifest, policy, budget=50):
    artifact=':'.join(str(manifest[key])for key in ('model_version','model_sha256','catalog_sha256','feature_schema','policy_sha256'))
    return f"{artifact}:{row['user']}:{row['history_sha256']}:{policy}:{budget}:seen=all-fit"

def replay(rows, manifest, mode='complete', budget=50):
    warm=next(r for r in rows if r['train_count']and r['eligible']); cold=next(r for r in rows if not r['train_count'])
    requests=[(warm,'rrf_equal'),(warm,'rrf_cf'),(warm,'rrf_equal'),(cold,'rrf_equal'),(warm,'rrf_cf')]
    cache={};trace=[]
    for row,policy in requests:
        artifact=':'.join(str(manifest[key])for key in ('model_version','model_sha256','catalog_sha256','feature_schema','policy_sha256'))
        full=cache_signature(row,manifest,policy,budget)
        key=full if mode=='complete'else f"{artifact}:{policy}:{budget}:seen=all-fit"if mode=='shared_user'else f"{artifact}:{row['user']}:{row['history_sha256']}:{budget}:seen=all-fit"
        previous=cache.get(key); rejected=previous is not None and previous['signature']!=full;hit=previous is not None and not rejected
        ranked=previous['ranked']if hit else fuse(row['sources'],policy,budget)['ranked']
        cache[key]=dict(signature=full,ranked=ranked)
        trace.append(dict(user=row['user'],policy=policy,hit=hit,rejected=rejected,ranked=ranked))
    return dict(requests=len(trace),hits=sum(r['hit']for r in trace),rejected=sum(r['rejected']for r in trace),computations=sum(not r['hit']for r in trace),trace=trace)

def analyse():
    m=source();raw,movies=m.load();timestamps=np.sort(raw[:,3]);fit_cut=int(timestamps[int(.8*len(raw))-1]);valid_cut=int(timestamps[int(.9*len(raw))-1]);fit=raw[raw[:,3]<=fit_cut];validation=raw[(raw[:,3]>fit_cut)&(raw[:,3]<=valid_cut)];audit=raw[raw[:,3]>valid_cut];model=m.Recommender(fit,movies)
    model_data=dict(train=[[int(u),int(i),float(r),int(t)]for u,i,r,t in fit],movies=[[int(i),movies[int(i)]['title'],movies[int(i)]['genres']]for i in model.ids],genres=model.genres,idf=model.idf.tolist(),neighbour_limit=20,shrink=10.,positive_threshold=4.)
    roles={};cards={}
    for role,events in [('validation',validation),('audit',audit)]:
        rows=[]
        for uid in sorted(set(events[:,0].astype(int))):
            observed=events[events[:,0]==uid];positive=sorted(set(observed[observed[:,2]>=4,1].astype(int)));seen=model.hist.get(int(uid),{});eligible=sorted(set(positive).intersection(model.item_index)-set(seen));sources={name:model.recommend(int(uid),name,k=100)for name in SOURCES};pipelines={name:fuse(sources,name)for name in POLICIES}
            rows.append(dict(user=int(uid),train_count=len(seen),positive=[int(i)for i in positive],eligible=[int(i)for i in eligible],cold_fallback=not any(r>=4 for r in seen.values()),cf_fallback=not bool(model.neighbours(int(uid))),history_sha256=sha(payload(sorted(seen.items())).encode()),sources=sources,pipelines=pipelines,rankings={**{name:sources[name][:10]for name in ('popularity','user_cf')},**{name:value['ranked']for name,value in pipelines.items()}}))
        roles[role]=rows;cards[role]={name:{scope:score(rows,name,scope,len(model.ids))for scope in ('warm','broad','cold')}for name in ('popularity','user_cf',*POLICIES)}
    selected=select(cards['validation']);policy=dict(version=VERSION,sources=list(SOURCES),budget=50,k=10,rrf_constant=60.,policies=POLICIES,selected=selected,selector='validation warm NDCG descending rounded12,Recall descending rounded12,declared preset order;fusion policies only;no refit')
    manifest=dict(model_version=VERSION,model_sha256=sha(payload(model_data).encode()),catalog_sha256=sha(payload([int(i)for i in model.ids]).encode()),feature_schema='fit-IDF-unit-genres+positive-profile+shrunk-user-cf-v1',policy_sha256=sha(payload(policy).encode()))
    warm=[r for r in roles['audit']if r['train_count']and r['eligible']];sample_ids=[r['user']for r in warm[:3]]+[next(r['user']for r in roles['audit']if not r['train_count'])]
    differences=[metrics(r['rankings'][selected],r['eligible'])['recall']-metrics(r['rankings']['popularity'],r['eligible'])['recall']for r in warm];x=np.array(differences);draws=x[np.random.default_rng(34).integers(len(x),size=(5000,len(x)))].mean(1);bounds=np.quantile(draws,[.025,.975],method='linear')
    return dict(report=dict(source_hashes={name:digest(DATA/name)for name in ('ratings.csv.gz','movies.csv','SOURCE_README.txt')},raw_rows=len(raw),fit_rows=len(fit),validation_rows=len(validation),audit_rows=len(audit),fit_cutoff=fit_cut,validation_cutoff=valid_cut,fit_users=len(model.users),fit_items=len(model.ids),fit_positives=int(model.pop.sum()),selected_policy=selected,protocol='80/10/10 timestamp thresholds,ties stay earlier,actual counts reported. Initial60/20/20 cohort feasibility check had only5warm audit users;expanded fit history for viable panel,not fresh protocol confirmation. Fit-only maps/IDF/profiles/neighbours;validation selects among3 declared RRF presets,baseline comparison separate,no refit. Frozen fit history for validation/audit,not prequential. Historical MovieLens development data already inspected,not a new blind test. Full2018 metadata not historically versioned,rating-entry timestamps not watch-time. CPU deterministic,not ANN/latency/online lift.'),model=model_data,policy=policy,manifest=manifest,roles=roles,scorecards=cards,samples=sample_ids,paired=dict(users=len(warm),mean=float(x.mean()),low=float(bounds[0]),high=float(bounds[1]),replicates=5000,seed=34,scope='Audit selected-policy vs popularity,conditional fixed-model user bootstrap;selection process not resampled,unadjusted,historical diagnostic'),cache={mode:replay(roles['audit'],manifest,mode)for mode in ('complete','shared_user','omit_policy')})

def verify_bundle(directory):
    directory=Path(directory);checks=json.loads((directory/'checksums.json').read_text());names={'capstone_model.json','capstone_policy.json','recommender_capstone_lab.json','SOURCE_README.txt'}
    if set(checks)!=names: raise ValueError('Incomplete artifact set')
    for name,h in checks.items():
        if digest(directory/name)!=h: raise ValueError(f'Checksum mismatch: {name}')
    lab=json.loads((directory/'recommender_capstone_lab.json').read_text(encoding='utf-8'))
    if digest(directory/'capstone_model.json')!=lab['manifest']['model_sha256']or digest(directory/'capstone_policy.json')!=lab['manifest']['policy_sha256']:raise ValueError('Manifest mismatch')
    if digest(directory/'SOURCE_README.txt')!=lab['report']['source_hashes']['SOURCE_README.txt']:raise ValueError('Source notice mismatch')
    return dict(verified=True,files=len(checks),model_version=lab['manifest']['model_version'])

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--write-lab',action='store_true');parser.add_argument('--artifact-dir',type=Path);parser.add_argument('--verify-dir',type=Path);args=parser.parse_args()
    if args.verify_dir: print(json.dumps(verify_bundle(args.verify_dir)));return
    lab=analyse()
    if args.write_lab:(DATA/'recommender_capstone_lab.json').write_text(payload(lab),encoding='utf-8')
    if args.artifact_dir:
        args.artifact_dir.mkdir(parents=True,exist_ok=True)
        files={'capstone_model.json':lab['model'],'capstone_policy.json':lab['policy'],'recommender_capstone_lab.json':lab}
        for name,value in files.items():(args.artifact_dir/name).write_text(payload(value),encoding='utf-8',newline='\n')
        (args.artifact_dir/'SOURCE_README.txt').write_bytes((DATA/'SOURCE_README.txt').read_bytes())
        (args.artifact_dir/'checksums.json').write_text(payload({name:digest(args.artifact_dir/name)for name in [*files,'SOURCE_README.txt']}),encoding='utf-8')
    print(json.dumps(dict(report=lab['report'],manifest=lab['manifest'],validation=lab['scorecards']['validation'],audit=lab['scorecards']['audit'],paired=lab['paired'],cache={name:{k:v for k,v in value.items()if k!='trace'}for name,value in lab['cache'].items()}),indent=2))

if __name__=='__main__':main()
