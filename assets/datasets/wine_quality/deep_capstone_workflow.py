"""Chapter21 White Wine Quality capstone: grouped selection and locked test.

Educational quality>=6 target. Exact chemistry profiles are identity proxies.
Published test outcomes become observed; future tuning needs fresh evidence.
"""
# %% Original white-wine source, identity proxies and role-separated groups
from pathlib import Path
import argparse,copy,hashlib,importlib.util,json,platform,sys
import joblib,numpy as np,pandas as pd,sklearn,torch
from torch import nn
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import GroupShuffleSplit,StratifiedGroupKFold
from sklearn.metrics import average_precision_score
from threadpoolctl import threadpool_limits
DATA=Path(__file__).resolve().parent
HASH='76c3f809815c17c07212622f776311faeb31e87610d52c26d87d6e361b169836'
FEATURES=['fixed acidity','volatile acidity','citric acid','residual sugar','chlorides','free sulfur dioxide','total sulfur dioxide','density','pH','sulphates','alcohol']
spec=importlib.util.spec_from_file_location('ch21_policy_helpers',DATA/'capstone_workflow.py');helpers=importlib.util.module_from_spec(spec);sys.modules[spec.name]=helpers;spec.loader.exec_module(helpers)
policy_metrics,probability_metrics,choose_policy,group_bootstrap=helpers.policy_metrics,helpers.probability_metrics,helpers.choose_policy,helpers.group_bootstrap

def load_source(path):
    path=Path(path)
    if hashlib.sha256(path.read_bytes()).hexdigest()!=HASH:raise ValueError('Original white-wine bytes required')
    frame=pd.read_csv(path,sep=';')
    if frame.columns.tolist()!=FEATURES+['quality'] or frame.shape!=(4898,12):raise ValueError('4898-row white-wine ordered schema')
    X=frame[FEATURES].to_numpy(dtype=float,copy=True);quality=frame.quality.to_numpy(dtype=int,copy=True)
    if not np.isfinite(X).all() or not np.isin(quality,np.arange(11)).all():raise ValueError('Finite chemistry and sensory scores')
    groups=pd.util.hash_pandas_object(frame[FEATURES],index=False).to_numpy()
    return frame,X,(quality>=6).astype(int),groups

def split_roles(X,y,groups):
    development,test=next(GroupShuffleSplit(n_splits=1,test_size=.2,random_state=21).split(X,y,groups))
    f,d=next(GroupShuffleSplit(n_splits=1,test_size=.25,random_state=22).split(X[development],y[development],groups[development]))
    roles={'fit':development[f],'decision':development[d],'test':test}
    for left in roles:
        if len(np.unique(y[roles[left]]))!=2:raise ValueError('Both labels in each role')
        for right in roles:
            if left!=right and not set(groups[roles[left]]).isdisjoint(groups[roles[right]]):raise ValueError('Exact-profile group overlap')
    return roles

# %% Registered MLP, fit-only preprocessing and fixed-budget candidates
class WineMLP(nn.Module):
    def __init__(self):
        super().__init__();self.hidden=nn.Linear(11,8,dtype=torch.float64);self.output=nn.Linear(8,1,dtype=torch.float64)
    def forward(self,X):
        if X.ndim!=2 or X.shape[1]!=11 or not torch.isfinite(X).all():raise ValueError('Finite X[B,11]')
        return self.output(torch.relu(self.hidden(X))).squeeze(-1)

def weights(model):
    return {'w1':model.hidden.weight.detach().tolist(),'b1':model.hidden.bias.detach().tolist(),'w2':model.output.weight.detach()[0].tolist(),'b2':model.output.bias.detach().item()}

def fit_mlp(X,y,scaled=True):
    if X.ndim!=2 or X.shape[1]!=11 or y.shape!=(len(X),) or not np.isfinite(X).all() or not np.isin(y,[0,1]).all():raise ValueError('Aligned finite fit data')
    scaler=StandardScaler().fit(X) if scaled else None
    mean=scaler.mean_.copy() if scaled else np.zeros(11);scale=scaler.scale_.copy() if scaled else np.ones(11)
    x=torch.tensor((X-mean)/scale,dtype=torch.float64);target=torch.tensor(y,dtype=torch.float64)
    with torch.random.fork_rng(devices=[]):
        torch.manual_seed(21);model=WineMLP();initial=weights(model)
        optimizer=torch.optim.AdamW(model.parameters(),lr=.01,weight_decay=.001,foreach=False);history=[]
        for epoch in range(81):
            model.eval()
            with torch.no_grad():history.append({'epoch':epoch,'train_bce':nn.functional.binary_cross_entropy_with_logits(model(x),target).item()})
            if epoch==80:break
            model.train();optimizer.zero_grad(set_to_none=True);loss=nn.functional.binary_cross_entropy_with_logits(model(x),target);loss.backward();nn.utils.clip_grad_norm_(model.parameters(),1.,error_if_nonfinite=True);optimizer.step()
    model.eval()
    return {'model':model,'mean':mean,'scale':scale,'history':history,'initial':initial,'scaled':scaled}

def fit_candidate(name,X,y):
    if name=='prior':return {'prior':float(y.mean())}
    if name=='logistic':return make_pipeline(StandardScaler(),LogisticRegression(C=1.,max_iter=2000,random_state=21)) .fit(X,y)
    if name=='mlp':return fit_mlp(X,y)
    raise ValueError('Declared candidate')

def predict(name,model,X):
    if name=='prior':return np.full(len(X),model['prior'])
    if name=='logistic':return model.predict_proba(X)[:,1]
    with torch.no_grad():return model['model'](torch.tensor((X-model['mean'])/model['scale'],dtype=torch.float64)).sigmoid().numpy()

# %% Fit-only grouped selection, decision policy, then one locked test stage
def analyse_source(path,artifact_dir=None):
    frame,X,y,groups=load_source(path);roles=split_roles(X,y,groups);fit,decision,test=[roles[k] for k in ['fit','decision','test']]
    folds=list(StratifiedGroupKFold(3,shuffle=True,random_state=23).split(X[fit],y[fit],groups[fit]));names=['prior','logistic','mlp'];candidates=[];models={}
    for order,name in enumerate(names):
        scores=[]
        for tr,va in folds:
            model=fit_candidate(name,X[fit][tr],y[fit][tr]);scores.append(float(average_precision_score(y[fit][va],predict(name,model,X[fit][va]))))
        candidates.append({'id':name,'declared_order':order,'fold_ap':scores,'mean_ap':float(np.mean(scores))});models[name]=fit_candidate(name,X[fit],y[fit])
    winner=min(candidates,key=lambda r:(-r['mean_ap'],r['declared_order']))['id']
    decision_predictions={name:predict(name,models[name],X[decision]) for name in names}
    locked,curve=choose_policy(y[decision],decision_predictions[winner]);threshold=locked['threshold']
    decision_summary={name:{**probability_metrics(y[decision],p),**policy_metrics(y[decision],p,threshold)} for name,p in decision_predictions.items()}
    # Declared diagnostic ablation. It never enters candidate selection or policy tuning.
    raw=fit_mlp(X[fit],y[fit],scaled=False);raw_p=predict('mlp',raw,X[decision]);ablation={**probability_metrics(y[decision],raw_p),**policy_metrics(y[decision],raw_p,threshold)}
    # Winner, transform, terminal checkpoint and threshold are locked above.
    final_p=predict(winner,models[winner],X[test]);final={**probability_metrics(y[test],final_p),**policy_metrics(y[test],final_p,threshold)}
    intervals=group_bootstrap(y[test],final_p,groups[test],threshold,repeats=200,seed=24)
    counts={k:{'rows':len(v),'groups':len(np.unique(groups[v])),'positives':int(y[v].sum())} for k,v in roles.items()}
    report={'source':'White Wine Quality, Cortez et al. (2009), UCI, CC BY4.0','sha256':HASH,'versions':{'python':platform.python_version(),'torch':torch.__version__,'numpy':np.__version__,'sklearn':sklearn.__version__},'device':'cpu','dtype':'float64','rows':len(X),'unique_profiles':len(np.unique(groups)),'roles':counts,'candidates':candidates,'winner':winner,'threshold':threshold,'decision':decision_summary,'no_scale_diagnostic':ablation,'final_test':final,'fixed_prediction_group_bootstrap':intervals,'mlp_parameters':105,'recipe':{'seed':21,'updates':80,'learning_rate':.01,'weight_decay':.001,'clip_norm':1.,'hidden':8,'full_batch':True},'initial_train_bce':models['mlp']['history'][0]['train_bce'],'final_train_bce':models['mlp']['history'][-1]['train_bce'],'assumptions':['Educational binary target quality>=6 from subjective sensory scores; not objective/commercial grading.','Exact chemistry profiles group duplicates; bottle/batch/producer/time independence is not established.','Three fixed candidates selected only by three fit-role grouped CV mean AP; declared order breaks exact ties.','Each CV scaler fits its training fold; refit scaler/model use fit role only.','Decision role alone selects threshold grid.05..95 under illustrative FP1/FN4 costs, highest threshold breaks cost ties.','No fit+decision refit after threshold selection; selected terminal checkpoint and policy remain unchanged.','No-scale MLP is a separately trained fixed diagnostic ablation with common initial weights/budget, not a selection candidate.','Final test assessed only after locks; published outcomes are now observed and re-audits are not new confirmation.','Group bootstrap assumes exchangeable profile groups and fixed fitted predictions/policy; excludes training/search uncertainty.','No wine recommendation, causal chemistry, calibrated probability or production deployment claim.']}
    # Fixed all-positive action reference from the already disclosed test counts.
    # This diagnostic comparison does not reselect either the model or threshold.
    report['final_all_positive_reference']={'tn':0,'fp':int((y[test]==0).sum()),'fn':0,'tp':int(y[test].sum()),'mean_cost':float((y[test]==0).mean()),'scope':'Fixed all-positive diagnostic reference; no policy reselection'}
    selected_rows=[{'source_row_1based':int(i+1),'quality':int(frame.quality.iloc[i]),'positive':int(y[i]),'probability':float(p)} for i,p in zip(decision,decision_predictions[winner])]
    # First three decision rows in source order; not selected for correct predictions.
    samples=[]
    for i in sorted(decision)[:3]:
        entry={'source_row_1based':int(i+1),'quality':int(frame.quality.iloc[i]),'raw':X[i].tolist(),'references':[]}
        for name,model in [('scaled',models['mlp']),('no_scale',raw)]:
            z=(X[i]-model['mean'])/model['scale']
            with torch.no_grad():hidden_pre=model['model'].hidden(torch.tensor(z,dtype=torch.float64));hidden=hidden_pre.relu();logit=model['model'].output(hidden).item()
            entry['references'].append({'id':name,'standardized':z.tolist(),'pre':hidden_pre.tolist(),'hidden':hidden.tolist(),'logit':logit,'probability':float(torch.sigmoid(torch.tensor(logit,dtype=torch.float64)))})
        samples.append(entry)
    mlp=models['mlp']
    pipelines=[{'id':name,'mean':m['mean'].tolist(),'scale':m['scale'].tolist(),'weights':weights(m['model']),'initial':m['initial'],'history':m['history']} for name,m in [('scaled',mlp),('no_scale',raw)]]
    selection={'primary_metric':'mean grouped CV AP','candidates':candidates,'winner':winner,'threshold':threshold,'cost_fp':1.,'cost_fn':4.,'tie_rule':'declared candidate order; highest threshold on cost ties','test_rows_in_labs':0}
    asset={'source':report['source'],'sha256':HASH,'features':FEATURES,'dtype':'float64','parameter_count':105,'roles':counts,'selection':selection,'decision_rows':selected_rows,'policy_curve':curve,'decision_metrics':decision_summary,'no_scale_metrics':ablation,'pipelines':pipelines,'samples':samples,'fit_rows_1based':(fit+1).tolist(),'decision_rows_1based':(decision+1).tolist()}
    if artifact_dir:
        folder=Path(artifact_dir);folder.mkdir(parents=True,exist_ok=True)
        torch.save(mlp['model'].state_dict(),folder/'mlp.pt');torch.save(raw['model'].state_dict(),folder/'no_scale.pt');joblib.dump(models['logistic'],folder/'logistic.joblib')
        documents={'schema.json':{'features':FEATURES,'mean':mlp['mean'].tolist(),'scale':mlp['scale'].tolist(),'dtype':'float64','target':'quality>=6','source_sha256':HASH,'parameters':105},'selection.json':selection,'model_card.json':{'winner':winner,'threshold':threshold,'roles':counts,'final_test':final,'final_all_positive_reference':report['final_all_positive_reference'],'limitations':report['assumptions']},'golden.json':samples}
        for name,value in documents.items():(folder/name).write_text(json.dumps(value,indent=2,allow_nan=False)+'\n',encoding='utf-8')
        (folder/'checksums.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(folder.iterdir()) if p.is_file() and p.name!='checksums.json'},indent=2)+'\n')
    return report,asset

def run_analysis(path,artifact_dir=None):
    threads=torch.get_num_threads()
    try:
        torch.set_num_threads(1)
        with torch.random.fork_rng(devices=[]),threadpool_limits(limits=1):return analyse_source(path,artifact_dir)
    finally:torch.set_num_threads(threads)

# %% Import-safe CLI and explicit lab regeneration
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--write-labs',action='store_true');parser.add_argument('--artifact-dir',type=Path);args=parser.parse_args(argv)
    report,asset=run_analysis(DATA/'winequality-white.csv',args.artifact_dir)
    if args.write_labs:(DATA/'deep_capstone_lab.json').write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);temp=args.output.with_name(args.output.name+'.tmp');temp.write_text(rendered+'\n',encoding='utf-8');temp.replace(args.output)
    print(rendered);return report
if __name__=='__main__':main()
