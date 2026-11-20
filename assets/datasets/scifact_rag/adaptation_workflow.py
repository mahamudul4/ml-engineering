"""Tiny decoder full/head-LoRA response-token adaptation on real SciFact labels.

Claim-prefix-only diagnostic; no evidence verification,chat or instruction model.
Base is the fixed Chapter22 Alice byte decoder. No model/data downloads.
"""
from pathlib import Path
import argparse,copy,hashlib,importlib.util,json,math
import numpy as np
import torch
from torch import nn
from torch.nn import functional as F
HERE=Path(__file__).resolve().parent
RECIPE={'seed':25,'epochs':12,'batch_size':64,'lr':.01,'weight_decay':0.,'clip':1.,
        'rank':2,'alpha':2,'target':'head.weight only for LoRA;head.bias frozen',
        'prefix':'[BOS]+first24 raw UTF8 claim bytes+newline;right PAD to26',
        'response':'single ASCII S(83) or C(67);only final valid prefix position supervised',
        'prediction':'argmax restricted to S/C,not unconstrained generation',
        'roles':'annotated train queries excluding exact claim texts present in dev;dev diagnostic only',
        'no_evidence_input':True,'selection':'fixed12 epochs;no best epoch/seed/rank search'}
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def lm_module(root=HERE):
 p=Path(root).parent/'alice/llm_workflow.py';s=importlib.util.spec_from_file_location('adaptation_byte_lm',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def load_rows(root=HERE):
 root=Path(root);rows={}
 for role,file in [('train','claims_train.jsonl'),('diagnostic','claims_dev.jsonl')]:
  selected=[]
  for q in map(json.loads,(root/file).read_text().splitlines()):
   if not q['evidence']:continue
   labels={a['label'] for anns in q['evidence'].values() for a in anns};assert len(labels)==1
   selected.append({'id':str(q['id']),'text':q['claim'],'label':next(iter(labels))})
  rows[role]=selected
 seen={q['text'] for q in rows['diagnostic']};rows['excluded_train_ids']=[q['id'] for q in rows['train'] if q['text'] in seen]
 rows['train']=[q for q in rows['train'] if q['text'] not in seen]
 return rows
def prefix(text):
 if not isinstance(text,str):raise ValueError('Claim string required')
 return [257]+list(text.encode('utf-8')[:24])+[10]
def batch(rows):
 sequences=[prefix(q['text']) for q in rows]
 x=torch.tensor([s+[256]*(26-len(s)) for s in sequences],dtype=torch.long)
 positions=torch.tensor([len(s)-1 for s in sequences]);targets=torch.tensor([83 if q['label']=='SUPPORT' else 67 for q in rows])
 return x,positions,targets
def response_loss(logits,positions,targets):
 if logits.ndim!=3 or logits.shape[-1]!=259 or positions.shape!=targets.shape or positions.numel()!=logits.shape[0]:raise ValueError('Aligned response positions/targets')
 if not torch.isfinite(logits).all() or not ((targets==83)|(targets==67)).all() or (positions<0).any() or (positions>=logits.shape[1]).any():raise ValueError('Finite logits,valid positions,S/C labels')
 selected=logits[torch.arange(len(targets)),positions].clone();selected[:,256:258]=-torch.inf
 return F.cross_entropy(selected,targets)
class LoRAHead(nn.Module):
 def __init__(self,head,rank=2,alpha=2):
  super().__init__()
  if type(rank) is not int or rank<1 or rank>8 or not math.isfinite(alpha) or alpha<=0:raise ValueError('Rank1..8,alpha>0')
  self.base=head;self.rank=rank;self.alpha=alpha
  self.A=nn.Parameter(torch.randn(rank,8,dtype=torch.float64)*.02)
  self.B=nn.Parameter(torch.zeros(259,rank,dtype=torch.float64))
  for p in self.base.parameters():p.requires_grad=False
 def forward(self,x):return self.base(x)+(x@self.A.T)@self.B.T*(self.alpha/self.rank)
 def merged(self):return self.base.weight.detach()+(self.B@self.A).detach()*(self.alpha/self.rank)
def quantize(matrix):
 x=torch.as_tensor(matrix,dtype=torch.float64)
 if x.ndim!=2 or not torch.isfinite(x).all():raise ValueError('Finite matrix')
 scale=x.abs().amax(dim=1,keepdim=True)/127;scale=torch.where(scale>0,scale,torch.ones_like(scale))
 codes=(x/scale).round().clamp(-127,127).to(torch.int8)
 return codes,scale,codes.double()*scale
def evaluate(model,rows):
 x,pos,target=batch(rows);model.eval()
 with torch.no_grad():
  logits=model(x);chosen=logits[torch.arange(len(rows)),pos];binary=chosen[:,[83,67]]
  probs=binary.softmax(-1);pred=binary.argmax(-1);gold=(target==67).long()
  # Raw259-class masked CE is separate from two-verbalizer conditional probability.
  return {'response_nll':response_loss(logits,pos,target).item(),'accuracy':(pred==gold).double().mean().item(),
          'support_predictions':int((pred==0).sum()),'contradict_predictions':int((pred==1).sum())}
def workflow(root=HERE,output=None,artifact_dir=None,write_labs=False):
 root=Path(root);lm=lm_module(root);base_asset=root.parent/'alice/llm_lab.json';raw=json.loads(base_asset.read_text());rows=load_rows(root)
 threads=torch.get_num_threads()
 try:
  torch.set_num_threads(1)
  with torch.random.fork_rng(devices=[]):
   torch.manual_seed(25);base=lm.ByteDecoder();base.load_state_dict({k:torch.tensor(v,dtype=torch.float64) for k,v in raw['weights'].items()});base.eval()
   states={};reports={};histories={};models={'base':copy.deepcopy(base)}
   train=rows['train'];x,pos,targets=batch(train)
   for mode in ['full','lora']:
    torch.manual_seed(25);model=copy.deepcopy(base)
    if mode=='lora':
     for p in model.parameters():p.requires_grad=False
     model.head=LoRAHead(model.head)
    optimizer=torch.optim.AdamW([p for p in model.parameters() if p.requires_grad],lr=.01,weight_decay=0.,foreach=False)
    rng=torch.Generator().manual_seed(250);history=[]
    for epoch in range(13):
     history.append({'epoch':epoch,'train':evaluate(model,train)})
     if epoch==12:break
     model.train()
     for indices in torch.randperm(len(train),generator=rng).split(64):
      optimizer.zero_grad(set_to_none=True);loss=response_loss(model(x[indices]),pos[indices],targets[indices]);loss.backward();nn.utils.clip_grad_norm_([p for p in model.parameters() if p.requires_grad],1.,error_if_nonfinite=True);optimizer.step()
    trainable=sum(p.numel() for p in model.parameters() if p.requires_grad)
    if mode=='lora':
     adapter={'A':model.head.A.detach().tolist(),'B':model.head.B.detach().tolist(),'rank':2,'alpha':2}
     merged=copy.deepcopy(base);merged.head.weight.data.copy_(model.head.merged());models['lora']=merged
     with torch.no_grad():torch.testing.assert_close(model(x[:3]),merged(x[:3]),atol=1e-12,rtol=1e-12)
    else:models['full']=model
    histories[mode]=history;reports[mode]={'trainable_parameters':trainable,'total_parameters':sum(p.numel() for p in model.parameters()),'train':evaluate(model,train),'diagnostic':evaluate(model,rows['diagnostic'])}
   reports['base']={'trainable_parameters':0,'total_parameters':5019,'train':evaluate(base,train),'diagnostic':evaluate(base,rows['diagnostic'])}
   for mode in ['base','full','lora']:states[mode]={k:v.detach().tolist() for k,v in models[mode].state_dict().items()}
   codes,scales,dequant=quantize(models['lora'].head.weight.detach());quant=copy.deepcopy(models['lora']);quant.head.weight.data.copy_(dequant)
   models['int8_head_demo']=quant;states['int8_head_demo']={k:v.detach().tolist() for k,v in quant.state_dict().items()}
   reports['int8_head_demo']={'diagnostic':evaluate(quant,rows['diagnostic']),'max_weight_error':float((dequant-models['lora'].head.weight).abs().max()),'codes_bytes':codes.numel(),'scales_float64_bytes':scales.numel()*8,'original_head_float64_bytes':259*8*8}
   majority=max(['SUPPORT','CONTRADICT'],key=lambda label:sum(q['label']==label for q in train))
   report={'recipe':RECIPE,'base_asset_sha256':digest(base_asset),'train_queries':len(train),'diagnostic_queries':len(rows['diagnostic']),'excluded_train_ids':rows['excluded_train_ids'],
     'class_counts':{role:{label:sum(q['label']==label for q in rows[role]) for label in ['SUPPORT','CONTRADICT']} for role in ['train','diagnostic']},
     'train_majority_label':majority,'majority_diagnostic_accuracy':sum(q['label']==majority for q in rows['diagnostic'])/len(rows['diagnostic']),
     'runs':reports,'limits':['Tiny5019-parameter Alice decoder is not a large pretrained LLM.',
      'Real SciFact labels,first24 claim bytes only,no evidence text;not a fact verifier or instruction assistant.',
      'Claim-prefix may cut UTF8;byte model accepts IDs,display replacement is not text repair.',
      'Response loss uses all257 legal output classes;reported label probabilities condition only on S/C.',
      'Dev already observed in Chapters23/24,shared documents/related claims remain;diagnostic,not fresh confirmation.',
      'Exact full-text overlap excluded from training;distinct claims may still share24-byte prefixes.',
      'Fixed12epochs,shared base/order,head-only LoRA rank2/alpha2;no search or best checkpoint selection.',
      'Int8 rowwise output-head round/dequant demonstration,not QLoRA,NF4 or native quantized kernels.',
      'Trainable counts are not measured peak memory/latency;full model/activations still needed.',
      'No RAG evidence verification,Bangla/chat/factuality/instruction-following or production utility claim.']}
   samples=[]
   for role in ['train','diagnostic']:
    for q in rows[role][:3]:
     ids=prefix(q['text']);references={}
     for name,model in models.items():
      with torch.no_grad():trace=model.inspect(torch.tensor([ids]));logits=trace['logits'][0,-1];p=logits[[83,67]].softmax(0)
      references[name]={'normalized':trace['normalized'][0,-1].tolist(),'logits':logits.tolist(),'conditional_support_probability':p[0].item(),'prediction':'SUPPORT' if p[0]>=p[1] else 'CONTRADICT'}
     samples.append({**q,'role':role,'ids':ids,'references':references})
   asset={'report':report,'weights':states,'adapter':adapter,'quantization':{'codes':codes.tolist(),'scales':scales[:,0].tolist()},'history':histories,'samples':samples}
   if write_labs:(root/'adaptation_lab.json').write_text(json.dumps(asset,indent=2)+'\n')
   if output:
    path=Path(output);path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(report,indent=2)+'\n')
   if artifact_dir:
    dest=Path(artifact_dir);dest.mkdir(parents=True,exist_ok=True)
    for name,value in [('model_card.json',report),('golden.json',samples),('adapter.json',adapter),('weights.json',states)]: (dest/name).write_text(json.dumps(value,indent=2)+'\n')
    torch.save(models['full'].state_dict(),dest/'full.pt');torch.save(models['lora'].state_dict(),dest/'lora_merged.pt')
    (dest/'checksums.json').write_text(json.dumps({p.name:digest(p) for p in dest.iterdir() if p.is_file() and p.name!='checksums.json'},indent=2)+'\n')
   return report
 finally:torch.set_num_threads(threads)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path);p.add_argument('--artifact-dir',type=Path);p.add_argument('--write-labs',action='store_true');a=p.parse_args();print(json.dumps(workflow(output=a.output,artifact_dir=a.artifact_dir,write_labs=a.write_labs),indent=2))
