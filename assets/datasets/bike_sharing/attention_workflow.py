"""Chapter20: explicit pre-norm attention on historical Bike Sharing counts.

Fixed diagnostic recipe; final184 outcomes excluded from modeling and exports.
"""
# %% Verified source, training-only count transform and causal windows
from pathlib import Path
import argparse,hashlib,importlib.util,json,platform,sys
import numpy as np
import torch
from torch import nn
DATA=Path(__file__).resolve().parent

def prepare(path):
    spec=importlib.util.spec_from_file_location('ch20_sequence_source',path.with_name('sequence_workflow.py'))
    module=importlib.util.module_from_spec(spec);sys.modules[spec.name]=module;spec.loader.exec_module(module)
    return module.prepare(path)

def windows(y,mean,scale,start,end):
    y=np.asarray(y,dtype=float)
    if y.ndim!=1 or not np.isfinite(y).all() or not np.isfinite(mean) or not np.isfinite(scale) or scale<=0 or start<14 or end>len(y) or start>=end:raise ValueError('Finite causal windows')
    ids=np.arange(start,end)
    return torch.tensor(np.stack([(y[t-14:t]-mean)/scale for t in ids])[:,:,None],dtype=torch.float64),torch.tensor((y[ids]-mean)/scale,dtype=torch.float64),ids

# %% Explicit pre-norm Transformer block and independent NumPy attention
def positions():
    pos=torch.arange(14,dtype=torch.float64)[:,None];freq=torch.exp(torch.arange(0,4,2,dtype=torch.float64)*(-np.log(10000.)/4))
    pe=torch.zeros(14,4,dtype=torch.float64);pe[:,0::2]=torch.sin(pos*freq);pe[:,1::2]=torch.cos(pos*freq)
    return pe

class CountTransformer(nn.Module):
    def __init__(self):
        super().__init__();self.input=nn.Linear(1,4,dtype=torch.float64);self.norm1=nn.LayerNorm(4,eps=1e-5,dtype=torch.float64)
        self.attn=nn.MultiheadAttention(4,2,dropout=0.,batch_first=True,dtype=torch.float64)
        self.norm2=nn.LayerNorm(4,eps=1e-5,dtype=torch.float64);self.ff1=nn.Linear(4,8,dtype=torch.float64);self.ff2=nn.Linear(8,4,dtype=torch.float64);self.head=nn.Linear(4,1,dtype=torch.float64)
        self.register_buffer('position',positions())
    def inspect(self,X,causal=True,valid=14,use_position=True):
        if X.ndim!=3 or X.shape[1:]!=(14,1) or not torch.isfinite(X).all() or not isinstance(valid,int) or not 1<=valid<=14:raise ValueError('Finite X[B,14,1], valid1..14')
        x=self.input(X)+(self.position if use_position else 0);n=self.norm1(x)
        blocked=torch.triu(torch.ones(14,14,dtype=torch.bool),diagonal=1) if causal else torch.zeros(14,14,dtype=torch.bool)
        padding=(torch.arange(14)[None]>=valid).expand(X.shape[0],-1)
        out,w=self.attn(n,n,n,attn_mask=blocked,key_padding_mask=padding,need_weights=True,average_attn_weights=False)
        residual=x+out;n2=self.norm2(residual);hidden=torch.relu(self.ff1(n2));ff=self.ff2(hidden);state=residual+ff
        return {'embedding':x,'norm1':n,'attention':out,'weights':w,'residual1':residual,'norm2':n2,'ff_hidden':hidden,'ff_output':ff,'state':state,'prediction':self.head(state[:,valid-1]).squeeze(-1)}
    def forward(self,X):return self.inspect(X)['prediction']

def weights(model):return {k:v.detach().tolist() for k,v in model.state_dict().items()}

def manual(sequence,p,causal=True,valid=14,use_position=True):
    s=np.asarray(sequence,dtype=float)
    if s.shape!=(14,) or not np.isfinite(s).all() or not isinstance(valid,int) or not 1<=valid<=14:raise ValueError('Finite14-step sequence, valid1..14')
    def array(key):return np.asarray(p[key],dtype=float)
    def linear(x,key):return x@array(key+'.weight').T+array(key+'.bias')
    def norm(x,key):return (x-x.mean(-1,keepdims=True))/np.sqrt(x.var(-1,keepdims=True)+1e-5)*array(key+'.weight')+array(key+'.bias')
    x=linear(s[:,None],'input')+(array('position') if use_position else 0);n=norm(x,'norm1')
    Q,K,V=np.split(n@array('attn.in_proj_weight').T+array('attn.in_proj_bias'),3,axis=-1)
    q,k,v=[a.reshape(14,2,2).transpose(1,0,2) for a in [Q,K,V]]
    scores=q@k.transpose(0,2,1)/np.sqrt(2.)
    allowed=np.broadcast_to(np.arange(14)[None,:]<valid,(14,14)).copy()
    if causal:allowed&=np.arange(14)[None,:]<=np.arange(14)[:,None]
    logits=np.where(allowed[None],scores,-np.inf);ex=np.exp(logits-logits.max(-1,keepdims=True));w=ex/ex.sum(-1,keepdims=True)
    mixed=w@v;concat=mixed.transpose(1,0,2).reshape(14,4);out=linear(concat,'attn.out_proj');r1=x+out;n2=norm(r1,'norm2');hidden=np.maximum(0,linear(n2,'ff1'));ff=linear(hidden,'ff2');state=r1+ff
    return {'embedding':x.tolist(),'norm1':n.tolist(),'q':q.tolist(),'k':k.tolist(),'v':v.tolist(),'scores':scores.tolist(),'weights':w.tolist(),'mixed':mixed.tolist(),'concat':concat.tolist(),'attention':out.tolist(),'residual1':r1.tolist(),'norm2':n2.tolist(),'ff_hidden':hidden.tolist(),'ff_output':ff.tolist(),'state':state.tolist(),'prediction':float(linear(state[valid-1],'head')[0])}

# %% Fixed training, baseline evaluation and real-window reference export
def analyse_source(path,artifact_dir=None):
    dates,y,mean,scale=prepare(path);X,target,ids=windows(y,mean,scale,14,365);V,_,dev=windows(y,mean,scale,365,547)
    torch.manual_seed(20);model=CountTransformer();opt=torch.optim.Adam(model.parameters(),lr=.01,foreach=False);history=[]
    for epoch in range(81):
        model.eval()
        with torch.no_grad():history.append({'epoch':epoch,'train_mse_scaled':nn.functional.mse_loss(model(X),target).item()})
        if epoch==80:break
        model.train();opt.zero_grad(set_to_none=True);nn.functional.mse_loss(model(X),target).backward();nn.utils.clip_grad_norm_(model.parameters(),1.,error_if_nonfinite=True);opt.step()
    model.eval();p=weights(model);queries=[]
    with torch.no_grad():pred=model(V).numpy()*scale+mean
    scores={name:{'mae':float(np.abs(v-y[dev]).mean()),'rmse':float(np.sqrt(np.mean((v-y[dev])**2)))} for name,v in {'naive':y[dev-1],'seasonal7':y[dev-7],'transformer':pred}.items()}
    for t in [365,400,540]:
        seq=((y[t-14:t]-mean)/scale).tolist();refs=[]
        for causal,valid,pos in [(True,14,True),(False,14,True),(True,10,True),(False,10,True),(True,14,False)]:
            m=manual(seq,p,causal,valid,pos)
            with torch.no_grad():actual=model.inspect(torch.tensor(seq,dtype=torch.float64).reshape(1,14,1),causal,valid,pos)
            for key in actual:np.testing.assert_allclose(m[key],actual[key][0].numpy(),atol=2e-11,rtol=2e-11)
            refs.append({'causal':causal,'valid':valid,'use_position':pos,'trace':m})
        queries.append({'target_index':t,'target_date':dates[t],'history_dates':dates[t-14:t],'counts':y[t-14:t].tolist(),'standardized':seq,'outcome':float(y[t]),'references':refs})
    count=sum(v.numel() for v in model.parameters());assert count==185
    provenance={'source':'UCI Bike Sharing, Fanaee-T (2013), CC BY4.0','sha256':'a6bcf826782d3c0fbfdcbeead17cd0884185a0dafe8ff10cd48a874ee7ba18be'}
    report={**provenance,'versions':{'python':platform.python_version(),'torch':torch.__version__,'numpy':np.__version__},'device':'cpu','dtype':'float64','train_days':365,'train_windows':351,'development_windows':182,'reserved_outcomes_used':0,'mean':mean,'scale':scale,'parameters':count,'seed':20,'updates':80,'learning_rate':.01,'initial_train_mse_scaled':history[0]['train_mse_scaled'],'final_train_mse_scaled':history[-1]['train_mse_scaled'],'rolling_one_step':scores,'assumptions':['Counts known after day close; only past14 counts enter next-day input.','2011-only scaling; Jan-Jun2012 development already explored in Chapters13/19, not fresh confirmation.','One explicit pre-norm block: d_model4,heads2,d_head2,FF8,ReLU,LayerNorm eps1e-5,causal attention,dropout0; no final norm.','One fixed seed20/80-update full-batch Adam.01 recipe, clipping1; no architecture/seed/rate search.','Window-relative sinusoidal positions reset0..13; this is not calendar encoding or an LLM.','Full-attention/no-position/prefix-length references are inference interventions on the same trained weights, not separately trained models.','Every query has at least one allowed key; valid10 is a declared prefix truncation, not missing source days.','Final184 outcomes are neither scored nor exported. Integrity checks may read the full original CSV.','Attention weights are mixing coefficients, not established feature importance or causal explanation.']}
    asset={**provenance,'mean':mean,'scale':scale,'dtype':'float64','lookback':14,'width':4,'heads':2,'ff_width':8,'parameter_count':185,'train_end':'2011-12-31','development_end':'2012-06-30','weights':p,'queries':queries,'train_history':history,'rolling_metrics':scores}
    if artifact_dir:
        folder=Path(artifact_dir);folder.mkdir(parents=True,exist_ok=True);torch.save(model.state_dict(),folder/'transformer.pt')
        (folder/'schema.json').write_text(json.dumps({'input':['B',14,1],'mean':mean,'scale':scale,'causal':True,'position':'window-relative sinusoidal0..13','source_sha256':provenance['sha256'],'parameters':185},indent=2)+'\n')
        (folder/'checksums.json').write_text(json.dumps({n:hashlib.sha256((folder/n).read_bytes()).hexdigest() for n in ['transformer.pt','schema.json']},indent=2)+'\n')
    return report,asset

def run_analysis(path,artifact_dir=None):
    threads=torch.get_num_threads()
    try:
        torch.set_num_threads(1)
        with torch.random.fork_rng(devices=[]):return analyse_source(path,artifact_dir)
    finally:torch.set_num_threads(threads)

# %% Import-safe command line and explicit derived-asset regeneration
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--write-labs',action='store_true');parser.add_argument('--artifact-dir',type=Path);args=parser.parse_args(argv)
    report,asset=run_analysis(DATA/'day.csv',args.artifact_dir)
    if args.write_labs:(DATA/'attention_lab.json').write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);temp=args.output.with_name(args.output.name+'.tmp');temp.write_text(rendered+'\n',encoding='utf-8');temp.replace(args.output)
    print(rendered);return report
if __name__=='__main__':main()
