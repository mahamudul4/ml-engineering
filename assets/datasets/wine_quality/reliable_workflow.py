"""Chapter17 CPU training-state audit on the existing inner Wine Quality split.

Fixed recipe, no new model selection or outer decision/test evaluation.
Only load checkpoints you created/trust in this compatible local environment.
"""
# %% Import-safe source reuse and declared configuration
from pathlib import Path
import argparse,copy,hashlib,importlib.util,io,json,platform,sys
import numpy as np
import torch
from torch import nn
import torch.nn.functional as F

DATA=Path(__file__).resolve().parent
CONFIG={'seed':17,'batch_size':64,'epochs':40,'resume_epoch':20,'learning_rate':.01,'weight_decay':.01,'dropout':.2,'clip_norm':1.,'step_size':20,'gamma':.5}

def source(path):
    spec=importlib.util.spec_from_file_location('ch17_neural_source',path.with_name('neural_workflow.py'))
    module=importlib.util.module_from_spec(spec);sys.modules[spec.name]=module;spec.loader.exec_module(module)
    prepared=module.prepare(path)
    frame,raw,y,groups,fit,train,val,mean,scale=prepared
    X=torch.tensor((raw[train]-mean)/scale,dtype=torch.float64);Y=torch.tensor(y[train],dtype=torch.float64)
    V=torch.tensor((raw[val]-mean)/scale,dtype=torch.float64);vY=torch.tensor(y[val],dtype=torch.float64)
    return module,prepared,X,Y,V,vY

class ReliableMLP(nn.Module):
    def __init__(self):
        super().__init__();self.hidden=nn.Linear(11,4,dtype=torch.float64);self.dropout=nn.Dropout(.2);self.output=nn.Linear(4,1,dtype=torch.float64)
    def forward(self,X):return self.output(self.dropout(torch.relu(self.hidden(X)))).squeeze(-1)

def setup(module):
    model=ReliableMLP();module.initialize(model)
    # Explicit policy: only matrix weights decay; biases do not.
    opt=torch.optim.AdamW([{'params':[model.hidden.weight,model.output.weight],'weight_decay':.01},
        {'params':[model.hidden.bias,model.output.bias],'weight_decay':0.}],lr=.01,foreach=False)
    scheduler=torch.optim.lr_scheduler.StepLR(opt,step_size=20,gamma=.5)
    generator=torch.Generator().manual_seed(170)
    return model,opt,scheduler,generator

# %% Update lifecycle, complete epoch-boundary state and atomic serialization
def record(model,X,y,V,vy,epoch,opt):
    model.eval()
    with torch.no_grad():
        return {'epoch':epoch,'train_bce':F.binary_cross_entropy_with_logits(model(X),y).item(),
            'validation_bce':F.binary_cross_entropy_with_logits(model(V),vy).item(),'next_lr':opt.param_groups[0]['lr']}

def advance(model,opt,scheduler,generator,X,y,V,vy,start,end):
    rows=[]
    for epoch in range(start,end):
        model.train();order=torch.randperm(len(X),generator=generator);weighted_loss=0.;norms=[]
        used_lr=opt.param_groups[0]['lr']
        for batch in order.split(64):
            opt.zero_grad(set_to_none=True);logits=model(X[batch]);loss=F.binary_cross_entropy_with_logits(logits,y[batch])
            if not torch.isfinite(loss):raise ValueError('Finite loss required')
            loss.backward();norm=nn.utils.clip_grad_norm_(model.parameters(),1.,error_if_nonfinite=True,foreach=False)
            norms.append(norm.item());opt.step();weighted_loss+=loss.detach().item()*len(batch)
        scheduler.step() # Once per completed epoch, after optimizer updates.
        rows.append({**record(model,X,y,V,vy,epoch+1,opt),'used_lr':used_lr,
            'online_train_bce':weighted_loss/len(X),'max_preclip_norm':max(norms),'updates':len(order.split(64))})
    return rows

def checkpoint(model,opt,scheduler,generator,epoch,prepared,history):
    _,_,_,_,_,train,val,mean,scale=prepared
    return {'format':1,'config':dict(CONFIG),'epoch':epoch,'model':copy.deepcopy(model.state_dict()),
        'optimizer':copy.deepcopy(opt.state_dict()),'scheduler':copy.deepcopy(scheduler.state_dict()),
        'torch_rng':torch.get_rng_state().clone(),'shuffle_rng':generator.get_state().clone(),
        'feature_names':list(source_features()),'mean':mean.tolist(),'scale':scale.tolist(),
        'train_source_rows':(train+1).tolist(),'validation_source_rows':(val+1).tolist(),'history':copy.deepcopy(history),
        'source_sha256':'4a402cf041b025d4566d954c3b9ba8635a3a8a01e039005d97d6a710278cf05e'}

def source_features():
    return ['fixed acidity','volatile acidity','citric acid','residual sugar','chlorides','free sulfur dioxide','total sulfur dioxide','density','pH','sulphates','alcohol']

def validate_checkpoint(state,prepared):
    _,_,_,_,_,train,val,mean,scale=prepared
    if state['format']!=1 or state['config']!=CONFIG or state['epoch']!=20 or state['feature_names']!=source_features():raise ValueError('Checkpoint recipe/schema mismatch')
    if state['train_source_rows']!=(train+1).tolist() or state['validation_source_rows']!=(val+1).tolist() or state['mean']!=mean.tolist() or state['scale']!=scale.tolist():raise ValueError('Checkpoint data/transform mismatch')
    if state['source_sha256']!='4a402cf041b025d4566d954c3b9ba8635a3a8a01e039005d97d6a710278cf05e':raise ValueError('Checkpoint source hash mismatch')

def restore(module,state,prepared,weights_only=False):
    validate_checkpoint(state,prepared)
    model,opt,scheduler,generator=setup(module) # Construct scheduler before loading optimizer.
    model.load_state_dict(state['model'])
    if not weights_only:
        scheduler.load_state_dict(state['scheduler']);opt.load_state_dict(state['optimizer'])
    # Both branches get identical next sample order/dropout masks to isolate state loss.
    generator.set_state(state['shuffle_rng']);torch.set_rng_state(state['torch_rng'])
    return model,opt,scheduler,generator

def atomic_checkpoint(path,state):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True);temp=path.with_name(path.name+'.tmp')
    torch.save(state,temp);temp.replace(path)

# %% Actual-gradient optimizer replay and actual-activation normalization evidence
def lab_evidence(module,X,y,model):
    model.eval();model.zero_grad(set_to_none=True)
    F.binary_cross_entropy_with_logits(model(X[:8]),y[:8]).backward()
    initial=[model.hidden.weight[0,0].item(),model.hidden.weight[1,1].item(),model.output.bias[0].item()]
    gradient=[model.hidden.weight.grad[0,0].item(),model.hidden.weight.grad[1,1].item(),model.output.bias.grad[0].item()]
    replay=[]
    # Repeated fixed gradient is an optimizer-mechanics counterfactual, not retraining.
    for kind in ['sgd','momentum','adam','adamw']:
        p=nn.Parameter(torch.tensor(initial,dtype=torch.float64));kwargs={'lr':.01,'weight_decay':.1}
        if kind in ['sgd','momentum']:opt=torch.optim.SGD([p],momentum=.9 if kind=='momentum' else 0,**kwargs)
        elif kind=='adam':opt=torch.optim.Adam([p],betas=(.9,.999),eps=1e-8,foreach=False,**kwargs)
        else:opt=torch.optim.AdamW([p],betas=(.9,.999),eps=1e-8,foreach=False,**kwargs)
        values=[p.detach().tolist()]
        for _ in range(3):p.grad=torch.tensor(gradient,dtype=torch.float64);opt.step();values.append(p.detach().tolist())
        replay.append({'kind':kind,'values':values})
    with torch.no_grad():z=model.hidden(X[:8]).detach()
    bn=nn.BatchNorm1d(4,affine=False,momentum=.1,eps=1e-5,dtype=torch.float64)
    train=bn(z);bn.eval();evaluation=bn(z);ln=nn.LayerNorm(4,elementwise_affine=False,eps=1e-5,dtype=torch.float64)
    norms={'input':z.tolist(),'bn_train':train.tolist(),'bn_eval':evaluation.tolist(),'layer_norm':ln(z).tolist(),
        'running_mean':bn.running_mean.tolist(),'running_var':bn.running_var.tolist(),'batch_mean':z.mean(0).tolist(),
        'batch_var_biased':z.var(0,correction=0).tolist(),'batch_var_unbiased':z.var(0,correction=1).tolist(),'eps':1e-5,'momentum':.1}
    return {'initial':initial,'gradient':gradient,'lr':.01,'decay':.1,'beta1':.9,'beta2':.999,'eps':1e-8,'replay':replay},norms

# %% Continuous, fully resumed and weights-only controlled branches
def analyse_source(path,artifact_dir=None):
    module,prepared,X,y,V,vy=source(path)
    with torch.random.fork_rng(devices=[]):
        torch.manual_seed(17);model,opt,scheduler,generator=setup(module)
        optimizers,normalization=lab_evidence(module,X,y,model)
        initial=record(model,X,y,V,vy,0,opt)
        first=advance(model,opt,scheduler,generator,X,y,V,vy,0,20)
        saved=checkpoint(model,opt,scheduler,generator,20,prepared,[initial]+first)
        # Serialize/load even without --artifact-dir: audit actual checkpoint format.
        stream=io.BytesIO();torch.save(saved,stream);stream.seek(0);loaded=torch.load(stream,map_location='cpu',weights_only=True)
        tail=advance(model,opt,scheduler,generator,X,y,V,vy,20,40)
        resumed,ro,rs,rg=restore(module,loaded,prepared)
        resumed_tail=advance(resumed,ro,rs,rg,X,y,V,vy,20,40)
        assert tail==resumed_tail
        for key,v in model.state_dict().items():assert torch.equal(v,resumed.state_dict()[key]),key
        warm,wo,ws,wg=restore(module,loaded,prepared,weights_only=True)
        warm_tail=advance(warm,wo,ws,wg,X,y,V,vy,20,40)
        mismatch=max((v-warm.state_dict()[k]).abs().max().item() for k,v in model.state_dict().items())
        frame,raw,labels,groups,fit,train,val,mean,scale=prepared
        provenance={'source':'UCI Wine Quality, Cortez et al. (2009), CC BY 4.0','sha256':loaded['source_sha256']}
        roles={'inner_train_rows':len(train),'inner_validation_rows':len(val),'inner_train_groups':len(set(groups[train])),'inner_validation_groups':len(set(groups[val]))}
        report={**provenance,**roles,'versions':{'python':platform.python_version(),'torch':torch.__version__,'numpy':np.__version__},'config':CONFIG,
            'initial':initial,'continuous_final':tail[-1],'resumed_final':resumed_tail[-1],'weights_only_final':warm_tail[-1],
            'exact_resume':True,'resume_parameter_max_abs':0.,'weights_only_parameter_max_abs':mismatch,'optimizer_updates':40*13,
            'assumptions':['Existing inner split reused:776 training/190 diagnostic validation; scaler only on inner training.',
                'CPU float64, one fixed recipe; no hyperparameter/seed/early-stopping model selection or outer decision/test scoring.',
                'Epoch-boundary checkpoint at20 after scheduler step, no pending gradients; mid-epoch cursor/workers not covered.',
                'Exact resume is local same-version CPU evidence, not a cross-platform deterministic guarantee.',
                'Weights-only branch restores RNG/order but resets optimizer/scheduler, isolating state loss; this is not a fair candidate ranking.',
                'Optimizer replay repeats a measured8-row gradient on3 selected scalars; no model retraining/performance claim.',
                'BN/LN lab uses actual initial preactivations; neither normalization layer is trained in the main model.']}
        asset={**provenance,**roles,'config':CONFIG,'feature_names':source_features(),'mean':mean.tolist(),'scale':scale.tolist(),
            'source_rows_1based':(train[:8]+1).tolist(),'optimizers':optimizers,'normalization':normalization,
            'continuous_history':[initial]+first+tail,'resumed_history':[initial]+first+resumed_tail,'weights_only_history':[initial]+first+warm_tail,
            'resume_parameter_max_abs':0.,'weights_only_parameter_max_abs':mismatch,'torch_version':torch.__version__}
        if artifact_dir:
            folder=Path(artifact_dir);atomic_checkpoint(folder/'epoch-20.pt',saved)
            folder.joinpath('recipe.json').write_text(json.dumps({'config':CONFIG,'feature_names':source_features(),'mean':mean.tolist(),'scale':scale.tolist(),'source_sha256':loaded['source_sha256']},indent=2)+'\n')
            folder.joinpath('checksums.json').write_text(json.dumps({name:hashlib.sha256((folder/name).read_bytes()).hexdigest() for name in ['epoch-20.pt','recipe.json']},indent=2)+'\n')
    return report,asset

def run_analysis(path,artifact_dir=None):
    previous=torch.get_num_threads()
    try:torch.set_num_threads(1);return analyse_source(path,artifact_dir)
    finally:torch.set_num_threads(previous)

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--write-labs',action='store_true');parser.add_argument('--artifact-dir',type=Path)
    args=parser.parse_args(argv);report,asset=run_analysis(DATA/'winequality-red.csv',args.artifact_dir)
    if args.write_labs:(DATA/'reliable_lab.json').write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);temp=args.output.with_name(args.output.name+'.tmp');temp.write_text(rendered+'\n',encoding='utf-8');temp.replace(args.output)
    print(rendered);return report

if __name__=='__main__':main()
