"""Chapter15 offline CPU tensor/autograd audit on the existing Wine Quality fit role.

Training-only numerical checks, not a new generalization benchmark. Chapter14's
published test stays observed; no decision/test predictions or metrics are added.
"""
# %% Source reuse, explicit CPU/dtype and immutable feature provenance
from pathlib import Path
import argparse
import importlib.util
import json
import platform
import sys
import numpy as np
import torch
import torch.nn.functional as F
from torch.utils.data import TensorDataset,DataLoader

DATA=Path(__file__).resolve().parent

def load_fit(path):
    spec=importlib.util.spec_from_file_location('ch15_source_contract',path.with_name('capstone_workflow.py'))
    contract=importlib.util.module_from_spec(spec);sys.modules[spec.name]=contract;spec.loader.exec_module(contract)
    frame,X,y,groups=contract.load_source(path);fit,_,_=contract.split_roles(X,y,groups)
    reference=json.loads(path.with_name('capstone_lab.json').read_text(encoding='utf-8'))['logistic_reference']
    if reference['feature_names']!=contract.FEATURES:raise ValueError('Ordered feature schema mismatch')
    mean=np.asarray(reference['mean']);scale=np.asarray(reference['scale'])
    np.testing.assert_allclose(mean,X[fit].mean(axis=0),atol=1e-12)
    np.testing.assert_allclose(scale,X[fit].std(axis=0,ddof=0),atol=1e-12)
    Z=(X[fit]-mean)/scale
    return frame,X,y,groups,fit,reference,Z

# %% Exact-shape objectives and independent analytical gradients
def tensors(X,y,w,b):
    if X.ndim!=2 or y.shape!=(X.shape[0],) or w.shape!=(X.shape[1],) or b.ndim!=0 or X.shape[0]<1:raise ValueError('X[B,D],y[B],w[D],scalar b required')
    if any(t.device.type!='cpu' or t.dtype!=torch.float64 or not torch.isfinite(t).all().item() for t in [X,y,w,b]):raise ValueError('Finite CPU float64 contract')
    if not torch.all((y==0)|(y==1)).item():raise ValueError('Binary targets')
    return X,y,w,b

def objective(X,y,w,b):
    X,y,w,b=tensors(X,y,w,b)
    return F.binary_cross_entropy_with_logits(X@w+b,y,reduction='mean')

def analytic_gradient(X,y,w,b):
    X,y,w,b=tensors(X,y,w,b)
    with torch.no_grad():
        residual=torch.sigmoid(X@w+b)-y
        return X.T@residual/len(y),residual.mean()

def finite_gradient(X,y,w,b,eps=1e-6):
    if not np.isfinite(eps) or eps<=0:raise ValueError('Positive finite difference epsilon')
    result=torch.empty_like(w)
    with torch.no_grad():
        for j in range(len(w)):
            direction=torch.zeros_like(w);direction[j]=eps
            result[j]=(objective(X,y,w+direction,b)-objective(X,y,w-direction,b))/(2*eps)
        gb=(objective(X,y,w,b+eps)-objective(X,y,w,b-eps))/(2*eps)
    return result,gb

def mse_shape_audit(probability,target):
    if probability.ndim!=1 or probability.shape!=target.shape or len(target)<1:raise ValueError('Aligned batch vectors')
    correct=probability-target
    wrong=probability-target[:,None]  # Deliberately wrong pairwise broadcast.
    return {'batch':len(target),'correct_shape':list(correct.shape),'wrong_shape':list(wrong.shape),
        'correct_residual':correct.tolist(),'wrong_residual':wrong.tolist(),
        'correct_mse':float(correct.square().mean()),'wrong_mse':float(wrong.square().mean())}

# %% Real-observation layouts, broadcasting evidence and autograd audit
def analyse_source(path):
    frame,raw,y,groups,fit,reference,Z=load_fit(path)
    X=torch.tensor(Z,dtype=torch.float64,device='cpu');target=torch.tensor(y[fit],dtype=torch.float64)
    w=torch.zeros(X.shape[1],dtype=torch.float64,requires_grad=True);bias=torch.zeros((),dtype=torch.float64,requires_grad=True)
    loss=objective(X,target,w,bias);gw,gb=torch.autograd.grad(loss,(w,bias))
    aw,ab=analytic_gradient(X,target,w,bias);fw,fb=finite_gradient(X,target,w,bias)
    torch.testing.assert_close(gw,aw,atol=1e-12,rtol=1e-12);torch.testing.assert_close(gb,ab,atol=1e-12,rtol=1e-12)
    torch.testing.assert_close(gw,fw,atol=1e-8,rtol=1e-8);torch.testing.assert_close(gb,fb,atol=1e-8,rtol=1e-8)
    checked=torch.autograd.gradcheck(lambda p,q:objective(X[:32],target[:32],p,q),(w,bias),eps=1e-6,atol=1e-5,rtol=1e-3)
    with torch.no_grad():after=float(objective(X,target,w-.1*gw,bias-.1*gb))
    loader=DataLoader(TensorDataset(X,target,torch.tensor(fit)),batch_size=16,shuffle=True,generator=torch.Generator().manual_seed(42),num_workers=0)
    first_X,first_y,first_rows=next(iter(loader))
    # A 4x3 raw source matrix for storage/stride inspection, not a training model.
    columns=[10,1,9];base=torch.tensor(raw[fit[:4]][:,columns],dtype=torch.float64).contiguous()
    layouts=[]
    for name,view in [('original',base),('transpose',base.T),('slice',base[:,::2]),('expand',base[:,:1].expand(4,3))]:
        indices=[[view.storage_offset()+i*view.stride(0)+j*view.stride(1) for j in range(view.shape[1])] for i in range(view.shape[0])]
        copy=view.contiguous()
        layouts.append({'name':name,'shape':list(view.shape),'stride':list(view.stride()),'storage_offset':view.storage_offset(),
            'contiguous':view.is_contiguous(),'values':view.tolist(),'storage_indices':indices,
            'after_contiguous_stride':list(copy.stride()),'contiguous_shares_storage':copy.untyped_storage().data_ptr()==view.untyped_storage().data_ptr()})
    fit_w=torch.tensor(reference['weights'],dtype=torch.float64);fit_bias=torch.tensor(reference['bias'],dtype=torch.float64)
    probability=torch.sigmoid(X[:4]@fit_w+fit_bias);broadcast=[]
    for batch in [1,2,4]:
        record=mse_shape_audit(probability[:batch],target[:batch])
        try:F.binary_cross_entropy_with_logits(X[:batch]@fit_w+fit_bias,target[:batch,None])
        except (ValueError,RuntimeError) as error:record['bce_shape_error']=type(error).__name__
        else:raise AssertionError('Expected strict BCE shape rejection')
        broadcast.append(record)
    # Separate two-feature BCE microscope, zero/reference parameters are declared
    # illustrative choices on real training observations, not a fitted classifier.
    micro_X=X[:16][:,[10,1]].contiguous();micro_y=target[:16];gradient_refs=[]
    for theta in [[0.,0.,0.],[.5,-.25,.1],[1.,.5,-.2]]:
        mw=torch.tensor(theta[:2],dtype=torch.float64,requires_grad=True);mb=torch.tensor(theta[2],dtype=torch.float64,requires_grad=True)
        ml=objective(micro_X,micro_y,mw,mb);dw,db=torch.autograd.grad(ml,(mw,mb));analytic_w,analytic_b=analytic_gradient(micro_X,micro_y,mw,mb)
        torch.testing.assert_close(dw,analytic_w);torch.testing.assert_close(db,analytic_b)
        gradient_refs.append({'parameters':theta,'loss':float(ml.detach()),'gradient':dw.tolist()+[float(db)]})
    # Explicit graph lifecycle / accumulation evidence on a scalar illustration.
    scalar=torch.tensor(3.,dtype=torch.float64,requires_grad=True)
    for _ in range(2):(scalar.square()+2*scalar).backward()  # Fresh graph each time.
    accumulated=float(scalar.grad);scalar.grad=None;(scalar.square()+2*scalar).backward();cleared=float(scalar.grad)
    u=torch.tensor([1.,2.],dtype=torch.float64,requires_grad=True);v=u.square();seed=torch.tensor([3.,4.],dtype=torch.float64)
    vjp=torch.autograd.grad(v,u,grad_outputs=seed)[0]
    provenance={'source':'UCI Wine Quality, Cortez et al. (2009), CC BY 4.0','sha256':'4a402cf041b025d4566d954c3b9ba8635a3a8a01e039005d97d6a710278cf05e'}
    samples=[{'source_row_1based':int(i+1),'quality':int(frame.quality.iloc[i]),'positive':int(y[i]),'raw':raw[i].tolist(),'standardized':Z[j].tolist()} for j,i in enumerate(fit[:16])]
    asset={**provenance,'scope':'Existing Chapter14 fit role only; first16 actual training rows, no decision/test rows or new predictive evaluation',
        'feature_names':reference['feature_names'],'mean':reference['mean'],'scale':reference['scale'],'reference_weights':reference['weights'],'reference_bias':reference['bias'],
        'samples':samples,'layout_columns':columns,'layout_storage':base.flatten().tolist(),'layouts':layouts,'broadcast_references':broadcast,
        'gradient_columns':[10,1],'gradient_references':gradient_refs,'dtype':'float64','itemsize':8,'torch_version':torch.__version__}
    report={**provenance,'versions':{'python':platform.python_version(),'torch':torch.__version__,'numpy':np.__version__},'device':'cpu','dtype':'float64',
        'fit_rows':len(fit),'features':11,'gradcheck_passed':bool(checked),'zero_parameter_mean_bce':float(loss.detach()),
        'autograd_gradient':gw.tolist()+[float(gb)],'analytic_max_abs_error':float(torch.max(torch.abs(gw-aw))),
        'finite_difference_max_abs_error':max(float(torch.max(torch.abs(gw-fw))),float(torch.abs(gb-fb))),
        'one_manual_step_lr':.1,'one_manual_step_mean_bce':after,'first_shuffled_loader_source_rows_1based':(first_rows+1).tolist(),
        'loader_batch_shape':list(first_X.shape),'loader_target_shape':list(first_y.shape),'grad_accumulated_two_graphs':accumulated,'grad_after_none_then_backward':cleared,
        'vjp_seed':seed.tolist(),'vjp_result':vjp.tolist(),'layout_summary':[{k:r[k] for k in ['name','shape','stride','contiguous','contiguous_shares_storage']} for r in layouts],
        'broadcast_summary':[{k:r[k] for k in ['batch','correct_shape','wrong_shape','correct_mse','wrong_mse','bce_shape_error']} for r in broadcast],
        'assumptions':['Existing source/target/group split reused; preprocessing reference checked against966 fit-only rows.',
            'CPU float64 numerical audit; CUDA/MPS/AMP performance and reproducibility not tested.',
            'Layout/storage indices are element offsets, not byte addresses; expanded views can overlap.',
            'Broadcast MSE is a deliberately broken loss example; production BCE helper enforces exact batch shapes.',
            'The16-row two-feature microscope uses declared illustrative parameter values on real observations, not a selected fitted model.',
            'Gradient accumulation scalar examples are explicitly mathematical illustrations, not empirical data.',
            'No decision/test metrics or new model-selection claims; published Chapter14 test remains observed.']}
    return report,asset

def run_analysis(path):
    previous=torch.get_num_threads()
    try:
        torch.set_num_threads(1)
        return analyse_source(path)
    finally:torch.set_num_threads(previous)

# %% Import-safe CLI, explicit lab-asset regeneration and atomic report write
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--write-labs',action='store_true')
    args=parser.parse_args(argv);report,asset=run_analysis(DATA/'winequality-red.csv')
    if args.write_labs:(DATA/'tensor_lab.json').write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);temporary=args.output.with_name(args.output.name+'.tmp')
        temporary.write_text(rendered+'\n',encoding='utf-8');temporary.replace(args.output)
    print(rendered);return report

if __name__=='__main__':main()
