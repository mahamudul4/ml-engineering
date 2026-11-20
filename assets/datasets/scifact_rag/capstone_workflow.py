"""Chapter29: real retrieval, tiny response-word generation and provenance audit.

No pretrained LLM. Decoder generates support/contradict letter-by-letter with EOS;
quotes are copied exactly, not generated. Hypotheses are NOT scientific verdicts.
"""
from pathlib import Path
from collections import Counter
import argparse,hashlib,importlib.util,json,math,platform,re
import numpy as np
import torch
from torch import nn
import torch.nn.functional as F
from threadpoolctl import threadpool_limits
HERE=Path(__file__).resolve().parent
VOCAB=['<PAD>','<BOS>','<EOS>']+sorted(set('supportcontradict'))
PAD,BOS,EOS=0,1,2

def rag_module():
 s=importlib.util.spec_from_file_location('capstone_rag',HERE/'rag_workflow.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def bucket(word):
 h=2166136261
 for b in word.encode('ascii'):h=((h^b)*16777619)&0xffffffff
 return h%128
def block_features(text):
 counts=Counter(bucket(t.lower()) for t in re.findall(r'[A-Za-z0-9]+',text));x=np.zeros(128)
 for i,n in counts.items():x[i]=math.log1p(n)
 norm=np.linalg.norm(x)
 return x/norm if norm else x
def features(query,context):return np.r_[block_features(query),block_features(context)]
def plain_context(run):return '\n'.join(c['text'] for c in run['selected'])

class ResponseDecoder(nn.Module):
 def __init__(self):
  super().__init__();self.condition=nn.Linear(256,16,dtype=torch.float64);self.embedding=nn.Embedding(len(VOCAB),8,dtype=torch.float64);self.cell=nn.GRUCell(8,16,dtype=torch.float64);self.head=nn.Linear(16,len(VOCAB),dtype=torch.float64)
 def initial(self,x):return self.condition(x).tanh()
 def step(self,token,h):
  h=self.cell(self.embedding(token),h);logits=self.head(h).clone();logits[:,:2]=-torch.inf
  return logits,h
 def forward(self,x,previous):
  h=self.initial(x);out=[]
  for t in range(previous.shape[1]):
   logits,h=self.step(previous[:,t],h);out.append(logits)
  return torch.stack(out,1)

def decode(model,x):
 with torch.no_grad():
  h=model.initial(torch.as_tensor(np.asarray(x,dtype=np.float64)[None,:]));initial=h[0].tolist();token=BOS;ids=[];trace=[]
  for _ in range(12):
   logits,h=model.step(torch.tensor([token]),h);p=logits.softmax(-1)[0];n=int(p.argmax());ids.append(n);trace.append(dict(previous=token,chosen=n,probabilities=p.tolist(),hidden=h[0].tolist()));token=n
   if n==EOS:break
  ended=bool(ids and ids[-1]==EOS);text=''.join(VOCAB[i] for i in ids if i>=3);valid=ended and text in ['support','contradict']
  return dict(text=text,ended=ended,format_valid=valid,first_token_confidence=max(trace[0]['probabilities']),ids=ids,initial_hidden=initial,trace=trace)

def policy(generation,quotes_exact,has_context,threshold=0.):
 if not math.isfinite(threshold) or not 0<=threshold<=1:raise ValueError('Threshold0..1')
 reason='no_context' if not has_context else 'citation_mismatch' if not quotes_exact else 'invalid_format' if not generation['format_valid'] else 'low_confidence' if generation['first_token_confidence']<threshold else None
 return dict(emitted=reason is None,reason=reason or 'unverified_hypothesis')

def summarize(rows,threshold=0.):
 accepted=[r for r in rows if policy(r['generation'],True,r['has_context'],threshold)['emitted']]
 correct=sum(r['generation']['format_valid'] and r['generation']['text']==r['gold'] for r in rows)
 accepted_correct=sum(r['generation']['text']==r['gold'] for r in accepted)
 return dict(n=len(rows),valid=sum(r['generation']['format_valid'] for r in rows),correct=correct,accuracy=correct/len(rows),complete_rationale_hits=sum(r['rationale_hit'] for r in rows),joint_hits=sum(r['rationale_hit'] and r['generation']['format_valid'] and r['generation']['text']==r['gold'] for r in rows),accepted=len(accepted),coverage=len(accepted)/len(rows),accepted_accuracy=accepted_correct/len(accepted) if accepted else None,accepted_risk=1-accepted_correct/len(accepted) if accepted else None)

def prepare(system,roles,rag):
 out={}
 for role in ['train','test']:
  rows=[]
  for q in sorted((q for q in roles[role] if q['evidence']),key=lambda q:q['id']):
   labels={ann['label'] for anns in q['evidence'].values() for ann in anns};assert len(labels)==1
   run=system.run(q['claim']);metric=rag.evidence_metrics(run,q['evidence'],{i for i,_ in run['retrieved']})
   rows.append(dict(id=str(q['id']),text=q['claim'],gold='support' if next(iter(labels))=='SUPPORT' else 'contradict',context=plain_context(run),rationale_hit=metric['complete_rationale_hit'],has_context=bool(run['selected']),run=run,evidence=q['evidence']))
  out[role]=rows
 assert [len(out[k]) for k in ['train','test']]==[505,188]
 return out

def analyse(artifact_dir=None):
 rag=rag_module();threads=torch.get_num_threads()
 try:
  torch.set_num_threads(1)
  with threadpool_limits(1):system,roles,index_dir=rag.load_inputs();rows=prepare(system,roles,rag)
  with torch.random.fork_rng(devices=[]):
   torch.manual_seed(29);model=ResponseDecoder();rng=torch.Generator().manual_seed(290)
   fit=rows['train'];x=torch.tensor(np.array([features(r['text'],r['context']) for r in fit]),dtype=torch.float64)
   targets=[[VOCAB.index(c) for c in r['gold']]+[EOS] for r in fit];width=max(map(len,targets));target=torch.tensor([t+[PAD]*(width-len(t)) for t in targets]);previous=torch.tensor([[BOS]+t[:-1]+[PAD]*(width-len(t)) for t in targets])
   opt=torch.optim.AdamW(model.parameters(),lr=.005,weight_decay=0.,foreach=False);history=[]
   for epoch in range(60):
    total=tokens=0
    for b in torch.randperm(len(fit),generator=rng).split(64):
     opt.zero_grad(set_to_none=True);logits=model(x[b],previous[b]);loss=F.cross_entropy(logits.reshape(-1,len(VOCAB)),target[b].reshape(-1),ignore_index=PAD);loss.backward();torch.nn.utils.clip_grad_norm_(model.parameters(),1.);opt.step();n=int((target[b]!=PAD).sum());total+=loss.item()*n;tokens+=n
    history.append(dict(epoch=epoch+1,response_token_nll=total/tokens))
   variants={};diagnostic=rows['test']
   for mode in ['retrieved','query_only','rotated_context']:
    cases=[]
    for i,r in enumerate(diagnostic):
     ctx=r['context'] if mode=='retrieved' else '' if mode=='query_only' else diagnostic[(i+1)%len(diagnostic)]['context']
     g=decode(model,features(r['text'],ctx));g={k:v for k,v in g.items() if k not in ['trace','initial_hidden']}
     cases.append(dict(id=r['id'],gold=r['gold'],generation=g,has_context=r['has_context'],rationale_hit=r['rationale_hit']))
    variants[mode]=dict(rows=cases,summary=summarize(cases),strict=summarize(cases,.9))
   samples=[]
   for role in ['train','test']:
    for r in rows[role][:3]:
     cases={}
     for mode,budget in [('retrieved',1024),('empty_budget',0),('query_only',1024)]:
      run=system.run(r['text'],budget=budget);context='' if mode=='query_only' else plain_context(run);g=decode(model,features(r['text'],context))
      cases[mode]=dict(features=features(r['text'],context).tolist(),generation=g,decision=policy(g,all(rag.audit_quote(c,system.source)['exact_quote'] for c in run['selected']),bool(run['selected'])),context=context,pack=dict(context=run['context'],used_bytes=run['used_bytes'],selected=run['selected']))
     samples.append(dict(id=r['id'],role=role,text=r['text'],gold=r['gold'],evidence=r['evidence'],cases=cases))
   weights={k:v.detach().tolist() for k,v in model.state_dict().items()}
   protocol=dict(candidate_documents=10,chunk_sentences=2,overlap=1,formatted_context_utf8_bytes=1024,max_passages=3,minimum_lexical_score=.05,features='FNV1a32 unsigned modulo128,log1p bucket counts,L2 per query/context block;concatenate256',decoder='condition256->16 tanh,embedding14x8,GRUCell8->16,head16->14;PAD/BOS logits excluded',max_generated_tokens=12,response='support or contradict letters plus EOS;greedy,not forced valid verbalizer',policy='nonempty packed source,exact quotes,valid EOS word,first-token confidence>=threshold;output always unverified hypothesis',threshold=0.,strict_illustration=.9,roles='505 train/188 annotated dev,previously observed;no fresh confirmation',seed=29,shuffle_seed=290,epochs=60,updates=480,batch_size=64,lr=.005,weight_decay=0.,clip=1.,loss='teacher-forced response-only legal-token CE,ignore right PAD,mean valid tokens')
   report=dict(source='SciFact Wadden et al.2020;claims/annotations CC BY4.0,abstracts ODC-By1.0',protocol=protocol,source_sha256=digest(HERE/'corpus.jsonl'),index_sha256=digest(index_dir/'retrieval_index.json'),train_sha256=digest(HERE/'claims_train.jsonl'),diagnostic_sha256=digest(HERE/'claims_dev.jsonl'),weights_sha256=hashlib.sha256(json.dumps(weights,sort_keys=True,separators=(',',':')).encode()).hexdigest(),parameters=sum(p.numel() for p in model.parameters()),fit_count=505,diagnostic_count=188,majority_accuracy=sum(r['gold']=='support' for r in diagnostic)/188,variants={k:dict(summary=v['summary'],strict=v['strict']) for k,v in variants.items()},torch=torch.__version__,python=platform.python_version(),dtype='float64 CPU',limits=['Small task-specific decoder is not a pretrained LLM,chatbot,free-form answer generator or scientific verifier.','Quotes are copied source provenance,not generated evidence or entailment proof.','Gold rationales/labels enter targets or diagnostics only,not retrieval,context features or runtime gate.','Query-only and cyclic mismatched-context are frozen-model controls,not separately trained fair-budget baselines or causal proof.','Rationale hit for controls records the original retrieved pack,not rotated decoder input;joint hit is a descriptive original-pack diagnostic.','Missing annotations excluded,not labeled false/unanswerable. Already observed roles,shared sources and2 exact full-role repeated claims limit independence.','First-token max confidence is uncalibrated,not sequence correctness or truth probability;thresholds not selected on diagnostic data.','No latency/hardware benchmark,prompt-injection resistance,clinical use or generative factuality certification.'])
   result=dict(report=report,vocabulary=VOCAB,weights=weights,history=history,variants=variants,samples=samples)
   if artifact_dir:
    out=Path(artifact_dir);out.mkdir(parents=True,exist_ok=True);torch.save(model.state_dict(),out/'response_decoder.pt')
    for name,value in [('model_card.json',report),('protocol.json',protocol),('golden.json',samples)]: (out/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (out/'checksums.json').write_text(json.dumps({p.name:digest(p) for p in out.iterdir() if p.is_file() and p.name!='checksums.json'},indent=2)+'\n')
   return result
 finally:torch.set_num_threads(threads)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--write-labs',action='store_true');p.add_argument('--artifact-dir',type=Path);a=p.parse_args();r=analyse(a.artifact_dir)
 if a.write_labs:(HERE/'capstone_lab.json').write_text(json.dumps(r,ensure_ascii=False,separators=(',',':'),allow_nan=False)+'\n',encoding='utf-8')
 print(json.dumps(r['report'],indent=2))
