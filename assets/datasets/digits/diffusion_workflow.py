"""Chapter28 offline DDPM noise training, deterministic DDIM and label alignment.

UCI digits, existing Chapter18 roles. Label-name lookup baseline is NOT CLIP
or a natural-language encoder. Default import/CLI never modifies bundled files.
"""
from pathlib import Path
import argparse,hashlib,importlib.util,json,math,platform
import numpy as np
import torch
from torch import nn
import torch.nn.functional as F
DATA=Path(__file__).resolve().parent
T=32
NAMES=['zero','one','two','three','four','five','six','seven','eight','nine']

def source():
 spec=importlib.util.spec_from_file_location('chapter28_source',DATA/'generative_workflow.py')
 m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 return m.source()

def schedule():
 t=torch.arange(T+1,dtype=torch.float64)/T
 f=torch.cos((t+.008)/1.008*math.pi/2).square();bar=f/f[0]
 beta=(1-bar[1:]/bar[:-1]).clamp(max=.999)
 return beta,torch.cat([torch.ones(1,dtype=torch.float64),(1-beta).cumprod(0)])

def time_features(t):
 angle=t.to(torch.float64)/T*math.pi
 return torch.stack([angle.sin(),angle.cos(),(2*angle).sin(),(2*angle).cos()],-1)

class Denoiser(nn.Module):
 def __init__(self):
  super().__init__();self.first=nn.Linear(79,64,dtype=torch.float64);self.hidden=nn.Linear(64,64,dtype=torch.float64);self.out=nn.Linear(64,64,dtype=torch.float64)
 def forward(self,x,t,label):
  c=F.one_hot(label,11).to(torch.float64)
  h=torch.cat([x,time_features(t),c],-1)
  return self.out(F.silu(self.hidden(F.silu(self.first(h)))))

class Alignment(nn.Module):
 def __init__(self):
  super().__init__();self.image=nn.Linear(64,32,dtype=torch.float64);self.project=nn.Linear(32,8,dtype=torch.float64);self.names=nn.Embedding(10,8,dtype=torch.float64)
 def images(self,x):return F.normalize(self.project(F.relu(self.image(x))),dim=-1)
 def texts(self,ids):return F.normalize(self.names(ids),dim=-1)
 def forward(self,x,ids,tau=.1):return self.images(x)@self.texts(ids).T/tau

def multipositive_loss(logits,labels):
 mask=labels[:,None]==labels[None,:]
 positive=logits.masked_fill(~mask,-torch.inf)
 return .5*((logits.logsumexp(1)-positive.logsumexp(1)).mean()+(logits.logsumexp(0)-positive.logsumexp(0)).mean())

def corrupt(x,epsilon,t,bar):
 a=bar[t].unsqueeze(-1)
 return a.sqrt()*x+(1-a).sqrt()*epsilon

def ddim_step(x,epsilon,a,previous):
 # Fixed policy: clip x0 to [-1,1], retain original epsilon in direction term.
 x0=((x-math.sqrt(1-a)*epsilon)/math.sqrt(a)).clamp(-1,1)
 return math.sqrt(previous)*x0+math.sqrt(1-previous)*epsilon

def sample(model,initial,label,guidance,steps,bar):
 if steps not in [8,32] or label not in range(10) or not math.isfinite(guidance) or not 0<=guidance<=4:raise ValueError('steps8/32,label0..9,guidance0..4')
 times=np.rint(np.linspace(T,1,steps)).astype(int).tolist();x=initial.clone();trace=[dict(t=T,pixels=x[0].tolist())]
 with torch.no_grad():
  for i,t in enumerate(times):
   ts=torch.tensor([t]);cond=model(x,ts,torch.tensor([label]));null=model(x,ts,torch.tensor([10]));eps=null+guidance*(cond-null)
   prev=times[i+1] if i+1<len(times) else 0
   x=ddim_step(x,eps,bar[t].item(),bar[prev].item());trace.append(dict(t=prev,pixels=x[0].tolist()))
 return trace

def weights(model):return {k:v.detach().tolist() for k,v in model.state_dict().items()}

def analyse(artifact_dir=None):
 raw,labels,fit,diag=source();unit=torch.tensor(raw.reshape(-1,64),dtype=torch.float64)/16;clean=2*unit-1;y=torch.tensor(labels)
 beta,bar=schedule();old=torch.get_num_threads()
 try:
  torch.set_num_threads(1)
  with torch.random.fork_rng(devices=[]):
   torch.manual_seed(28);d=Denoiser();align=Alignment();rng=torch.Generator().manual_seed(280)
   opt=torch.optim.Adam(d.parameters(),lr=.002,foreach=False);ao=torch.optim.Adam(align.parameters(),lr=.003,foreach=False)
   dh=[];ah=[]
   for epoch in range(120):
    total=0.
    for batch in torch.randperm(len(fit),generator=rng).split(128):
     ids=fit[batch.numpy()];x=clean[ids];n=len(x);ts=torch.randint(1,T+1,(n,),generator=rng);eps=torch.randn(n,64,generator=rng,dtype=torch.float64)
     cond=y[ids].clone();cond[torch.rand(n,generator=rng)<.15]=10
     opt.zero_grad(set_to_none=True);pred=d(corrupt(x,eps,ts,bar),ts,cond);loss=F.mse_loss(pred,eps);loss.backward();opt.step();total+=loss.item()*n
    dh.append(dict(epoch=epoch+1,noise_mse=total/len(fit)))
   for epoch in range(50):
    total=0.
    for batch in torch.randperm(len(fit),generator=rng).split(128):
     ids=fit[batch.numpy()];ao.zero_grad(set_to_none=True);loss=multipositive_loss(align(unit[ids],y[ids]),y[ids]);loss.backward();ao.step();total+=loss.item()*len(ids)
    ah.append(dict(epoch=epoch+1,multipositive_loss=total/len(fit)))
   samples=[];diagnostic=[];ids=[int(next(i for i in diag if labels[i]==digit)) for digit in range(10)]
   erng=torch.Generator().manual_seed(282)
   with torch.no_grad():
    for t in [8,24,32]:
     ts=torch.full((len(diag),),t,dtype=torch.long);eps=torch.randn(len(diag),64,generator=erng,dtype=torch.float64);xt=corrupt(clean[diag],eps,ts,bar);pred=d(xt,ts,y[diag]);x0=((xt-(1-bar[t]).sqrt()*pred)/bar[t].sqrt()).clamp(-1,1)
     diagnostic.append(dict(t=t,noise_mse=F.mse_loss(pred,eps).item(),zero_noise_baseline=eps.square().mean().item(),identity_noise_baseline=F.mse_loss(xt,eps).item(),clipped_x0_unit_mse=F.mse_loss((x0+1)/2,unit[diag]).item()))
    eps=torch.randn(10,64,generator=torch.Generator().manual_seed(283),dtype=torch.float64)
    text=align.texts(torch.arange(10));cosines=align.images(unit[diag])@text.T;pred=cosines.argmax(-1);conf=torch.zeros(10,10,dtype=torch.long)
    for truth,guess in zip(y[diag],pred):conf[truth,guess]+=1
    for row,i in enumerate(ids):
     refs=[]
     for t in [8,24,32]:
      xt=corrupt(clean[[i]],eps[[row]],torch.tensor([t]),bar);c=d(xt,torch.tensor([t]),y[[i]]);u=d(xt,torch.tensor([t]),torch.tensor([10]))
      refs.append(dict(t=t,xt=xt[0].tolist(),conditional=c[0].tolist(),null=u[0].tolist()))
     samples.append(dict(source_row_1based=i+1,digit=int(labels[i]),unit_pixels=unit[i].tolist(),epsilon=eps[row].tolist(),references=refs,image_embedding=align.images(unit[[i]])[0].tolist(),cosines=(align.images(unit[[i]])@text.T)[0].tolist()))
    initial=torch.randn(1,64,generator=torch.Generator().manual_seed(281),dtype=torch.float64)
    traces=[dict(label=label,guidance=scale,steps=steps,trace=sample(d,initial,label,scale,steps,bar)) for label,scale,steps in [(3,1.,32),(3,2.,8),(7,1.,8),(3,0.,8),(3,1.,8)]]
   report=dict(source='UCI Optical Recognition of Handwritten Digits, Alpaydin & Kaynak (1998), CC BY 4.0; historical sklearn subset',source_sha256=hashlib.sha256((DATA/'digits.csv.gz').read_bytes()).hexdigest(),fit_rows_1based=(fit+1).tolist(),diagnostic_rows_1based=(diag+1).tolist(),fit_count=len(fit),diagnostic_count=len(diag),split='Chapter18 observed roles, not writer independent/fresh confirmation',model_seed=28,training_rng=280,sampling_seed=281,diagnostic_seed=282,display_noise_seed=283,diffusion_epochs=120,alignment_epochs=50,denoiser_updates=1440,alignment_updates=600,denoiser_parameters=sum(p.numel() for p in d.parameters()),alignment_parameters=sum(p.numel() for p in align.parameters()),diagnostic=diagnostic,alignment_top1=(pred==y[diag]).double().mean().item(),alignment_confusion=conf.tolist(),majority_baseline=max(np.bincount(labels[diag])).item()/len(diag),torch=torch.__version__,python=platform.python_version(),dtype='float64 CPU',notes='No model/seed/epoch search. DDPM simplified unweighted epsilon MSE, cosine32 schedule. DDIM eta0 with clipped x0 and unchanged epsilon direction;8/32 steps, common initial noise. Class-conditioned toy-scale MLP is not text-to-image. Alignment is supervised image/class-name lookup retrieval among10 known labels, not CLIP, natural language understanding, caption training or zero-shot transfer. UI aliases are authored label names, not observed captions.')
   result=dict(report=report,beta=beta.tolist(),alpha_bar=bar.tolist(),weights=dict(denoiser=weights(d),alignment=weights(align)),names=NAMES,samples=samples,initial=initial[0].tolist(),traces=traces,text_embeddings=text.tolist(),diffusion_history=dh,alignment_history=ah)
   if artifact_dir:
    out=Path(artifact_dir);out.mkdir(parents=True,exist_ok=True)
    for name,model in [('denoiser',d),('alignment',align)]:torch.save(model.state_dict(),out/f'{name}.pt')
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    (out/'checksums.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file() and p.name!='checksums.json'},indent=2)+'\n')
   return result
 finally:torch.set_num_threads(old)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--write-labs',action='store_true');p.add_argument('--artifact-dir',type=Path);args=p.parse_args();r=analyse(args.artifact_dir)
 if args.write_labs:(DATA/'diffusion_lab.json').write_text(json.dumps(r,separators=(',',':'),allow_nan=False)+'\n',encoding='utf-8')
 report={k:v for k,v in r['report'].items() if 'rows_1based' not in k};print(json.dumps(report,indent=2))
