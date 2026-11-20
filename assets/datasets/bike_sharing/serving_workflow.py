"""Chapter36: real local Ridge inference and explicitly scoped MLOps rehearsals.

First547 original Bike days only; final184 outcomes excluded. Real fit/diagnostics,
but arrival/label maturity/traffic routing/SLO durations are declared fixtures.
Optional HTTP lab binds127.0.0.1 only; installed Flutter app needs no API/server.
Default import/CLI preserves assets; --write-lab regenerates derived JSON.
"""
from pathlib import Path
import argparse,bisect,hashlib,importlib.util,json,math,threading
import numpy as np

DATA=Path(__file__).resolve().parent
FIELDS=['lag1','lag7','mean7']
PERIODS={'early':(365,455),'late':(456,546),'full':(365,546)}
SLO_DURATIONS=[18,22,25,40,35,60,80,95,110,25,70,130,45,20,200,30,85,90,150,15]
_SOURCE=None

def payload(value):return json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\n'
def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def source():
    global _SOURCE
    if _SOURCE is None:
        spec=importlib.util.spec_from_file_location('serving36source',DATA/'pipeline_workflow.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);_SOURCE=m
    return _SOURCE
def object_hash(value):return hashlib.sha256(payload(value).encode()).hexdigest()
def route_bucket(request_id):
    value=2166136261
    for byte in request_id.encode('utf-8'):value=((value^byte)*16777619)&0xffffffff
    return value%10000
def valid_model(model):
    if not isinstance(model.get('model_version'),str)or not model['model_version']:return False
    if model.get('kind')=='seasonal7':return model.get('input_fields')==['lag7']
    if model.get('kind')!='ridge'or model.get('input_fields')!=FIELDS:return False
    for key in ['weights','mean','scale']:
        values=model.get(key)
        if not isinstance(values,list)or len(values)!=3 or any(type(v)not in(int,float)or not math.isfinite(v)for v in values):return False
    return all(s>0 for s in model['scale'])and type(model.get('intercept'))in(int,float)and math.isfinite(model['intercept'])
def predict(model,features):
    if not valid_model(model):return None
    if any(type(features.get(key))not in(int,float)or not math.isfinite(features[key])for key in model['input_fields']):return None
    if model['kind']=='seasonal7':return float(features['lag7'])
    z=[(features[key]-mu)/scale for key,mu,scale in zip(model['input_fields'],model['mean'],model['scale'])]
    raw=model['intercept']+sum(w*x for w,x in zip(model['weights'],z))
    return max(0.,raw)
def make_manifest(model,definition):
    return dict(model_version=model['model_version'],model_sha256=object_hash(model),feature_definition_sha256=object_hash(definition),source_sha256=definition['source_sha256'],input_schema='|'.join(model['input_fields'])+':float-v1')
def contract_errors(expected,loaded):return [k for k in ['model_version','model_sha256','feature_definition_sha256','source_sha256','input_schema']if expected.get(k)!=loaded.get(k)]
def _serve(lab,target,scenario='on_time',canary_bp=10000,rollback=False,candidate_fault=False,baseline_fault=False):
    if type(target)is not int or not 365<=target<=546 or scenario not in ('on_time','late_fixture')or type(canary_bp)is not int or canary_bp not in (0,1000,5000,10000)or type(rollback)is not bool:raise ValueError('Unknown request/preset')
    m=source();request_id='bike-global:'+m.day_string(target);bucket=route_bucket(request_id)
    if not valid_model(lab['models']['baseline']):return dict(request_id=request_id,bucket=bucket,status='BLOCKED',served='none',prediction=None,reason='baseline_contract')
    expected=make_manifest(lab['models']['baseline'],lab['feature_definition']);loaded=dict(lab['manifests']['baseline'])
    if baseline_fault:loaded['model_sha256']='declared-incompatible-fixture'
    if contract_errors(expected,loaded):return dict(request_id=request_id,bucket=bucket,status='BLOCKED',served='none',prediction=None,reason='baseline_contract')
    features=m.features(lab['events'][scenario],target);baseline=predict(lab['models']['baseline'],features)
    if baseline is None:return dict(request_id=request_id,bucket=bucket,status='BLOCKED',served='none',prediction=None,reason='missing_baseline_feature')
    chosen=not rollback and bucket<canary_bp
    if not chosen:return dict(request_id=request_id,bucket=bucket,status='OK',served='baseline',prediction=baseline,reason='rollback'if rollback else'routed_baseline',features=features)
    if not valid_model(lab['models']['candidate']):return dict(request_id=request_id,bucket=bucket,status='OK',served='fallback',prediction=baseline,reason='candidate_contract',features=features)
    expected=make_manifest(lab['models']['candidate'],lab['feature_definition']);loaded=dict(lab['manifests']['candidate'])
    if candidate_fault:loaded['model_sha256']='declared-incompatible-fixture'
    if contract_errors(expected,loaded):return dict(request_id=request_id,bucket=bucket,status='OK',served='fallback',prediction=baseline,reason='candidate_contract',features=features)
    candidate=predict(lab['models']['candidate'],features)
    if candidate is None:return dict(request_id=request_id,bucket=bucket,status='OK',served='fallback',prediction=baseline,reason='missing_candidate_features',features=features)
    return dict(request_id=request_id,bucket=bucket,status='OK',served='candidate',prediction=candidate,reason='validated_candidate',features=features)
def serve(lab,target,scenario='on_time',canary_bp=10000,rollback=False,candidate_fault=False,baseline_fault=False):
    response=_serve(lab,target,scenario,canary_bp,rollback,candidate_fault,baseline_fault)
    key='candidate'if response['served']=='candidate'else'baseline'
    response['model_version']=lab['models'][key]['model_version']if response['status']=='OK'else None
    response['feature_version']=lab['feature_definition']['feature_version']
    return response
def replay(lab,scenario='on_time',canary_bp=10000,rollback=False,candidate_fault=False):
    rows=[serve(lab,t,scenario,canary_bp,rollback,candidate_fault)for t in range(365,547)]
    return dict(requests=len(rows),candidate=sum(r['served']=='candidate'for r in rows),baseline=sum(r['served']=='baseline'for r in rows),fallback=sum(r['served']=='fallback'for r in rows),blocked=sum(r['status']=='BLOCKED'for r in rows))
def quantile(values,p):
    x=sorted(values)
    if not x:return None
    h=(len(x)-1)*p;lo=math.floor(h);hi=math.ceil(h);return x[lo]+(x[hi]-x[lo])*(h-lo)
def slo_fixture(threshold=100,target=.99):
    rows=[dict(duration_ms=duration,ok=j not in (8,14))for j,duration in enumerate(SLO_DURATIONS)];n=len(rows);good=sum(r['ok']and r['duration_ms']<=threshold for r in rows);bad=n-good;allowed=n*(1-target);buckets=[dict(le=bound,count=sum(r['duration_ms']<=bound for r in rows))for bound in (25,50,100,200)]
    return dict(rows=rows,requests=n,good=good,bad=bad,availability=sum(r['ok']for r in rows)/n,composite_sli=good/n,allowed_bad=allowed,remaining_bad=allowed-bad,burn_rate=(bad/n)/(1-target),p95_all=quantile(SLO_DURATIONS,.95),p95_success=quantile([r['duration_ms']for r in rows if r['ok']],.95),histogram=buckets,threshold_ms=threshold,target=target,scope='AUTHORED duration/status arithmetic fixture,not local HTTP measurements or production telemetry')
def error_metrics(rows,model):
    if not rows:return dict(labels=0,mae=None,rmse=None,bias=None)
    errors=[r[model]-r['outcome']for r in rows];return dict(labels=len(rows),mae=sum(abs(e)for e in errors)/len(errors),rmse=math.sqrt(sum(e*e for e in errors)/len(errors)),bias=sum(errors)/len(errors))
def quality(rows,period='full',delay=0):
    start,end=PERIODS[period];selected=[r for r in rows if start<=r['target']<=end];clock=end+1;mature=[r for r in selected if r['target']+1+delay<=clock]
    return dict(request_rows=len(selected),mature_labels=len(mature),clock=clock,delay_days=delay,models={name:error_metrics(mature,name)for name in ['naive1','baseline','candidate']})
def psi(reference,observed,edges):
    k=len(edges)+1;ref=[0]*k;obs=[0]*k
    for value in reference:ref[bisect.bisect_right(edges,value)]+=1
    for value in observed:obs[bisect.bisect_right(edges,value)]+=1
    p=[(n+.5)/(len(reference)+.5*k)for n in ref];q=[(n+.5)/(len(observed)+.5*k)for n in obs];parts=[(b-a)*math.log(b/a)for a,b in zip(p,q)]
    return dict(reference_count=len(reference),observed_count=len(observed),edges=list(edges),reference_bins=ref,observed_bins=obs,reference_mass=p,observed_mass=q,contributions=parts,psi=sum(parts),smoothing=.5)
def analyse():
    m=source();events={name:m.scheduled(m.load(),name)for name in m.SCENARIOS};definition=m.definition();original=events['on_time'];train=[]
    for target in range(7,365):train.append(dict(target=target,features=m.features(original,target),outcome=original[target]['cnt']))
    x=np.array([[r['features'][key]for key in FIELDS]for r in train],dtype=np.float64);y=np.array([r['outcome']for r in train],dtype=np.float64);mean=x.mean(0);scale=x.std(0);scale[scale==0]=1.;z=(x-mean)/scale;intercept=float(y.mean());weights=np.linalg.solve(z.T@z+10*np.eye(3),z.T@(y-intercept))
    baseline=dict(kind='seasonal7',model_version='seasonal7-v1',input_fields=['lag7'])
    candidate=dict(kind='ridge',model_version='ridge36-v1',input_fields=FIELDS,mean=mean.tolist(),scale=scale.tolist(),weights=weights.tolist(),intercept=intercept,alpha=10.,objective='sum_squared_error+alpha*sum(w_squared);unpenalized intercept;fit standardized X;serving clips at0',train_targets=[7,364],fit_examples=len(train))
    models=dict(baseline=baseline,candidate=candidate);manifests={name:make_manifest(model,definition)for name,model in models.items()};rows=[]
    for target in range(365,547):
        f=m.features(original,target);rows.append(dict(target=target,date=m.day_string(target),features=f,outcome=original[target]['cnt'],naive1=float(f['lag1']),baseline=predict(baseline,f),candidate=predict(candidate,f)))
    monitoring={}
    for period,(start,end)in PERIODS.items():
        chosen=[r for r in rows if start<=r['target']<=end];monitoring[period]={}
        for j,key in enumerate(FIELDS):
            edges=sorted(set(float(v)for v in np.quantile(x[:,j],[.2,.4,.6,.8],method='linear')));monitoring[period][key]=psi(x[:,j].tolist(),[r['features'][key]for r in chosen],edges)
    lab=dict(report=dict(source_hashes={**m.SOURCE_HASHES,'pipeline_lab.json':digest(DATA/'pipeline_lab.json')},used_rows=547,reserved_outcomes_used=0,fit_examples=358,fit_target_range=[7,364],development_examples=182,development_target_range=[365,546],protocol='Fixed Ridgealpha10 recipe,fit-only standardization/intercept2011;no tuning/refit,rolling one-step Jan-Jun2012 with day-close availability assumption. Historical development already inspected,not fresh blind confirmation. Seasonal7 is a declared serving-demo baseline,not strongest assumed model;naive1 also reported. No GPU/ANN/real traffic/latency/causal online lift.'),feature_definition=definition,events=events,models=models,manifests=manifests,training=train,rows=rows,monitoring=monitoring,quality={period:{str(delay):quality(rows,period,delay)for delay in (0,2,7)}for period in PERIODS},slo=slo_fixture(),cases=[365,375,409,545])
    lab['rollouts']={scenario:{str(bp):replay(lab,scenario,bp)for bp in (0,1000,5000,10000)}for scenario in m.SCENARIOS};return lab
def export_bundle(directory,lab):
    directory=Path(directory);directory.mkdir(parents=True,exist_ok=True)
    files={'baseline_model.json':lab['models']['baseline'],'ridge_model.json':lab['models']['candidate'],'feature_definition.json':lab['feature_definition'],'serving_lab.json':lab}
    for name,value in files.items():(directory/name).write_text(payload(value),encoding='utf-8',newline='\n')
    (directory/'SOURCE_README.txt').write_bytes((DATA/'Readme.txt').read_bytes());(directory/'ATTRIBUTION.txt').write_text('Bike Sharing,Hadi Fanaee-T(2013),UCI,CC BY4.0\nhttps://doi.org/10.24432/C5W894\nhttps://creativecommons.org/licenses/by/4.0/\nOriginal first547 counts/dates;last184 outcomes unused. Arrival,label-delay,routing andSLO telemetry are explicitly authored fixtures. Model fit2011/historicalJan-Jun2012diagnostics.\n',encoding='utf-8',newline='\n')
    names=[*files,'SOURCE_README.txt','ATTRIBUTION.txt'];(directory/'checksums.json').write_text(payload({name:digest(directory/name)for name in names}),encoding='utf-8')
def verify_bundle(directory):
    directory=Path(directory);checks=json.loads((directory/'checksums.json').read_text());names={'baseline_model.json','ridge_model.json','feature_definition.json','serving_lab.json','SOURCE_README.txt','ATTRIBUTION.txt'}
    if set(checks)!=names:raise ValueError('Incomplete release bundle')
    for name,h in checks.items():
        if digest(directory/name)!=h:raise ValueError('Checksum mismatch:'+name)
    lab=json.loads((directory/'serving_lab.json').read_text(encoding='utf-8'));definition=json.loads((directory/'feature_definition.json').read_text(encoding='utf-8'))
    if definition!=lab['feature_definition']:raise ValueError('Definition mismatch')
    for key,file in [('baseline','baseline_model.json'),('candidate','ridge_model.json')]:
        if not valid_model(lab['models'][key]):raise ValueError('Invalid model schema')
        if contract_errors(make_manifest(lab['models'][key],definition),lab['manifests'][key]):raise ValueError('Release metadata mismatch')
        if digest(directory/file)!=lab['manifests'][key]['model_sha256']or json.loads((directory/file).read_text())!=lab['models'][key]or digest(directory/'feature_definition.json')!=lab['manifests'][key]['feature_definition_sha256']:raise ValueError('Release manifest mismatch')
    if digest(directory/'SOURCE_README.txt')!=source().SOURCE_HASHES['Readme.txt']:raise ValueError('Source notice mismatch')
    return dict(verified=True,files=len(checks),candidate='ridge36-v1',baseline='seasonal7-v1')

def make_http_server(lab,port=0):
    from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
    from urllib.parse import urlparse
    metrics=dict(requests=0,errors=0,fallbacks=0);lock=threading.Lock()
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args):pass
        def send_json(self,code,value):
            body=payload(value).encode();self.send_response(code);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
        def do_GET(self):
            path=urlparse(self.path).path
            if path=='/healthz':self.send_json(200,dict(status='alive'));return
            if path=='/readyz':
                ready=all(valid_model(lab['models'][k])and not contract_errors(make_manifest(lab['models'][k],lab['feature_definition']),lab['manifests'][k])for k in ('baseline','candidate'));self.send_json(200 if ready else 503,dict(ready=ready));return
            if path=='/metrics':
                with lock:body=('\n'.join('mlops_predict_'+k+'_total '+str(v)for k,v in metrics.items())+'\n').encode()
                self.send_response(200);self.send_header('Content-Type','text/plain; version=0.0.4');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body);return
            self.send_json(404,dict(error='unknown_path'))
        def do_POST(self):
            if urlparse(self.path).path!='/predict':self.send_json(404,dict(error='unknown_path'));return
            with lock:metrics['requests']+=1
            try:
                length=int(self.headers.get('Content-Length','0'))
                if not 0<length<=4096:raise ValueError('body_size')
                request=json.loads(self.rfile.read(length));allowed={'target','scenario','canary_bp','rollback'}
                if not isinstance(request,dict)or set(request)-allowed:raise ValueError('request_schema')
                if 'rollback'in request and type(request['rollback'])is not bool:raise ValueError('rollback_type')
                response=serve(lab,**request)
            except (ValueError,TypeError,KeyError):
                with lock:metrics['errors']+=1
                self.send_json(400,dict(error='invalid_request'));return
            with lock:
                metrics['fallbacks']+=response['served']=='fallback';metrics['errors']+=response['status']=='BLOCKED'
            self.send_json(200 if response['status']=='OK'else 503,response)
    server=ThreadingHTTPServer(('127.0.0.1',port),Handler);server.daemon_threads=True;return server
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--write-lab',action='store_true');parser.add_argument('--artifact-dir',type=Path);parser.add_argument('--verify-dir',type=Path);parser.add_argument('--bundle',type=Path);parser.add_argument('--serve',action='store_true');parser.add_argument('--port',type=int,default=8765);args=parser.parse_args()
    if args.verify_dir:print(json.dumps(verify_bundle(args.verify_dir)));return
    if args.bundle:verify_bundle(args.bundle);lab=json.loads((args.bundle/'serving_lab.json').read_text(encoding='utf-8'))
    else:lab=analyse()
    if args.write_lab:(DATA/'serving_lab.json').write_text(payload(lab),encoding='utf-8')
    if args.artifact_dir:export_bundle(args.artifact_dir,lab)
    if args.serve:
        server=make_http_server(lab,args.port);print(json.dumps(dict(host=server.server_address[0],port=server.server_address[1],scope='loopback demo only,not production server')),flush=True)
        try:server.serve_forever(poll_interval=.1)
        except KeyboardInterrupt:pass
        finally:server.server_close()
        return
    print(json.dumps(dict(report=lab['report'],models=lab['models'],quality=lab['quality']['full'],rollouts=lab['rollouts'],psi={p:{f:d['psi']for f,d in values.items()}for p,values in lab['monitoring'].items()},slo={k:v for k,v in lab['slo'].items()if k!='rows'}),indent=2))
if __name__=='__main__':main()
