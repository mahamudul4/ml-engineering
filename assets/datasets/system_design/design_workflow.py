"""Chapter38: real offline case replays plus explicitly authored system assumptions.

No production traffic/latency/fraud/medical truth claim. Spambase exact-profile
group split;reserved test labels unscored/unexported. Prior artifacts frozen.
Default import/CLI preserves assets;--write-lab explicitly writes derived JSON.
"""
from pathlib import Path
from collections import Counter
import argparse,hashlib,importlib.util,json,math,re
import numpy as np
from scipy.special import expit
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import GroupShuffleSplit
from sklearn.preprocessing import StandardScaler

DATA=Path(__file__).resolve().parent;ROOT=DATA.parent
SPAM_HASHES={'spambase.data':'b1ef93de71f97714d3d7d4f58fc9f718da7bbc8ac8a150eff2778616a8097b12','spambase.names':'df418fab7923f929237b81efa0987ddfaf2d68cf61291243625aadc684d5ab6a','spambase.DOCUMENTATION':'462e4ffba1241a5962d528364708d188dc75931d56a25a8e9b6c8bb25e094cfd'}
DEPENDENCIES=['movielens/recommender_capstone_lab.json','scifact/retrieval_index.json','scifact/retrieval_lab.json','scifact/corpus.jsonl','scifact_rag/capstone_lab.json','scifact_rag/corpus.jsonl','bike_sharing/serving_lab.json']
CASE_IDS=('recommendation','search','spam','forecast','rag')
RESPONSE_POLICIES={'recommendation':dict(policy='rrf_cf',budget=50,k=10,fallback='fit_popularity'),'search':dict(method='hybrid',depth=100,k=5,fallback='tfidf'),'spam':dict(binary_threshold=.5,missing_features='defer'),'forecast':dict(target=375,model='ridge36-v1',scenario='on_time',fallback='seasonal7'),'rag':dict(source_case='claim2/retrieved',threshold=0.,format='support-or-contradict+EOS',policy='unverified_hypothesis',missing_context='abstain')}
_DEPS=None
def payload(x):return json.dumps(x,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\n'
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def identity(x):return hashlib.sha256(payload(x).encode()).hexdigest()
def read(name):return json.loads((ROOT/name).read_text(encoding='utf-8'))
def deps():
    global _DEPS
    if _DEPS is None:_DEPS={n:read(n)for n in DEPENDENCIES if n.endswith('.json')}
    return _DEPS
def load_spam():
    for name,h in SPAM_HASHES.items():
        if digest(ROOT/'spambase'/name)!=h:raise ValueError('Original source mismatch:'+name)
    a=np.loadtxt(ROOT/'spambase/spambase.data',delimiter=',');x=a[:,:57];y=a[:,57].astype(int)
    if a.shape!=(4601,58)or not np.isfinite(a).all()or np.any(x<0)or not np.isin(a[:,57],[0,1]).all():raise ValueError('Invalid source matrix')
    _,groups=np.unique(x,axis=0,return_inverse=True)
    train,remaining=next(GroupShuffleSplit(n_splits=1,train_size=.7,random_state=38).split(x,groups=groups))
    vi,ti=next(GroupShuffleSplit(n_splits=1,train_size=.5,random_state=380).split(x[remaining],groups=groups[remaining]));roles={'train':np.sort(train),'validation':np.sort(remaining[vi]),'reserved':np.sort(remaining[ti])}
    names=[line.split(':')[0].strip()for line in (ROOT/'spambase/spambase.names').read_text().splitlines()if ': 'in line and line.strip().endswith('continuous.')]
    if len(names)!=57:raise ValueError('Feature field order')
    return x,y,groups,roles,names
def valid_spam_model(model):
    if model.get('version')!='spam38-logreg-v1'or model.get('schema')!='spambase57-v1':return False
    for k in ['mean','scale','weights']:
        a=model.get(k)
        if not isinstance(a,list)or len(a)!=57 or any(type(v)not in(int,float)or not math.isfinite(v)for v in a):return False
    return all(v>0 for v in model['scale'])and type(model.get('intercept'))in(int,float)and math.isfinite(model['intercept'])
def spam_predict(model,features):
    if not valid_spam_model(model)or len(features)!=57 or any(type(v)not in(int,float)or not math.isfinite(v)or v<0 for v in features):return None
    raw=model['intercept']+sum(w*(x-mu)/s for x,mu,s,w in zip(features,model['mean'],model['scale'],model['weights']))
    if not math.isfinite(raw):return None
    return 1/(1+math.exp(-raw))if raw>=0 else math.exp(raw)/(1+math.exp(raw))
def binary_metrics(rows,threshold=.5):
    counts=dict(tp=0,fp=0,tn=0,fn=0)
    for r in rows:counts[('tp'if r['label'] else'fp')if r['score']>=threshold else('fn'if r['label'] else'tn')]+=1
    tp,fp,tn,fn=(counts[k]for k in ['tp','fp','tn','fn'])
    return dict(n=len(rows),threshold=threshold,**counts,precision=tp/(tp+fp)if tp+fp else None,recall=tp/(tp+fn)if tp+fn else None,fpr=fp/(fp+tn)if fp+tn else None,accuracy=(tp+tn)/len(rows))
def review_policy(rows,low=.2,high=.8,budget=50,overflow='defer',fp_cost=100,fault=False):
    if not 0<=low<high<=1 or type(budget)is not int or budget<0 or overflow not in('defer','allow','block')or fp_cost<0:raise ValueError('Invalid policy')
    n=len(rows);routes=['defer']*n;uncertain=[]
    if not fault:
        for j,r in enumerate(rows):
            p=r['score']
            if not math.isfinite(p)or not 0<=p<=1:raise ValueError('Invalid score')
            if p<low:routes[j]='allow'
            elif p>=high:routes[j]='block'
            else:uncertain.append(j)
        uncertain.sort(key=lambda j:(math.floor(abs(rows[j]['score']-.5)*1e12+.5),rows[j]['index']))
        for j in uncertain[:budget]:routes[j]='review'
        for j in uncertain[budget:]:routes[j]=overflow
    counts={k:routes.count(k)for k in ['allow','block','review','defer']};fp=sum(route=='block'and r['label']==0 for route,r in zip(routes,rows));fn=sum(route=='allow'and r['label']==1 for route,r in zip(routes,rows));decided=counts['allow']+counts['block'];pending=counts['review']+counts['defer']
    return dict(n=n,low=low,high=high,budget=budget,overflow=overflow,fp_cost=fp_cost,contract_blocked=n if fault else 0,uncertain=len(uncertain),overflow_count=max(0,len(uncertain)-budget),review_ids=[rows[j]['index']for j in uncertain[:budget]],**counts,decided=decided,pending=pending,coverage=decided/n if n else None,false_blocks=fp,missed_spam=fn,conditional_accuracy=(decided-fp-fn)/decided if decided else None,automatic_cost=fp_cost*fp+fn,routes=routes)
def guarded_review(lab,**kw):
    fault=kw.pop('fault',False);rows=lab['spam']['validation']
    if fault or not valid_spam_model(lab['spam']['model']):return review_policy(rows,fault=True,**kw)
    actual=[dict(r,score=spam_predict(lab['spam']['model'],r['features']))for r in rows]
    return review_policy(actual,**kw)
def architecture_cases():
    def group(label,ms):return [dict(label=label,ms=ms)]
    return {
    'recommendation':dict(title='Recommendation & ranking',request='MovieLens audit user15',quality='Historical RRF ranking from fit-only sources;not online lift',stages=[group('Validate request',2),[dict(label='Popularity',ms=3),dict(label='Content',ms=8),dict(label='User-CF',ms=12)],group('RRF + seen filter',4),group('Return top10',2)]),
    'search':dict(title='Lexical + semantic retrieval',request='SciFact saved query0',quality='Fixed TF-IDF/LSA hybrid;not pretrained encoder or ANN benchmark',stages=[group('Encode query',3),[dict(label='Lexical',ms=8),dict(label='LSA candidates',ms=12)],group('RRF merge',2),group('Return top5',1)]),
    'spam':dict(title='Spam classification & review',request='Spambase validation first source row',quality='Exact-profile-group development split;reserved labels unused',stages=[group('Validate features',2),group('Train-only scaling',1),group('Linear inference',2),group('Decision policy',1),group('Return route',1)]),
    'forecast':dict(title='Daily demand forecasting',request='Bike target375 · 2012-01-11',quality='Frozen 2011 Ridge;historical rolling one-step,not current demand',stages=[group('Lookup known events',4),group('Build point-in-time features',2),group('Ridge inference',1),group('Fallback policy',1),group('Return count',1)]),
    'rag':dict(title='Retrieval-augmented response',request='SciFact saved claim2',quality='Tiny support/contradict decoder;unverified hypothesis,not medical truth',stages=[group('Encode query',3),group('Retrieve documents',12),group('Pack exact source spans',8),group('Decode response word',25),group('Provenance gate',4)])}
def capacity(case,qps=1000,hit=.5,replicas=4,scale=1.,deadline=100):
    if type(qps)is not int or qps<0 or not math.isfinite(hit)or not 0<=hit<=1 or type(replicas)is not int or replicas<1 or not math.isfinite(scale)or scale<=0 or deadline<=0:raise ValueError('Invalid planning assumptions')
    times=[max(s['ms']for s in g)*scale for g in case['stages']];critical=sum(times);total=sum(s['ms']for g in case['stages']for s in g)*scale;backend=qps*(1-hit);slots=4*replicas;limit=slots*1000/critical;rho=backend/limit
    return dict(qps=qps,hit=hit,replicas=replicas,scale=scale,deadline=deadline,critical_ms=critical,serial_work_ms=total,parallel_saved_ms=total-critical,backend_qps=backend,concurrent_slots=slots,ideal_capacity=limit,utilization=rho,stable=rho<1,in_service=backend*critical/1000 if rho<1 else None,deadline_slack=deadline-critical,state='OVERLOAD'if rho>=1 else'LOW HEADROOM'if rho>.7 else'WITHIN ASSUMPTION')
def manifest(case,dependencies,spam):
    source={'recommendation':'movielens/recommender_capstone_lab.json','search':'scifact/retrieval_index.json','spam':'spambase/spambase.data','forecast':'bike_sharing/serving_lab.json','rag':'scifact_rag/capstone_lab.json'}[case]
    return dict(case_version='design38-v1:'+case,model_identity=identity(spam['model'])if case=='spam'else dependencies[source],source_identity=dependencies[source],input_schema={'spam':'spambase57-v1','forecast':'bike-features35-v1','recommendation':'fit-history+three-source-ranks','search':'tfidf4096+lsa32','rag':'query+exact-source-context'}[case],policy_identity=identity(RESPONSE_POLICIES[case]))
def contract_errors(expected,loaded):return [k for k in ['case_version','model_identity','source_identity','input_schema','policy_identity']if expected.get(k)!=loaded.get(k)]
def search_replay(method='hybrid'):
    d=deps();index=d['scifact/retrieval_index.json'];sample=d['scifact/retrieval_lab.json']['samples'][0];lookup={t:i for i,t in enumerate(index['vocabulary'])};counts=Counter(t.lower()for t in re.findall('[A-Za-z0-9]+',sample['text']));q=np.zeros(len(lookup))
    for token,n in counts.items():
        if token in lookup:q[lookup[token]]=(1+math.log(n))*index['idf'][lookup[token]]
    norm=np.linalg.norm(q);q=q/norm if norm else q;dense=np.asarray(index['components'])@q;norm=np.linalg.norm(dense);dense=dense/norm if norm else dense;lex=[];semantic=[]
    for row in index['documents']:
        score=sum(v*q[i]for i,v in zip(row['indices'],row['values']))
        if score>0:lex.append((row['id'],float(score)))
        if np.any(row['dense']):semantic.append((row['id'],float(np.dot(row['dense'],dense))))
    sort=lambda pairs:sorted(pairs,key=lambda r:(-r[1],int(r[0])))
    lex=sort(lex);semantic=sort(semantic)
    if method=='tfidf':return [r[0]for r in lex[:5]]
    scores={}
    for ranked in [lex[:100],semantic[:100]]:
        for rank,(doc,_)in enumerate(ranked):scores[doc]=scores.get(doc,0)+1/(61+rank)
    return sorted(scores,key=lambda doc:(-scores[doc],int(doc)))[:5]
def rag_word(sample,weights,vocabulary):
    def block(text):
        counts=np.zeros(128)
        for word in re.findall('[A-Za-z0-9]+',text.lower()):
            h=2166136261
            for b in word.encode():h=((h^b)*16777619)&0xffffffff
            counts[h%128]+=1
        x=np.log1p(counts);n=np.linalg.norm(x);return x/n if n else x
    context=sample['cases']['retrieved']['context'];x=np.r_[block(sample['text']),block(context)];w={k:np.asarray(v)for k,v in weights.items()};h=np.tanh(w['condition.weight']@x+w['condition.bias']);token=1;ids=[]
    for _ in range(12):
        emb=w['embedding.weight'][token];gi=w['cell.weight_ih']@emb+w['cell.bias_ih'];gh=w['cell.weight_hh']@h+w['cell.bias_hh'];r=expit(gi[:16]+gh[:16]);z=expit(gi[16:32]+gh[16:32]);n=np.tanh(gi[32:]+r*gh[32:]);h=(1-z)*n+z*h;logits=w['head.weight']@h+w['head.bias'];token=int(np.argmax(logits[2:]))+2;ids.append(token)
        if token==2:break
    return ''.join(vocabulary[i]for i in ids if i>=3),bool(ids and ids[-1]==2)
def response(lab,case='recommendation',fault='none'):
    if case not in CASE_IDS or fault not in ('none','model_mismatch','upstream'):raise ValueError('Unknown case/fault')
    expected=lab['manifests'][case];loaded=dict(expected)
    if fault=='model_mismatch':loaded['model_identity']='explicit software mismatch'
    base=dict(case=case,request=lab['cases'][case]['request'],status='OK',served='',reason='',output=None,citations=[])
    if contract_errors(expected,loaded):return dict(base,status='BLOCKED',served='none',reason='artifact_contract')
    d=deps();upstream=fault=='upstream'
    if case=='recommendation':
        data=d['movielens/recommender_capstone_lab.json'];row=next(r for r in data['roles']['audit']if r['user']==15)
        if upstream:return dict(base,status='DEGRADED',served='fit_popularity',reason='personalization_missing_fixture',output=dict(items=row['sources']['popularity'][:10]))
        positions={name:{item:i+1 for i,item in enumerate(row['sources'][name][:50])}for name in ['popularity','content','user_cf']};candidates=set().union(*(set(v)for v in positions.values()));weights={'popularity':1,'content':1,'user_cf':2};scores={i:sum(weights[k]/(60+v[i])for k,v in positions.items()if i in v)for i in candidates};ranked=sorted(candidates,key=lambda i:(-round(scores[i],12),i))[:10]
        return dict(base,served='weighted_rrf',reason='validated_ranking',output=dict(items=ranked))
    if case=='search':return dict(base,status='DEGRADED'if upstream else'OK',served='lexical_tfidf'if upstream else'hybrid_rrf',reason='dense_candidates_ignored_fixture'if upstream else'validated_retrieval',output=dict(documents=search_replay('tfidf'if upstream else'hybrid')))
    if case=='spam':
        if upstream:return dict(base,status='ABSTAIN',served='defer',reason='feature_source_missing_fixture')
        p=spam_predict(lab['spam']['model'],lab['spam']['validation'][0]['features'])
        if p is None:return dict(base,status='ABSTAIN',served='defer',reason='invalid_features')
        return dict(base,served='logistic',reason='validated_score',output=dict(probability=p,decision='block'if p>=.5 else'allow'))
    if case=='forecast':
        data=d['bike_sharing/serving_lab.json'];events=data['events']['late_fixture'if upstream else'on_time'];known={r['event_day']:r['cnt']for r in events if r['event_day']<375 and r['available_day']<=375};window=[known[i]for i in range(368,375)if i in known];f=dict(lag1=known.get(374),lag7=known.get(368),mean7=sum(window)/len(window));model=data['models']['candidate']
        if f['lag1']is None:return dict(base,status='DEGRADED',served='seasonal7',reason='late_feature_fixture',output=dict(prediction=float(f['lag7'])))
        pred=max(0.,model['intercept']+sum(w*(f[k]-mu)/s for k,mu,s,w in zip(model['input_fields'],model['mean'],model['scale'],model['weights'])))
        return dict(base,served='ridge',reason='validated_point_in_time',output=dict(prediction=pred))
    if upstream:return dict(base,status='ABSTAIN',served='no_answer',reason='empty_context_fixture')
    data=d['scifact_rag/capstone_lab.json'];sample=data['samples'][0];word,ended=rag_word(sample,data['weights'],data['vocabulary']);selected=sample['cases']['retrieved']['pack']['selected'];corpus={str(r['doc_id']):r for r in [json.loads(line)for line in (ROOT/'scifact_rag/corpus.jsonl').read_text().splitlines()]}
    exact=all(' '.join(corpus[c['doc_id']]['abstract'][c['start']:c['end']])==c['text']for c in selected)
    if not selected or not exact or not ended or word not in('support','contradict'):return dict(base,status='ABSTAIN',served='no_answer',reason='provenance_or_format')
    return dict(base,served='tiny_response_decoder',reason='unverified_hypothesis',output=dict(hypothesis=word),citations=[f"[{c['doc_id']}:{c['start']}-{c['end']}]"for c in selected])
def analyse():
    x,y,groups,roles,names=load_spam();train=roles['train'];validation=roles['validation'];scaler=StandardScaler().fit(x[train]);z=scaler.transform(x[train]);model=LogisticRegression(C=1,solver='lbfgs',max_iter=2000,tol=1e-9,random_state=38).fit(z,y[train]);params=dict(version='spam38-logreg-v1',schema='spambase57-v1',fields=names,mean=scaler.mean_.tolist(),scale=scaler.scale_.tolist(),weights=model.coef_[0].tolist(),intercept=float(model.intercept_[0]),C=1.,fit_rows=len(train));scores=model.predict_proba(scaler.transform(x[validation]))[:,1]
    rows=[dict(index=int(i),features=x[i].tolist(),label=int(y[i]),score=float(p))for i,p in zip(validation,scores)];dependencies={name:digest(ROOT/name)for name in DEPENDENCIES};dependencies.update({'spambase/'+name:h for name,h in SPAM_HASHES.items()});cases=architecture_cases();lab=dict(report=dict(source='UCI Spambase(1999),CC BY4.0;frozen prior MovieLens/SciFact/Bike artifacts',source_sha256=SPAM_HASHES,source_rows=4601,unique_profiles=int(groups.max()+1),roles={k:len(v)for k,v in roles.items()},reserved_outcomes_scored=0,protocol='Feature-only exact-profile groups,GroupShuffleSplit38 then380,70/15/15 group targets;actual row counts differ. Train-only StandardScaler+fixed C1 LogisticRegression;no tuning/refit,validation is development,not fresh confirmation. Reserved test labels not fitted/scored/exported or used for policy selection. Partial source-specific features limit deployment generalization;no real fraud/traffic/latency/human-review/security evidence.'),dependencies=dependencies,cases=cases,spam=dict(model=params,roles={k:v.tolist()for k,v in roles.items()},groups=groups.tolist(),validation=rows,metrics={str(t):binary_metrics(rows,t)for t in (.2,.5,.8)},fit_iterations=int(model.n_iter_[0])),capacity={},policies={})
    lab['response_policies']=RESPONSE_POLICIES
    lab['manifests']={case:manifest(case,dependencies,lab['spam'])for case in CASE_IDS}
    for case in CASE_IDS:
        for qps in (100,1000,10000):
            for hit in (0.,.5,.9):
                for replicas in (1,4,16):
                    for scale in (.5,1.,2.):
                        for deadline in (50,100,250):lab['capacity'][':'.join(map(str,[case,qps,hit,replicas,scale,deadline]))]=capacity(cases[case],qps,hit,replicas,scale,deadline)
    for low in (.2,.4):
        for high in (.6,.8):
            for budget in (20,50,100):
                for overflow in ('defer','allow','block'):
                    for cost in (10,100):lab['policies'][':'.join(map(str,[low,high,budget,overflow,cost]))]=review_policy(rows,low,high,budget,overflow,cost)
    lab['responses']={case:{fault:response(lab,case,fault)for fault in ('none','model_mismatch','upstream')}for case in CASE_IDS};return lab
def export_bundle(directory,lab):
    out=Path(directory);out.mkdir(parents=True,exist_ok=True);contract=dict(spam_model_sha256=identity(lab['spam']['model']),dependencies=lab['dependencies'],manifests=lab['manifests'],reserved_outcomes_scored=0,scope='Real offline case replay;capacity/stage latency/cache/review budgets/faults authored assumptions,not production measurements')
    for name,data in [('design_lab.json',lab),('spam_model.json',lab['spam']['model']),('design_contract.json',contract)]:(out/name).write_text(payload(data),encoding='utf-8',newline='\n')
    (out/'SPAM_SOURCE.txt').write_bytes((ROOT/'spambase/spambase.DOCUMENTATION').read_bytes());(out/'MOVIELENS_SOURCE.txt').write_bytes((ROOT/'movielens/SOURCE_README.txt').read_bytes());(out/'ATTRIBUTION.txt').write_text('Spambase:Hopkins,Reeber,Forman,Suermondt(1999),UCI,CC BY4.0,https://doi.org/10.24432/C53G6X\nBike:Fanaee-T(2013),UCI,CC BY4.0,https://doi.org/10.24432/C5W894\nMovieLens:GroupLens,ml-latest-small,research-use terms in MOVIELENS_SOURCE.txt\nSciFact:Wadden et al.(2020),claims CC BY4.0,abstracts ODC-By1.0;prior source manifests retained in app.\nDerived local models/case replays identified separately;capacity,review and fault assumptions authored,no production claims.\n',encoding='utf-8')
    names=['design_lab.json','spam_model.json','design_contract.json','SPAM_SOURCE.txt','MOVIELENS_SOURCE.txt','ATTRIBUTION.txt'];(out/'checksums.json').write_text(payload({n:digest(out/n)for n in names}),encoding='utf-8')
def verify_bundle(directory):
    out=Path(directory);checks=json.loads((out/'checksums.json').read_text());names={'design_lab.json','spam_model.json','design_contract.json','SPAM_SOURCE.txt','MOVIELENS_SOURCE.txt','ATTRIBUTION.txt'}
    if set(checks)!=names:raise ValueError('Incomplete design bundle')
    for name,h in checks.items():
        if digest(out/name)!=h:raise ValueError('Checksum mismatch:'+name)
    lab=json.loads((out/'design_lab.json').read_text());model=json.loads((out/'spam_model.json').read_text());contract=json.loads((out/'design_contract.json').read_text())
    if not valid_spam_model(model)or model!=lab['spam']['model']or digest(out/'spam_model.json')!=contract['spam_model_sha256']or contract['dependencies']!=lab['dependencies']or contract['manifests']!=lab['manifests']or contract['reserved_outcomes_scored']!=0:raise ValueError('Design contract mismatch')
    for name,h in contract['dependencies'].items():
        if digest(ROOT/name)!=h:raise ValueError('Dependency source mismatch:'+name)
    if digest(out/'SPAM_SOURCE.txt')!=SPAM_HASHES['spambase.DOCUMENTATION']or digest(out/'MOVIELENS_SOURCE.txt')!=digest(ROOT/'movielens/SOURCE_README.txt'):raise ValueError('Source notice mismatch')
    return dict(verified=True,files=6,cases=5,validation_rows=len(lab['spam']['validation']))
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--write-lab',action='store_true');parser.add_argument('--artifact-dir',type=Path);parser.add_argument('--verify-dir',type=Path);args=parser.parse_args()
    if args.verify_dir:print(json.dumps(verify_bundle(args.verify_dir)));return
    lab=analyse()
    if args.write_lab:(DATA/'design_lab.json').write_text(payload(lab),encoding='utf-8',newline='\n')
    if args.artifact_dir:export_bundle(args.artifact_dir,lab)
    policy={k:v for k,v in review_policy(lab['spam']['validation']).items()if k not in ('routes','review_ids')}
    print(json.dumps({k:lab[k]for k in ['report','responses']},indent=2));print(json.dumps(dict(spam_metrics=lab['spam']['metrics'],default_policy=policy)))
if __name__=='__main__':main()
