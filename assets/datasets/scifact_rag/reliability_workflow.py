"""Frozen claim-prefix model audit and explicitly assumed serving replay.

Not generative-LLM factuality,medical verification or a device latency benchmark.
"""
from pathlib import Path
import argparse,hashlib,importlib.util,json,math
import numpy as np
import torch
HERE=Path(__file__).resolve().parent
THRESHOLDS=[.5,.6,.7,.8,.9,.95]
def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def validate(rows):
 if not rows or len({r['id'] for r in rows})!=len(rows):raise ValueError('Nonempty unique query rows')
 for r in rows:
  if type(r['gold']) is not int or r['gold'] not in [0,1] or not isinstance(r['p_support'],(int,float)) or isinstance(r['p_support'],bool) or not math.isfinite(r['p_support']) or not 0<=r['p_support']<=1:raise ValueError('Binary gold,finite probability0..1')
def selective(rows,threshold=.5):
 validate(rows)
 if isinstance(threshold,bool) or not isinstance(threshold,(int,float)) or not math.isfinite(threshold) or not .5<=threshold<=1:raise ValueError('Confidence threshold.5..1')
 accepted=[r for r in rows if max(r['p_support'],1-r['p_support'])>=threshold]
 correct=sum(int(r['p_support']>=.5)==r['gold'] for r in accepted)
 return {'threshold':threshold,'accepted':len(accepted),'correct':correct,'coverage':len(accepted)/len(rows),
         'accuracy':correct/len(accepted) if accepted else None,'risk':1-correct/len(accepted) if accepted else None}
def audit(rows,bins=5):
 validate(rows)
 if type(bins) is not int or not 1<=bins<=20:raise ValueError('Bins1..20')
 tp=tn=fp=fn=0;table=[{'index':i,'count':0,'correct':0,'confidence_sum':0.} for i in range(bins)]
 for r in rows:
  p=r['p_support'];pred=int(p>=.5);gold=r['gold'];confidence=max(p,1-p)
  tp+=int(pred==gold==1);tn+=int(pred==gold==0);fp+=int(pred==1 and gold==0);fn+=int(pred==0 and gold==1)
  bucket=table[min(int(confidence*bins),bins-1)];bucket['count']+=1;bucket['correct']+=int(pred==gold);bucket['confidence_sum']+=confidence
 ece=0.
 for b in table:
  b['accuracy']=b['correct']/b['count'] if b['count'] else None;b['mean_confidence']=b['confidence_sum']/b['count'] if b['count'] else None
  b['gap']=abs(b['accuracy']-b['mean_confidence']) if b['count'] else None
  if b['count']:ece+=b['count']/len(rows)*b['gap']
 eps=1e-15
 return {'queries':len(rows),'tp':tp,'tn':tn,'fp':fp,'fn':fn,'accuracy':(tp+tn)/len(rows),
         'support_recall':tp/(tp+fn) if tp+fn else None,'contradict_recall':tn/(tn+fp) if tn+fp else None,
         'precision':tp/(tp+fp) if tp+fp else None,
         'brier':sum((r['p_support']-r['gold'])**2 for r in rows)/len(rows),
         'binary_nll_clipped':sum(-math.log(max(eps,min(1-eps,r['p_support'] if r['gold'] else 1-r['p_support']))) for r in rows)/len(rows),
         'ece':ece,'bins':table,'sweep':[selective(rows,t) for t in THRESHOLDS]}
def replay(requests,batch_size=1,interval=5.,prefill=.4,decode=1.2,overhead=2.):
 if not requests or type(batch_size) is not int or not 1<=batch_size<=16 or any(isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(v) or v<0 for v in [interval,prefill,decode,overhead]):raise ValueError('Nonempty requests,batch1..16,finite nonnegative assumptions')
 if any(type(r['input_tokens']) is not int or not 1<=r['input_tokens']<=32 or type(r['output_tokens']) is not int or not 1<=r['output_tokens']<=8 for r in requests):raise ValueError('Token counts within declared tiny-model context')
 clock=0.;rows=[]
 for begin in range(0,len(requests),batch_size):
  group=requests[begin:begin+batch_size];arrivals=[(begin+i)*interval for i in range(len(group))]
  start=max(clock,arrivals[-1]);prefill_time=overhead+max(r['input_tokens'] for r in group)*prefill
  first=start+prefill_time+decode;finish=start+prefill_time+max(r['output_tokens'] for r in group)*decode
  for i,r in enumerate(group):rows.append({'id':r['id'],'arrival_ms':arrivals[i],'start_ms':start,'queue_ms':start-arrivals[i],'ttft_ms':first-arrivals[i],'latency_ms':finish-arrivals[i],'finish_ms':finish})
  clock=finish
 latencies=sorted(r['latency_ms'] for r in rows)
 def percentile(q):return latencies[max(0,math.ceil(q*len(latencies))-1)]
 return {'assumptions':{'batch_size':batch_size,'interval_ms':interval,'prefill_ms_per_input_token':prefill,'decode_ms_per_output_token':decode,'batch_overhead_ms':overhead,'scheduler':'consecutive fixed groups wait for last member;one serial worker;ideal padded batch compute'},
         'requests':len(rows),'makespan_ms':clock,'throughput_per_second':len(rows)*1000/clock if clock else None,
         'p50_ms':percentile(.5),'p95_ms':percentile(.95),'mean_ttft_ms':sum(r['ttft_ms'] for r in rows)/len(rows),'rows':rows}
def cache_key(query,model,corpus,prompt,permission,decoding):
 values=[query,model,corpus,prompt,permission,decoding]
 if any(not isinstance(v,str) or not v for v in values):raise ValueError('Six nonempty version/scope strings')
 return json.dumps(values,ensure_ascii=False,separators=(',',':'))
def workflow(root=HERE,output=None,artifact_dir=None,write_labs=False):
 root=Path(root);spec=importlib.util.spec_from_file_location('reliability_adaptation',root/'adaptation_workflow.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 asset_path=root/'adaptation_lab.json';asset=json.loads(asset_path.read_text());source=m.load_rows()['diagnostic'];lm=m.lm_module();threads=torch.get_num_threads()
 try:
  torch.set_num_threads(1)
  with torch.random.fork_rng(devices=[]):
   x,pos,targets=m.batch(source);variants={}
   for name in ['base','full','lora']:
    model=lm.ByteDecoder();model.load_state_dict({k:torch.tensor(v,dtype=torch.float64) for k,v in asset['weights'][name].items()});model.eval()
    with torch.no_grad():logits=model(x)[torch.arange(len(source)),pos][:,[83,67]];p=logits.softmax(-1)[:,0].tolist()
    rows=[{'id':q['id'],'text':q['text'],'gold':int(q['label']=='SUPPORT'),'p_support':probability,'input_tokens':len(m.prefix(q['text'])),'output_tokens':1} for q,probability in zip(source,p)]
    variants[name]={'rows':rows,'audit':audit(rows)}
   requests=[{'id':r['id'],'input_tokens':r['input_tokens'],'output_tokens':1} for r in variants['lora']['rows'][:40]]
   runs={str(size):replay(requests,batch_size=size) for size in [1,4,8]}
   report={'source':'Frozen Chapter25 SciFact claim-prefix predictions;188 already observed dev queries',
           'adaptation_asset_sha256':digest(asset_path),'source_claims_sha256':digest(root/'claims_dev.jsonl'),
           'positive_label':'SUPPORT','prediction_tie':'p_support>=.5 selects SUPPORT','ece_bins':5,
           'slices':{'all':188,'short_claims':sum(len(r['text'].encode('utf-8'))<=80 for r in variants['lora']['rows']),
                     'long_claims':sum(len(r['text'].encode('utf-8'))>80 for r in variants['lora']['rows'])},
           'variants':{name:value['audit'] for name,value in variants.items()},
           'replay':{name:{k:v for k,v in run.items() if k!='rows'} for name,run in runs.items()},
           'limits':['Tiny claim-prefix classifier,not a generative LLM,scientific verifier or medical tool.',
             'All dev predictions/labels already observed;threshold sweep and slices are diagnostics,not selection or fresh confirmation.',
             'Conditional S/C probabilities are not calibrated truth confidence;ECE depends on bins/samples and is not proof of calibration.',
             'Source papers/related claims and prefix collisions limit independence;no confidence interval or population guarantee.',
             'Queue replay uses actual40 source prefix/output lengths and assumed costs/arrival schedule,not device/network/GPU latency.',
             'Fixed-group ideal padded batching is a teaching scheduler,not continuous batching/PagedAttention implementation.',
             'Versioned cache-key demo has no production authorization,persistent cache,semantic cache or KV cache implementation.',
             'No executed LLM judge,prompt-injection attack benchmark,factuality or production reliability claim.']}
   lab={'report':report,'variants':variants,'requests':requests,'replay_runs':runs}
   if write_labs:(root/'reliability_lab.json').write_text(json.dumps(lab,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
   if output:
    p=Path(output);p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(report,indent=2)+'\n')
   if artifact_dir:
    p=Path(artifact_dir);p.mkdir(parents=True,exist_ok=True)
    for name,value in [('model_card.json',report),('golden.json',lab),('requests.json',requests)]: (p/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (p/'checksums.json').write_text(json.dumps({f.name:digest(f) for f in p.iterdir() if f.is_file() and f.name!='checksums.json'},indent=2)+'\n')
   return report
 finally:torch.set_num_threads(threads)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path);p.add_argument('--artifact-dir',type=Path);p.add_argument('--write-labs',action='store_true');a=p.parse_args();print(json.dumps(workflow(output=a.output,artifact_dir=a.artifact_dir,write_labs=a.write_labs),indent=2))
