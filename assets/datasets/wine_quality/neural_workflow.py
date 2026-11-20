"""Chapter16: fixed-recipe CPU MLP and independently checked backpropagation.

Reuses only Chapter14's fit role. Its published decision/test evidence is not
evaluated again. Inner validation is diagnostic, not untouched confirmation.
"""
# %% Source contract and inner-training-only preprocessing
from pathlib import Path
import argparse
import importlib.util
import json
import platform
import sys
import numpy as np
import torch
from torch import nn
import torch.nn.functional as F
from sklearn.model_selection import GroupShuffleSplit

DATA=Path(__file__).resolve().parent
FEATURES=['fixed acidity','volatile acidity','citric acid','residual sugar','chlorides','free sulfur dioxide','total sulfur dioxide','density','pH','sulphates','alcohol']
EPOCHS=[0,1,5,10,20,40,80,120]

def prepare(path):
    spec=importlib.util.spec_from_file_location('ch16_contract',path.with_name('capstone_workflow.py'))
    module=importlib.util.module_from_spec(spec);sys.modules[spec.name]=module;spec.loader.exec_module(module)
    frame,X,y,groups=module.load_source(path);fit,_,_=module.split_roles(X,y,groups)
    a,b=next(GroupShuffleSplit(n_splits=1,test_size=.2,random_state=16).split(X[fit],y[fit],groups[fit]))
    train,validation=fit[a],fit[b]
    assert set(groups[train]).isdisjoint(groups[validation])
    mean=X[train].mean(axis=0);scale=X[train].std(axis=0,ddof=0)
    if np.any(scale<=0):raise ValueError('Positive training scale required')
    return frame,X,y,groups,fit,train,validation,mean,scale

# %% Registered modules, explicit initialization and analytical chain rule
class WineMLP(nn.Module):
    def __init__(self):
        super().__init__()
        self.hidden=nn.Linear(11,4,dtype=torch.float64)
        self.output=nn.Linear(4,1,dtype=torch.float64)
    def forward(self,X):
        if X.ndim!=2 or X.shape[1]!=11:raise ValueError('X[B,11] required')
        return self.output(torch.relu(self.hidden(X))).squeeze(-1)

def initialize(model):
    nn.init.kaiming_uniform_(model.hidden.weight,nonlinearity='relu')
    nn.init.zeros_(model.hidden.bias)
    nn.init.xavier_uniform_(model.output.weight)
    nn.init.zeros_(model.output.bias)

def snapshot(model):
    return {'w1':model.hidden.weight.detach().tolist(),'b1':model.hidden.bias.detach().tolist(),
        'w2':model.output.weight.detach()[0].tolist(),'b2':model.output.bias.detach().item()}

def manual(X,y,p,reduction='mean',activation='relu'):
    X=np.asarray(X,dtype=np.float64);y=np.asarray(y,dtype=np.float64)
    W1=np.asarray(p['w1']);b1=np.asarray(p['b1']);w2=np.asarray(p['w2']);b2=float(p['b2'])
    if X.ndim!=2 or X.shape[1]!=11 or X.shape[0]<1 or y.shape!=(len(X),) or W1.shape!=(4,11) or b1.shape!=(4,) or w2.shape!=(4,):raise ValueError('11 ->4 ->1 exact-shape contract')
    if any(not np.isfinite(v).all() for v in [X,y,W1,b1,w2,np.asarray(b2)]) or not np.isin(y,[0,1]).all():raise ValueError('Finite values and binary labels required')
    if reduction not in ['mean','sum'] or activation not in ['relu','tanh']:raise ValueError('Declared reduction/activation required')
    z1=X@W1.T+b1;h=np.maximum(z1,0) if activation=='relu' else np.tanh(z1)
    gate=(z1>0).astype(float) if activation=='relu' else 1-h*h
    logits=h@w2+b2;probability=np.exp(-np.logaddexp(0,-logits))
    per_loss=np.logaddexp(0,logits)-y*logits
    d=(probability-y)/(len(y) if reduction=='mean' else 1)
    dh=d[:,None]*w2;dz1=dh*gate
    return {'z1':z1.tolist(),'hidden':h.tolist(),'gate':gate.tolist(),'logits':logits.tolist(),'probability':probability.tolist(),
        'loss':float(per_loss.mean() if reduction=='mean' else per_loss.sum()),'dlogit':d.tolist(),
        'dw1':(dz1.T@X).tolist(),'db1':dz1.sum(axis=0).tolist(),'dw2':(h.T@d).tolist(),'db2':float(d.sum())}

def evaluate(model,X,y):
    model.eval()
    with torch.no_grad():
        logits=model(X)
        return {'bce':F.binary_cross_entropy_with_logits(logits,y).item(),'accuracy_at_0_5':((logits>=0)==(y==1)).double().mean().item()}

# %% Fixed full-batch training and actual source-backed lab references
def analyse_source(path):
    frame,raw,y,groups,fit,train,validation,mean,scale=prepare(path)
    X=torch.tensor((raw[train]-mean)/scale,dtype=torch.float64);target=torch.tensor(y[train],dtype=torch.float64)
    V=torch.tensor((raw[validation]-mean)/scale,dtype=torch.float64);vy=torch.tensor(y[validation],dtype=torch.float64)
    # Isolate initialization RNG state from callers. No seed/model search.
    with torch.random.fork_rng(devices=[]):
        torch.manual_seed(16);model=WineMLP();initialize(model)
    optimizer=torch.optim.SGD(model.parameters(),lr=.05)
    history=[];checkpoints=[]
    for epoch in range(121):
        tr=evaluate(model,X,target);va=evaluate(model,V,vy)
        history.append({'epoch':epoch,'train_bce':tr['bce'],'validation_bce':va['bce'],
            'train_accuracy':tr['accuracy_at_0_5'],'validation_accuracy':va['accuracy_at_0_5']})
        if epoch in EPOCHS:checkpoints.append({'epoch':epoch,'parameters':snapshot(model),**history[-1]})
        if epoch==120:break
        model.train();optimizer.zero_grad(set_to_none=True)
        logits=model(X)
        if logits.shape!=target.shape:raise ValueError('BCE shapes must match')
        loss=F.binary_cross_entropy_with_logits(logits,target)
        if not torch.isfinite(loss):raise ValueError('Nonfinite training loss')
        loss.backward();optimizer.step()
    # Independently check the chain rule on actual source rows, initial weights.
    reference=[]
    for checkpoint in [checkpoints[0],checkpoints[-1]]:
        p=checkpoint['parameters'];W1=torch.tensor(p['w1'],dtype=torch.float64,requires_grad=True);b1=torch.tensor(p['b1'],dtype=torch.float64,requires_grad=True)
        w2=torch.tensor(p['w2'],dtype=torch.float64,requires_grad=True);b2=torch.tensor(p['b2'],dtype=torch.float64,requires_grad=True)
        for activation in ['relu','tanh']:
            for reduction in ['mean','sum']:
                hidden=X[:8]@W1.T+b1;h=torch.relu(hidden) if activation=='relu' else torch.tanh(hidden)
                logits=h@w2+b2;loss=F.binary_cross_entropy_with_logits(logits,target[:8],reduction=reduction)
                grads=torch.autograd.grad(loss,(W1,b1,w2,b2));result=manual(X[:8],target[:8],p,reduction,activation)
                for key,g in zip(['dw1','db1','dw2','db2'],grads):np.testing.assert_allclose(result[key],g.detach(),atol=1e-12,rtol=1e-12)
                reference.append({'epoch':checkpoint['epoch'],'activation':activation,'reduction':reduction,**result})
    prior=float(np.mean(y[train]));prior_bce=float(np.mean(-y[validation]*np.log(prior)-(1-y[validation])*np.log1p(-prior)))
    samples=[{'source_row_1based':int(i+1),'quality':int(frame.quality.iloc[i]),'positive':int(y[i]),'raw':raw[i].tolist(),'standardized':X[j].tolist()} for j,i in enumerate(train[:8])]
    provenance={'source':'UCI Wine Quality, Cortez et al. (2009), CC BY 4.0','sha256':'4a402cf041b025d4566d954c3b9ba8635a3a8a01e039005d97d6a710278cf05e'}
    roles={'outer_fit_rows':len(fit),'inner_train_rows':len(train),'inner_validation_rows':len(validation),
        'inner_train_groups':len(set(groups[train])),'inner_validation_groups':len(set(groups[validation]))}
    asset={**provenance,**roles,'feature_names':FEATURES,'mean':mean.tolist(),'scale':scale.tolist(),'samples':samples,
        'architecture':[11,4,1],'parameter_count':53,'activation':'relu','learning_rate':.05,'seed':16,'dtype':'float64',
        'checkpoints':checkpoints,'history':history,'backprop_references':reference,'torch_version':torch.__version__}
    report={**provenance,**roles,'versions':{'python':platform.python_version(),'numpy':np.__version__,'torch':torch.__version__},
        'device':'cpu','dtype':'float64','architecture':[11,4,1],'parameter_count':sum(p.numel() for p in model.parameters()),
        'optimizer':'SGD, full batch, no momentum/weight decay','learning_rate':.05,'updates':120,'seed':16,
        'initial':history[0],'final':history[-1],'inner_validation_prior_bce':prior_bce,'analytical_autograd_checks':len(reference),
        'assumptions':['Only existing966 fit-role rows used; inner grouped split seed16, fraction.2; scaler fitted only on inner training.',
            'One declared11->4->1 ReLU recipe; no architecture/seed/learning-rate search or best-epoch selection.',
            'Inner validation is diagnostic on previously explored source, not independent confirmatory evidence.',
            'Chapter14 decision/test evidence is not re-evaluated; its published test remains observed.',
            'Checkpoint0 and120 gradients checked for ReLU/tanh, mean/sum; tanh is a fixed-weight what-if, not a trained alternative.',
            'CPU float64 only; no CUDA/MPS/AMP or throughput claim. Profiles are chemistry proxies, not bottle/batch identities.']}
    return report,asset,model

def run_analysis(path):
    previous=torch.get_num_threads()
    try:
        torch.set_num_threads(1)
        return analyse_source(path)
    finally:torch.set_num_threads(previous)

# %% Import-safe CLI and explicit asset writes
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--write-labs',action='store_true')
    args=parser.parse_args(argv);report,asset,_=run_analysis(DATA/'winequality-red.csv')
    if args.write_labs:(DATA/'neural_lab.json').write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);temp=args.output.with_name(args.output.name+'.tmp');temp.write_text(rendered+'\n',encoding='utf-8');temp.replace(args.output)
    print(rendered);return report

if __name__=='__main__':main()
