"""Chapter19 causal recurrent forecasting on existing Bike Sharing roles.

Only2011 train and Jan-Jun2012 diagnostic development outcomes are used.
The final184 source outcomes are not scored or exported into labs.
"""
# %% Source verification, causal windows and training-only scaling
from pathlib import Path
import argparse,hashlib,importlib.util,json,platform,sys
import numpy as np
import torch
from torch import nn
from torch.nn.utils.rnn import pack_padded_sequence
DATA=Path(__file__).resolve().parent
LOOKBACK=14

def prepare(path):
    spec=importlib.util.spec_from_file_location('ch19_temporal_source',path.with_name('temporal_workflow.py'))
    module=importlib.util.module_from_spec(spec);sys.modules[spec.name]=module;spec.loader.exec_module(module)
    frame,y=module.load_source(path)
    # Do not consume reserved outcomes after June30 in modeling/reference evidence.
    observed=y[:547].copy();mean=float(observed[:365].mean());scale=float(observed[:365].std(ddof=0))
    if scale<=0:raise ValueError('Positive training count scale')
    return frame.dteday.iloc[:547].dt.strftime('%Y-%m-%d').tolist(),observed,mean,scale

def windows(y,mean,scale,start,end):
    y=np.asarray(y,dtype=float)
    if y.ndim!=1 or not np.isfinite(y).all() or not np.isfinite(mean) or not np.isfinite(scale) or scale<=0 or start<14 or end>len(y) or start>=end:raise ValueError('Finite causal window contract')
    ids=np.arange(start,end);X=np.stack([(y[t-14:t]-mean)/scale for t in ids])[:,:,None];target=(y[ids]-mean)/scale
    return torch.tensor(X,dtype=torch.float64),torch.tensor(target,dtype=torch.float64),ids

# %% Registered recurrent model and independent gate equations
class SequenceGRU(nn.Module):
    def __init__(self):
        super().__init__();self.recurrent=nn.GRU(1,3,batch_first=True,dtype=torch.float64);self.head=nn.Linear(3,1,dtype=torch.float64)
    def forward(self,X):
        if X.ndim!=3 or X.shape[1:]!=(14,1):raise ValueError('X[B,14,1]')
        output,_=self.recurrent(X)
        return self.head(output[:,-1]).squeeze(-1)

def parameters(cell,head=None):
    record={'w_ih':cell.weight_ih_l0.detach().tolist(),'w_hh':cell.weight_hh_l0.detach().tolist(),'b_ih':cell.bias_ih_l0.detach().tolist(),'b_hh':cell.bias_hh_l0.detach().tolist()}
    if head is not None:record.update(head_weight=head.weight.detach()[0].tolist(),head_bias=head.bias.detach().item())
    return record

def sigmoid(x):return np.exp(-np.logaddexp(0,-x))

def manual(sequence,p,kind,length=None):
    x=np.asarray(sequence,dtype=float);length=len(x) if length is None else length
    if x.ndim!=1 or not len(x) or not np.isfinite(x).all() or not isinstance(length,int) or length<1 or length>len(x) or kind not in ['rnn','gru','lstm']:raise ValueError('Finite sequence, valid length/cell')
    W=np.asarray(p['w_ih']);U=np.asarray(p['w_hh']);a=np.asarray(p['b_ih']);b=np.asarray(p['b_hh']);rows={'rnn':3,'gru':9,'lstm':12}[kind]
    if W.shape!=(rows,1) or U.shape!=(rows,3) or a.shape!=(rows,) or b.shape!=(rows,) or any(not np.isfinite(v).all() for v in [W,U,a,b]):raise ValueError('Hidden3 PyTorch gate layout')
    h=np.zeros(3);c=np.zeros(3);trace=[]
    for value in x[:length]:
        ih=W[:,0]*value+a;hh=U@h+b
        if kind=='rnn':h=np.tanh(ih+hh);gates={}
        elif kind=='gru':
            r=sigmoid(ih[:3]+hh[:3]);z=sigmoid(ih[3:6]+hh[3:6]);n=np.tanh(ih[6:]+r*hh[6:]);h=(1-z)*n+z*h;gates={'reset':r.tolist(),'update':z.tolist(),'candidate':n.tolist()}
        else:
            gates4=ih+hh;i=sigmoid(gates4[:3]);f=sigmoid(gates4[3:6]);g=np.tanh(gates4[6:9]);o=sigmoid(gates4[9:]);c=f*c+i*g;h=o*np.tanh(c);gates={'input':i.tolist(),'forget':f.tolist(),'candidate':g.tolist(),'output':o.tolist()}
        trace.append({'hidden':h.tolist(),'cell':c.tolist() if kind=='lstm' else [],'gates':gates})
    return trace

def recursive(model,history,mean,scale,horizon):
    prefix=list(history)
    if horizon<1 or horizon>7 or len(prefix)<14:raise ValueError('History>=14, horizon1..7')
    result=[];model.eval()
    with torch.no_grad():
        for _ in range(horizon):
            X=torch.tensor((np.array(prefix[-14:])-mean)/scale,dtype=torch.float64).reshape(1,14,1)
            value=model(X).item()*scale+mean;result.append(value);prefix.append(value)
    return result

# %% Fixed GRU training, real-window cell/packing audits and forecasts
def analyse_source(path,artifact_dir=None):
    dates,y,mean,scale=prepare(path);X,target,train_ids=windows(y,mean,scale,14,365);V,vy,dev_ids=windows(y,mean,scale,365,547)
    with torch.random.fork_rng(devices=[]):
        torch.manual_seed(19);model=SequenceGRU();initial=parameters(model.recurrent,model.head)
        opt=torch.optim.Adam(model.parameters(),lr=.01,foreach=False);history=[]
        for epoch in range(81):
            model.eval()
            with torch.no_grad():history.append({'epoch':epoch,'train_mse_scaled':nn.functional.mse_loss(model(X),target).item()})
            if epoch==80:break
            model.train();opt.zero_grad(set_to_none=True);loss=nn.functional.mse_loss(model(X),target);loss.backward();nn.utils.clip_grad_norm_(model.parameters(),1.,error_if_nonfinite=True);opt.step()
        torch.manual_seed(20);rnn=nn.RNN(1,3,batch_first=True,dtype=torch.float64)
        torch.manual_seed(21);lstm=nn.LSTM(1,3,batch_first=True,dtype=torch.float64)
    model.eval()
    with torch.no_grad():pred=model(V).numpy()*scale+mean
    baselines={'naive':y[dev_ids-1],'seasonal7':y[dev_ids-7],'gru':pred}
    scores={name:{'mae':float(np.abs(values-y[dev_ids]).mean()),'rmse':float(np.sqrt(np.mean((values-y[dev_ids])**2)))} for name,values in baselines.items()}
    cells=[{'name':'rnn_initial','kind':'rnn','parameters':parameters(rnn)},{'name':'gru_initial','kind':'gru','parameters':initial},
        {'name':'gru_trained','kind':'gru','parameters':parameters(model.recurrent,model.head)},{'name':'lstm_initial','kind':'lstm','parameters':parameters(lstm)}]
    queries=[]
    for t in [365,400,540]:
        values=y[t-14:t];seq=((values-mean)/scale).tolist();refs=[]
        for entry in cells:
            trace=manual(seq,entry['parameters'],entry['kind']);refs.append({'name':entry['name'],'trace':trace})
            cell={'rnn_initial':rnn,'gru_initial':None,'gru_trained':model.recurrent,'lstm_initial':lstm}[entry['name']]
            if cell is None:
                cell=nn.GRU(1,3,batch_first=True,dtype=torch.float64)
                with torch.no_grad():
                    for attr,key in [('weight_ih_l0','w_ih'),('weight_hh_l0','w_hh'),('bias_ih_l0','b_ih'),('bias_hh_l0','b_hh')]:getattr(cell,attr).copy_(torch.tensor(entry['parameters'][key],dtype=torch.float64))
            with torch.no_grad():output,_=cell(torch.tensor(seq,dtype=torch.float64).reshape(1,14,1))
            np.testing.assert_allclose([r['hidden'] for r in trace],output[0],atol=1e-12,rtol=1e-12)
        queries.append({'target_index':t,'target_date':dates[t],'history_dates':dates[t-14:t],'counts':values.tolist(),'standardized':seq,
            'future_dates':dates[t:t+7],'future_counts':y[t:t+7].tolist(),'cell_references':refs,
            'recursive_gru':recursive(model,y[:t],mean,scale,7),'seasonal7_fixed_origin':y[t-7:t].tolist()})
    # Different valid lengths are explicit truncations of actual history windows.
    lengths=[5,14,9];seqs=[q['standardized'][:length] for q,length in zip(queries,lengths)]
    padded=nn.utils.rnn.pad_sequence([torch.tensor(s,dtype=torch.float64)[:,None] for s in seqs],batch_first=True)
    with torch.no_grad():
        packed=pack_padded_sequence(padded,torch.tensor(lengths),batch_first=True,enforce_sorted=False);_,correct=model.recurrent(packed);all_output,naive=model.recurrent(padded)
    mask_refs=[]
    for j,(seq,length) in enumerate(zip(seqs,lengths)):
        trace=manual(padded[j,:,0].tolist(),cells[2]['parameters'],'gru');valid=manual(seq,cells[2]['parameters'],'gru')
        np.testing.assert_allclose(valid[-1]['hidden'],correct[0,j],atol=1e-12)
        mask_refs.append({'query':j,'length':length,'padded':padded[j,:,0].tolist(),'valid_hidden':correct[0,j].tolist(),'naive_hidden':naive[0,j].tolist(),'all_hidden':[s['hidden'] for s in trace]})
    provenance={'source':'UCI Bike Sharing, Fanaee-T (2013), CC BY 4.0','sha256':'a6bcf826782d3c0fbfdcbeead17cd0884185a0dafe8ff10cd48a874ee7ba18be'}
    report={**provenance,'versions':{'python':platform.python_version(),'torch':torch.__version__,'numpy':np.__version__},'device':'cpu','dtype':'float64',
        'train_days':365,'train_windows':351,'development_windows':182,'reserved_outcomes_used':0,'mean':mean,'scale':scale,'lookback':14,'hidden':3,'parameters':58,
        'epochs':80,'learning_rate':.01,'seed':19,'initial_train_mse_scaled':history[0]['train_mse_scaled'],'final_train_mse_scaled':history[-1]['train_mse_scaled'],'rolling_one_step':scores,
        'assumptions':['Counts observed after each day closes; input t-14:t excludes target t and later values.',
            'Scale fits only2011 counts. Jan-Jun2012 development previously explored; not fresh confirmation.',
            'One fixed GRU58-parameter recipe; RNN/LSTM and initial-GRU cell references are untrained mechanics comparisons, not fitted-model rankings.',
            'Each window resets hidden state to zero; shuffled independent windows never carry state.',
            'Rolling one-step uses earlier observed development counts; recursive7-day examples feed predictions after fixed origin. Protocols are distinct.',
            'Padding lengths5/14/9 are declared history truncations, not missing source observations; packed final states checked against individual sequences.',
            'Final184 outcomes after June30 are not scored/exported. CSV integrity calendar checks may read full original file.',
            'CPU float64 only; no accelerator throughput, causal, current-demand or production forecasting claim.']}
    asset={**provenance,'mean':mean,'scale':scale,'lookback':14,'hidden':3,'parameter_count':58,'cells':cells,'queries':queries,'padding_references':mask_refs,
        'train_history':history,'rolling_metrics':scores,'dtype':'float64','train_end':'2011-12-31','development_end':'2012-06-30','torch_version':torch.__version__}
    if artifact_dir:
        folder=Path(artifact_dir);folder.mkdir(parents=True,exist_ok=True);torch.save(model.state_dict(),folder/'gru.pt')
        (folder/'schema.json').write_text(json.dumps({'input':['B',14,1],'hidden_reset':'zero each window','mean':mean,'scale':scale,'source_sha256':provenance['sha256']},indent=2)+'\n')
        (folder/'checksums.json').write_text(json.dumps({n:hashlib.sha256((folder/n).read_bytes()).hexdigest() for n in ['gru.pt','schema.json']},indent=2)+'\n')
    return report,asset

def run_analysis(path,artifact_dir=None):
    previous=torch.get_num_threads()
    try:
        torch.set_num_threads(1)
        with torch.random.fork_rng(devices=[]):return analyse_source(path,artifact_dir)
    finally:torch.set_num_threads(previous)

# %% Import-safe CLI and explicit reference-asset writes
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--write-labs',action='store_true');parser.add_argument('--artifact-dir',type=Path)
    args=parser.parse_args(argv);report,asset=run_analysis(DATA/'day.csv',args.artifact_dir)
    if args.write_labs:(DATA/'sequence_lab.json').write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);temp=args.output.with_name(args.output.name+'.tmp');temp.write_text(rendered+'\n',encoding='utf-8');temp.replace(args.output)
    print(rendered);return report
if __name__=='__main__':main()
