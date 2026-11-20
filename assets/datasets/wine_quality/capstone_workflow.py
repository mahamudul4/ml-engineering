"""Chapter 14: reproducible grouped Classical ML capstone on original red Wine Quality.

Educational binary target quality>=6; no wine grading, causal or deployment claim.
Fit/CV -> decision validation -> locked final test. Test results are now disclosed;
future tuning needs new untouched evidence. Raw chemistry groups are identity proxies.
"""
# %% Source contract, grouping and role-separated splits
from pathlib import Path
import argparse
import hashlib
import json
import platform
import joblib
import numpy as np
import pandas as pd
import sklearn
from scipy.special import expit
from sklearn.base import clone
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier
from sklearn.ensemble import RandomForestClassifier,HistGradientBoostingClassifier
from sklearn.dummy import DummyClassifier
from sklearn.model_selection import GroupShuffleSplit,StratifiedGroupKFold
from sklearn.metrics import average_precision_score,roc_auc_score,brier_score_loss,confusion_matrix
from sklearn.inspection import permutation_importance
from threadpoolctl import threadpool_limits

DATA=Path(__file__).resolve().parent
SOURCE_HASH='4a402cf041b025d4566d954c3b9ba8635a3a8a01e039005d97d6a710278cf05e'
FEATURES=['fixed acidity','volatile acidity','citric acid','residual sugar','chlorides','free sulfur dioxide','total sulfur dioxide','density','pH','sulphates','alcohol']

def load_source(path):
    if hashlib.sha256(path.read_bytes()).hexdigest()!=SOURCE_HASH:raise ValueError('Expected original red wine source')
    frame=pd.read_csv(path,sep=';')
    if frame.columns.tolist()!=FEATURES+['quality'] or len(frame)!=1599:raise ValueError('Original 11-feature schema and 1599 rows required')
    X=frame[FEATURES].to_numpy(dtype=float,copy=True);quality=frame.quality.to_numpy(dtype=int,copy=True)
    if not np.isfinite(X).all() or not np.isin(quality,np.arange(0,11)).all():raise ValueError('Finite chemistry and valid source quality')
    y=(quality>=6).astype(int)
    # Target deliberately excluded: equal chemistry cannot straddle split roles.
    groups=pd.util.hash_pandas_object(frame[FEATURES],index=False).to_numpy()
    return frame,X,y,groups

def split_roles(X,y,groups):
    development,test=next(GroupShuffleSplit(n_splits=1,test_size=.2,random_state=42).split(X,y,groups))
    fit_local,decision_local=next(GroupShuffleSplit(n_splits=1,test_size=.25,random_state=43).split(X[development],y[development],groups[development]))
    fit,decision=development[fit_local],development[decision_local]
    for left,right in [(fit,decision),(fit,test),(decision,test)]:
        if not set(groups[left]).isdisjoint(groups[right]):raise ValueError('Group overlap')
    for rows in [fit,decision,test]:
        if len(np.unique(y[rows]))!=2:raise ValueError('Both labels required in every split role')
    return fit,decision,test

# %% Auditable metrics, policy and fixed-prediction uncertainty
def binary_inputs(y,p):
    y=np.asarray(y);p=np.asarray(p,dtype=float)
    if y.ndim!=1 or p.shape!=y.shape or not len(y) or not np.isin(y,[0,1]).all() or not np.isfinite(p).all() or ((p<0)|(p>1)).any():raise ValueError('Aligned binary labels and finite probabilities in [0,1]')
    return y.astype(int),p

def policy_metrics(y,p,threshold,*,cost_fp=1.,cost_fn=4.):
    y,p=binary_inputs(y,p)
    if not np.isfinite(threshold) or not 0<=threshold<=1 or not np.isfinite([cost_fp,cost_fn]).all() or min(cost_fp,cost_fn)<0:raise ValueError('Valid probability threshold and nonnegative costs')
    tn,fp,fn,tp=confusion_matrix(y,p>=threshold,labels=[0,1]).ravel()
    return {'tn':int(tn),'fp':int(fp),'fn':int(fn),'tp':int(tp),
        'precision':None if tp+fp==0 else float(tp/(tp+fp)),
        'recall':None if tp+fn==0 else float(tp/(tp+fn)),
        'specificity':None if tn+fp==0 else float(tn/(tn+fp)),
        'accuracy':float((tp+tn)/len(y)),'mean_cost':float((cost_fp*fp+cost_fn*fn)/len(y))}

def probability_metrics(y,p):
    y,p=binary_inputs(y,p)
    return {'ap':None if y.sum()==0 else float(average_precision_score(y,p)),
        'roc_auc':None if len(np.unique(y))<2 else float(roc_auc_score(y,p)),
        'brier':float(brier_score_loss(y,p)),'prevalence':float(y.mean())}

def choose_policy(y,p,*,cost_fp=1.,cost_fn=4.):
    grid=[float(t) for t in np.arange(1,20)/20]
    records=[{'threshold':t,**policy_metrics(y,p,t,cost_fp=cost_fp,cost_fn=cost_fn)} for t in grid]
    # Fixed tie rule: lowest mean cost, then highest threshold (fewer positives).
    selected=min(records,key=lambda row:(row['mean_cost'],-row['threshold']))
    return selected,records

def group_bootstrap(y,p,groups,threshold,*,repeats=300,seed=42):
    y,p=binary_inputs(y,p);groups=np.asarray(groups)
    if groups.shape!=y.shape or not isinstance(repeats,int) or isinstance(repeats,bool) or repeats<1:raise ValueError('Aligned groups and positive bootstrap budget')
    unique=np.unique(groups);members=[np.flatnonzero(groups==g) for g in unique];rng=np.random.default_rng(seed)
    ap=[];cost=[]
    for _ in range(repeats):
        chosen=rng.integers(0,len(unique),size=len(unique));rows=np.concatenate([members[i] for i in chosen])
        if len(np.unique(y[rows]))==2:ap.append(float(average_precision_score(y[rows],p[rows])))
        cost.append(policy_metrics(y[rows],p[rows],threshold)['mean_cost'])
    def interval(values):return None if not values else np.quantile(values,[.025,.975]).tolist()
    return {'resamples':repeats,'ap_defined_resamples':len(ap),'ap_percentile95':interval(ap),'mean_cost_percentile95':interval(cost),
        'scope':'Fixed fitted predictions and locked policy; profile-group exchangeability assumed; not training/search uncertainty'}

def candidate_models():
    return [
        ('prior','Prior baseline',DummyClassifier(strategy='prior')),
        ('logistic_01','Logistic C=0.1',make_pipeline(StandardScaler(),LogisticRegression(C=.1,max_iter=2000,random_state=42))),
        ('logistic_1','Logistic C=1',make_pipeline(StandardScaler(),LogisticRegression(C=1,max_iter=2000,random_state=42))),
        ('tree_4','Decision Tree depth=4',DecisionTreeClassifier(max_depth=4,min_samples_leaf=10,random_state=42)),
        ('forest_6','Random Forest depth=6',RandomForestClassifier(n_estimators=100,max_depth=6,min_samples_leaf=3,n_jobs=1,random_state=42)),
        ('forest_full','Random Forest unrestricted depth',RandomForestClassifier(n_estimators=100,min_samples_leaf=3,n_jobs=1,random_state=42)),
        ('hist_100','Histogram Boosting 100 rounds',HistGradientBoostingClassifier(max_iter=100,max_leaf_nodes=15,min_samples_leaf=20,l2_regularization=1.,early_stopping=False,random_state=42)),
    ]

# %% Fixed-budget experiment, validation diagnostics and single locked test evaluation
def analyse_source(path):
    frame,X,y,groups=load_source(path);fit,decision,test=split_roles(X,y,groups)
    folds=list(StratifiedGroupKFold(n_splits=3,shuffle=True,random_state=44).split(X[fit],y[fit],groups[fit]))
    candidates=[];models={}
    for order,(key,label,template) in enumerate(candidate_models()):
        scores=[]
        for train_local,valid_local in folds:
            fitted=clone(template).fit(X[fit][train_local],y[fit][train_local])
            scores.append(float(average_precision_score(y[fit][valid_local],fitted.predict_proba(X[fit][valid_local])[:,1])))
        models[key]=clone(template).fit(X[fit],y[fit])
        candidates.append({'id':key,'label':label,'declared_order':order,'fold_ap':scores,'mean_ap':float(np.mean(scores)),
            'fold_sd':float(np.std(scores,ddof=1))})
    # Winner uses FIT CV only. The declared order breaks exact score ties.
    winner=min(candidates,key=lambda r:(-r['mean_ap'],r['declared_order']));model=models[winner['id']]
    decision_p=model.predict_proba(X[decision])[:,1];policy,curve=choose_policy(y[decision],decision_p)
    decision_summary={**probability_metrics(y[decision],decision_p),**policy_metrics(y[decision],decision_p,policy['threshold'])}
    importance=permutation_importance(model,X[decision],y[decision],scoring='average_precision',n_repeats=5,random_state=45,n_jobs=1)
    permutation=[{'feature':name,'mean_ap_drop':float(v),'repeat_sd':float(s)} for name,v,s in zip(FEATURES,importance.importances_mean,importance.importances_std)]
    # A fixed secondary logistic ablation; it does not reselect the official winner.
    no_alcohol=np.arange(10);ablation=[]
    for train_local,valid_local in folds:
        secondary=clone(candidate_models()[2][2]).fit(X[fit][train_local][:,no_alcohol],y[fit][train_local])
        ablation.append(float(average_precision_score(y[fit][valid_local],secondary.predict_proba(X[fit][valid_local][:,no_alcohol])[:,1])))
    logistic=models['logistic_1'];scaler=logistic[0];lr=logistic[1]
    queries=[]
    for i in decision[:24]:
        z=scaler.transform(X[i:i+1])[0];contributions=z*lr.coef_[0];logit=float(lr.intercept_[0]+contributions.sum());p=float(expit(logit))
        np.testing.assert_allclose(p,logistic.predict_proba(X[i:i+1])[0,1],atol=1e-12)
        queries.append({'source_row_1based':int(i+1),'quality':int(frame.quality.iloc[i]),'positive':int(y[i]),'values':X[i].tolist(),'logit':logit,'probability':p})
    error_rows=[]
    for label in ['fp','fn']:
        predicted=decision_p>=policy['threshold'];mask=(predicted & (y[decision]==0)) if label=='fp' else (~predicted & (y[decision]==1))
        local=np.flatnonzero(mask);local=sorted(local,key=lambda i:-decision_p[i] if label=='fp' else decision_p[i])[:5]
        error_rows += [{'kind':label,'source_row_1based':int(decision[j]+1),'quality':int(frame.quality.iloc[decision[j]]),'probability':float(decision_p[j])} for j in local]
    # No test outcomes were used above. Evaluate the locked model/policy now.
    test_p=model.predict_proba(X[test])[:,1]
    final_test={**probability_metrics(y[test],test_p),**policy_metrics(y[test],test_p,policy['threshold'])}
    bootstrap=group_bootstrap(y[test],test_p,groups[test],policy['threshold'])
    schema={'feature_names':FEATURES,'feature_count':11,'dtype':'finite float64','missing':'reject','target_rule':'quality >= 6; sensory label, not objective grading truth','source_sha256':SOURCE_HASH}
    provenance={'source':'UCI Wine Quality, Cortez et al. (2009), CC BY 4.0','sha256':SOURCE_HASH}
    role_report={name:{'rows':len(rows),'groups':int(len(np.unique(groups[rows]))),'positive':int(y[rows].sum())} for name,rows in [('fit',fit),('decision',decision),('test',test)]}
    asset={**provenance,'scope':'FIT-CV board and decision-validation predictions only; final-test rows excluded from labs',
        'candidates':candidates,'selected_id':winner['id'],'locked_threshold':policy['threshold'],'cost_fp':1.,'cost_fn':4.,
        'decision_predictions':[{'source_row_1based':int(i+1),'quality':int(frame.quality.iloc[i]),'positive':int(y[i]),'probability':float(p)} for i,p in zip(decision,decision_p)],
        'policy_reference':curve,
        'selected_reference':{'model_id':winner['id'],'queries':[{'source_row_1based':q['source_row_1based'],'values':q['values'],'probability':float(p)} for q,p in zip(queries,model.predict_proba(X[decision[:24]])[:,1])]},
        'logistic_reference':{'model_id':'logistic_1','feature_names':FEATURES,'mean':scaler.mean_.tolist(),'scale':scaler.scale_.tolist(),'weights':lr.coef_[0].tolist(),'bias':float(lr.intercept_[0]),'queries':queries}}
    report={**provenance,'versions':{'python':platform.python_version(),'numpy':np.__version__,'pandas':pd.__version__,'sklearn':sklearn.__version__},
        'source_rows':len(X),'unique_chemistry_groups':int(len(np.unique(groups))),'roles':role_report,'target':'quality >= 6',
        'selection':'Highest mean FIT-only grouped CV AP; exact tie by declared order; no decision/test model selection',
        'candidates':candidates,'selected_id':winner['id'],'policy_selection':policy,'decision_metrics':decision_summary,
        'decision_permutation_importance':permutation,'secondary_logistic_no_alcohol_cv_ap':float(np.mean(ablation)),
        'decision_error_cases':error_rows,'locked_final_test':final_test,'fixed_prediction_group_bootstrap':bootstrap,
        'assumptions':['Identical chemistry groups exclude quality; proxies are not verified bottle/batch/person identities.',
            'All splits are group-separated random development roles, not chronological or external-domain validation.',
            'Six learned candidates plus prior baseline; preprocessing fits within each training fold; fixed seeds and budget.',
            'Illustrative FP1/FN4 costs and threshold grid0.05..0.95 are not measured business costs; probabilities not calibrated here.',
            'Selected model stays fit-role trained after policy lock; no silent full-development refit shifts its probability mapping.',
            'Test evaluated after locking; its published results are now observed and must not guide further tuning claims.',
            'Conditional bootstrap omits training/search variability; correlated chemistry, subjective labels and domain shifts limit interpretation.']}
    return report,asset,model,schema

def run_analysis(path):
    with threadpool_limits(limits=1):return analyse_source(path)

def write_artifacts(folder,report,asset,model,schema):
    folder.mkdir(parents=True,exist_ok=True)
    card={'intended_use':'Offline educational binary-classification capstone; no grading/deployment claim','source':report['source'],
        'roles':report['roles'],'selection':report['selection'],'selected_id':report['selected_id'],'locked_threshold':asset['locked_threshold'],
        'cost_fp':1.,'cost_fn':4.,'locked_final_test':report['locked_final_test'],'limitations':report['assumptions']}
    manifest={'source_sha256':SOURCE_HASH,'versions':report['versions'],'candidates':report['candidates'],'threshold':asset['locked_threshold']}
    for name,value in [('model_card.json',card),('feature_schema.json',schema),('selection_manifest.json',manifest),('reference_queries.json',asset['selected_reference'])]:
        (folder/name).write_text(json.dumps(value,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    # This locally generated trusted artifact is a Python environment deliverable,
    # not a mobile runtime dependency. Do not load arbitrary external pickle files.
    joblib.dump(model,folder/'model.joblib')
    names=['model_card.json','feature_schema.json','selection_manifest.json','reference_queries.json','model.joblib']
    hashes={name:hashlib.sha256((folder/name).read_bytes()).hexdigest() for name in names}
    (folder/'checksums.json').write_text(json.dumps(hashes,indent=2)+'\n',encoding='utf-8')
    return hashes

# %% Import-safe CLI and explicit artifact/asset outputs
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--artifact-dir',type=Path);parser.add_argument('--write-labs',action='store_true')
    args=parser.parse_args(argv);report,asset,model,schema=run_analysis(DATA/'winequality-red.csv')
    if args.write_labs:(DATA/'capstone_lab.json').write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    if args.artifact_dir:write_artifacts(args.artifact_dir,report,asset,model,schema)
    rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);temporary=args.output.with_name(args.output.name+'.tmp')
        temporary.write_text(rendered+'\n',encoding='utf-8');temporary.replace(args.output)
    print(rendered);return report

if __name__=='__main__':main()
