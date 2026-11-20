"""Chapter 27: actual unconditional VAE/GAN fits on bundled UCI 8x8 digits.

No downloads. Existing Chapter18 roles reused; diagnostic is already observed.
Default CLI verifies/recomputes but never mutates bundled assets.
"""
from pathlib import Path
import argparse, contextlib, hashlib, importlib.util, json, platform
import numpy as np
import torch
from torch import nn
import torch.nn.functional as F

DATA = Path(__file__).resolve().parent

def source():
    spec = importlib.util.spec_from_file_location('chapter27_vision', DATA/'vision_workflow.py')
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    raw, labels, groups, roles = m.load_source(DATA/'digits.csv.gz')
    train = np.sort(np.concatenate([roles['source_train'], roles['target_train']]))
    diagnostic = np.sort(np.concatenate([roles['source_validation'], roles['target_validation']]))
    assert len(train)==1438 and len(diagnostic)==359
    assert set(groups[train]).isdisjoint(groups[diagnostic])
    return raw, labels, train, diagnostic

class VAE(nn.Module):
    def __init__(self):
        super().__init__()
        self.enc=nn.Linear(64,32,dtype=torch.float64)
        self.mu=nn.Linear(32,2,dtype=torch.float64)
        self.logvar=nn.Linear(32,2,dtype=torch.float64)
        self.dec=nn.Linear(2,32,dtype=torch.float64)
        self.out=nn.Linear(32,64,dtype=torch.float64)
    def encode(self,x):
        h=F.relu(self.enc(x)); return self.mu(h),self.logvar(h)
    def decode(self,z): return self.out(F.relu(self.dec(z)))
    def forward(self,x,eps):
        mu,lv=self.encode(x)
        return self.decode(mu+torch.exp(.5*lv)*eps),mu,lv

class Generator(nn.Module):
    def __init__(self):
        super().__init__()
        self.hidden=nn.Linear(2,32,dtype=torch.float64);self.out=nn.Linear(32,64,dtype=torch.float64)
    def forward(self,z): return self.out(F.relu(self.hidden(z))).sigmoid()

class Discriminator(nn.Module):
    def __init__(self):
        super().__init__()
        self.hidden=nn.Linear(64,32,dtype=torch.float64);self.out=nn.Linear(32,1,dtype=torch.float64)
    def forward(self,x): return self.out(F.leaky_relu(self.hidden(x),.2)).squeeze(-1)

def vae_terms(logits,x,mu,logvar):
    """Sum pixels/latent dimensions per row, then mean batch. Soft-target BCE."""
    recon=F.binary_cross_entropy_with_logits(logits,x,reduction='none').sum(-1)
    kl=.5*(mu.square()+logvar.exp()-1-logvar).sum(-1)
    return recon,kl

def weights(model): return {k:v.detach().tolist() for k,v in model.state_dict().items()}

def evaluate(v,x):
    with torch.no_grad():
        mu,lv=v.encode(x);logits=v.decode(mu);r,k=vae_terms(logits,x,mu,lv)
        return dict(mean_decode_bce=r.mean().item(),kl=k.mean().item(),mse=(logits.sigmoid()-x).square().mean().item())

def analyse(artifact_dir=None):
    raw,labels,train,diag=source()
    x=torch.tensor(raw.reshape(-1,64),dtype=torch.float64)/16
    old_threads=torch.get_num_threads()
    try:
        torch.set_num_threads(1)
        with torch.random.fork_rng(devices=[]):
            torch.manual_seed(27);v=VAE();g=Generator();d=Discriminator()
            opt=torch.optim.Adam(v.parameters(),lr=.003,foreach=False)
            go=torch.optim.Adam(g.parameters(),lr=.001,betas=(.5,.999),foreach=False)
            do=torch.optim.Adam(d.parameters(),lr=.001,betas=(.5,.999),foreach=False)
            rng=torch.Generator().manual_seed(270)
            vh=[];gh=[]
            for epoch in range(60):
                rs=ks=0.
                for batch in torch.randperm(len(train),generator=rng).split(128):
                    b=x[train[batch.numpy()]];eps=torch.randn(len(b),2,generator=rng,dtype=torch.float64)
                    opt.zero_grad(set_to_none=True);logits,mu,lv=v(b,eps);r,k=vae_terms(logits,b,mu,lv)
                    (r+k).mean().backward();opt.step();rs+=r.sum().item();ks+=k.sum().item()
                vh.append(dict(epoch=epoch+1,reconstruction=rs/len(train),kl=ks/len(train)))
            for epoch in range(80):
                ds=gs=0.
                for batch in torch.randperm(len(train),generator=rng).split(128):
                    real=x[train[batch.numpy()]];n=len(real)
                    z=torch.randn(n,2,generator=rng,dtype=torch.float64)
                    do.zero_grad(set_to_none=True)
                    loss_d=F.softplus(-d(real)).mean()+F.softplus(d(g(z).detach())).mean()
                    loss_d.backward();do.step()
                    for p in d.parameters():p.requires_grad_(False)
                    go.zero_grad(set_to_none=True)
                    z=torch.randn(n,2,generator=rng,dtype=torch.float64)
                    loss_g=F.softplus(-d(g(z))).mean();loss_g.backward();go.step()
                    for p in d.parameters():p.requires_grad_(True)
                    ds+=loss_d.item()*n;gs+=loss_g.item()*n
                gh.append(dict(epoch=epoch+1,discriminator=ds/len(train),generator=gs/len(train)))
            ids=[int(next(i for i in diag if labels[i]==digit)) for digit in range(10)]
            refs=[]
            with torch.no_grad():
                for i in ids:
                    mu,lv=v.encode(x[[i]]);logits=v.decode(mu);r,k=vae_terms(logits,x[[i]],mu,lv)
                    refs.append(dict(source_row_1based=i+1,digit=int(labels[i]),pixels=x[i].tolist(),mu=mu[0].tolist(),logvar=lv[0].tolist(),reconstruction=logits[0].sigmoid().tolist(),bce=r.item(),kl=k.item()))
                latent=torch.randn(16,2,generator=torch.Generator().manual_seed(271),dtype=torch.float64)
                vp=v.decode(latent).sigmoid();gp=g(latent);scores=d(gp).sigmoid()
                # Pixel nearest-neighbor MSE is only a memorization diagnostic, NOT FID.
                nearest=(gp[:,None,:]-x[train][None,:,:]).square().mean(-1).min(-1)
                samples=[dict(z=z.tolist(),vae=a.tolist(),gan=b.tolist(),d_fake=s.item(),nearest_train_row_1based=int(train[idx])+1,nearest_mse=err.item()) for z,a,b,s,idx,err in zip(latent,vp,gp,scores,nearest.indices,nearest.values)]
            report=dict(source='UCI Optical Recognition of Handwritten Digits, Alpaydin & Kaynak (1998), CC BY 4.0; sklearn-packaged historical test subset',source_sha256=hashlib.sha256((DATA/'digits.csv.gz').read_bytes()).hexdigest(),train_rows_1based=(train+1).tolist(),diagnostic_rows_1based=(diag+1).tolist(),train_count=len(train),diagnostic_count=len(diag),split='Chapter18 StratifiedGroupKFold 5 seed18, same previously observed roles; not writer independent or fresh confirmation',seed=27,shuffle_seed=270,sample_seed=271,vae_epochs=60,gan_epochs=80,batch_size=128,vae_updates=720,gan_updates_each=960,vae_parameters=sum(p.numel() for p in v.parameters()),generator_parameters=sum(p.numel() for p in g.parameters()),discriminator_parameters=sum(p.numel() for p in d.parameters()),vae_diagnostic=evaluate(v,x[diag]),train_mean_baseline_mse=(x[diag]-x[train].mean(0)).square().mean().item(),torch=torch.__version__,python=platform.python_version(),dtype='float64 CPU',notes='Fixed run, no best-epoch/seed search. Soft targets x/16; BCE is a surrogate, not exact grayscale likelihood. Mean decode is not a Monte Carlo ELBO estimate. GAN loss/nearest pixel MSE are not sample quality or diversity certifications.')
            result=dict(report=report,weights=dict(vae=weights(v),generator=weights(g),discriminator=weights(d)),images=refs,samples=samples,vae_history=vh,gan_history=gh)
            if artifact_dir:
                out=Path(artifact_dir);out.mkdir(parents=True,exist_ok=True)
                for name,model in [('vae',v),('generator',g),('discriminator',d)]:torch.save(model.state_dict(),out/f'{name}.pt')
                (out/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
                files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file() and p.name!='checksums.json'}
                (out/'checksums.json').write_text(json.dumps(files,indent=2)+'\n',encoding='utf-8')
            return result
    finally:torch.set_num_threads(old_threads)

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--write-labs',action='store_true');parser.add_argument('--artifact-dir',type=Path);args=parser.parse_args()
    result=analyse(args.artifact_dir)
    if args.write_labs:(DATA/'generative_lab.json').write_text(json.dumps(result,separators=(',',':'),allow_nan=False)+'\n',encoding='utf-8')
    print(json.dumps(result['report'],indent=2))

if __name__=='__main__':main()
