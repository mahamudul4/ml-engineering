"""Chapter 10 offline ensemble development audit; UCI Adult, CC BY 4.0.

Original local adult.data only, no adult.test/network. Historical source reused
throughout this curriculum; diagnostics are not fresh confirmation or causality.
"""
# %% Source contract, shared group split and bounded compute
from pathlib import Path
import argparse
import hashlib
import json
import platform
import numpy as np
import pandas as pd
import sklearn
from scipy.special import expit
from threadpoolctl import threadpool_limits
from sklearn.model_selection import GroupShuffleSplit, StratifiedGroupKFold
from sklearn.tree import DecisionTreeClassifier, DecisionTreeRegressor
from sklearn.ensemble import BaggingClassifier, RandomForestClassifier, HistGradientBoostingClassifier, AdaBoostClassifier, GradientBoostingRegressor
from sklearn.dummy import DummyClassifier
from sklearn.metrics import accuracy_score, average_precision_score, brier_score_loss, mean_squared_error

DATA=Path(__file__).resolve().parent
SOURCE_HASH='5b00264637dbfec36bdeaab5676b0b309ff9eb788d63554ca0a249491c86603d'
COLUMNS=['age','workclass','fnlwgt','education','education_num','marital_status','occupation','relationship','race','sex','capital_gain','capital_loss','hours_per_week','native_country','income']
FEATURES=['age','education_num','capital_gain','capital_loss','hours_per_week']

def load_source(path):
    digest=hashlib.sha256(path.read_bytes()).hexdigest()
    if digest!=SOURCE_HASH: raise ValueError('Expected original adult.data')
    frame=pd.read_csv(path,names=COLUMNS,skipinitialspace=True,na_values='?')
    label=frame['income'].astype('string').str.strip()
    if not label.isin(['<=50K','>50K']).all(): raise ValueError('Binary label contract')
    X=frame[FEATURES].to_numpy(dtype=float,copy=True)
    if not np.isfinite(X).all(): raise ValueError('Finite numeric features required')
    y=(label=='>50K').to_numpy(dtype=int)
    keys=frame[[c for c in COLUMNS if c not in ('income','hours_per_week')]].astype('string').fillna('__MISSING__')
    groups=pd.util.hash_pandas_object(keys,index=False).to_numpy()
    return frame,X,y,groups,digest

# %% Transparent binary AdaBoost and squared-loss gradient boosting
def adaboost_step(y,prediction,weights):
    y,prediction,weights=np.asarray(y),np.asarray(prediction),np.asarray(weights,dtype=float)
    if (y.ndim!=1 or len(y)==0 or prediction.shape!=y.shape or weights.shape!=y.shape or
        not np.isin(y,[-1,1]).all() or not np.isin(prediction,[-1,1]).all() or
        not np.isfinite(weights).all() or np.any(weights<0) or not np.isfinite(weights.sum()) or weights.sum()<=0):
        raise ValueError('Aligned signed labels/predictions and finite nonnegative weights')
    normalized=weights/weights.sum(); wrong=y!=prediction
    error=float(normalized[wrong].sum())
    if error==0: return {'error':0.,'alpha':None,'weights':normalized.copy(),'status':'perfect_stop'}
    if error>=.5: return {'error':error,'alpha':None,'weights':normalized.copy(),'status':'reject_weak_learner'}
    alpha=.5*(np.log1p(-error)-np.log(error))
    log_weight=np.full(len(y),-np.inf)
    positive=normalized>0
    log_weight[positive]=np.log(normalized[positive])-alpha*y[positive]*prediction[positive]
    updated=np.exp(log_weight-np.max(log_weight)); updated/=updated.sum()
    return {'error':error,'alpha':float(alpha),'weights':updated,'status':'updated'}

def fit_squared_boost(X,y,*,rounds=16,rate=.1,min_leaf=100):
    X,y=np.asarray(X,dtype=float),np.asarray(y,dtype=float)
    if (X.ndim!=2 or min(X.shape)<1 or y.shape!=(len(X),) or
        not np.isfinite(X).all() or not np.isfinite(y).all() or
        not isinstance(rounds,int) or isinstance(rounds,bool) or not 0<=rounds<=100 or
        not np.isfinite(rate) or not 0<rate<=1 or
        not isinstance(min_leaf,int) or isinstance(min_leaf,bool) or min_leaf<1):
        raise ValueError('Finite aligned data, bounded rounds/rate and positive min_leaf')
    base=float(y.mean()); fitted=np.full(len(y),base); trees=[]; training_rmse=[float(np.sqrt(np.mean((y-fitted)**2)))]
    for stage in range(rounds):
        residual=y-fitted  # Negative gradient of (y-F)^2/2.
        tree=DecisionTreeRegressor(max_depth=2,min_samples_leaf=min_leaf,random_state=42).fit(X,residual)
        fitted+=rate*tree.predict(X); trees.append(tree)
        training_rmse.append(float(np.sqrt(np.mean((y-fitted)**2))))
    return {'base':base,'rate':rate,'trees':trees,'features':X.shape[1],'training_rmse':training_rmse}

def staged_squared_predict(model,X):
    X=np.asarray(X,dtype=float)
    if X.ndim!=2 or X.shape[1]!=model['features'] or not np.isfinite(X).all(): raise ValueError('Prediction schema')
    if len(X)==0: return np.empty((len(model['trees'])+1,0))
    current=np.full(len(X),model['base']); stages=[current.copy()]
    for tree in model['trees']:
        current+=model['rate']*tree.predict(X); stages.append(current.copy())
    return np.asarray(stages)

def metrics(estimator,X,y):
    p=estimator.predict_proba(X)[:,1]
    return {'ap':float(average_precision_score(y,p)), 'accuracy':float(accuracy_score(y,estimator.predict(X))),
            'brier':float(brier_score_loss(y,p))}

# %% Fixed inner grouped search and independent teaching experiments
def analyse_source(path):
    frame,X,y,groups,digest=load_source(path)
    train,valid=next(GroupShuffleSplit(n_splits=1,test_size=.2,random_state=42).split(X,y,groups))
    if not set(groups[train]).isdisjoint(groups[valid]): raise ValueError('Group overlap')
    folds=list(StratifiedGroupKFold(n_splits=3,shuffle=True,random_state=42).split(X[train],y[train],groups[train]))
    specifications=[('rf_half','rf',.5),('rf_all','rf',1.),('hist_slow','hist',.05),('hist_fast','hist',.1)]
    def build(kind,value):
        if kind=='rf': return RandomForestClassifier(n_estimators=32,max_depth=8,min_samples_leaf=30,max_features=value,random_state=42,n_jobs=1)
        return HistGradientBoostingClassifier(max_iter=60,max_leaf_nodes=7,min_samples_leaf=50,learning_rate=value,early_stopping=False,random_state=42)
    rows=[]
    for name,kind,value in specifications:
        scores=[]
        for fit,check in folds:
            fit,check=train[fit],train[check]
            if not set(groups[fit]).isdisjoint(groups[check]): raise ValueError('Inner group overlap')
            estimator=build(kind,value).fit(X[fit],y[fit])
            scores.append(average_precision_score(y[check],estimator.predict_proba(X[check])[:,1]))
        rows.append({'name':name,'family':kind,'value':value,'inner_ap':float(np.mean(scores))})
    # Exact score ties keep the declared candidate order; never consult outer validation.
    chosen=max(rows,key=lambda row:row['inner_ap'])
    winner=build(chosen['family'],chosen['value']).fit(X[train],y[train])
    baseline=DummyClassifier(strategy='prior').fit(X[train],y[train])
    bag=BaggingClassifier(estimator=DecisionTreeClassifier(max_depth=4,min_samples_leaf=20),n_estimators=24,bootstrap=True,max_samples=1.,random_state=42,n_jobs=1).fit(X[train],y[train])
    ada=AdaBoostClassifier(estimator=DecisionTreeClassifier(max_depth=1),n_estimators=30,learning_rate=.5,random_state=42).fit(X[train],y[train])
    # OOB membership is row-level; repeated-profile peers may still be in bag.
    member_probs=np.column_stack([est.predict_proba(X[train][:,features])[:,1] for est,features in zip(bag.estimators_,bag.estimators_features_)])
    in_bag=np.zeros_like(member_probs,dtype=bool)
    for j,indices in enumerate(bag.estimators_samples_): in_bag[np.unique(indices),j]=True
    oob_count=(~in_bag).sum(axis=1); supported=oob_count>0
    oob=np.zeros(len(train)); oob[supported]=(member_probs*(~in_bag)).sum(axis=1)[supported]/oob_count[supported]
    selected_points=[]
    # First row intentionally in the first tree's bag, so stage1/OOB has no vote.
    first=int(np.flatnonzero(in_bag[:,0])[0]); positions=[first]+[i for i in range(12) if i!=first]
    for i in positions:
        selected_points.append({'source_row_1based':int(train[i]+1),'positive':int(y[train[i]]),
            'probabilities':member_probs[i].tolist(),'in_bag':in_bag[i].tolist()})
    bag_asset={'source':'UCI Adult, Becker & Kohavi (1996), CC BY 4.0','sha256':digest,
        'scope':'24 fixed bootstrap depth4 trees, min_leaf20; real training rows. Row-OOB is not group-held-out evidence.',
        'members':24,'points':selected_points}
    hours=frame['hours_per_week'].to_numpy(dtype=float); regression_X=X[:,:2]
    probe_indices=valid[:8]
    runs=[]
    for rate in [.1,.5,1.]:
        model=fit_squared_boost(regression_X[train],hours[train],rounds=16,rate=rate)
        predictions=staged_squared_predict(model,regression_X[valid])
        valid_rmse=np.sqrt(np.mean((predictions-hours[valid])**2,axis=1))
        # Independent library check on the SAME loss, rate, depth, support and seed.
        reference=GradientBoostingRegressor(loss='squared_error',n_estimators=16,learning_rate=rate,max_depth=2,min_samples_leaf=100,random_state=42).fit(regression_X[train],hours[train])
        np.testing.assert_allclose(predictions[-1],reference.predict(regression_X[valid]),rtol=1e-10,atol=1e-9)
        runs.append({'rate':rate,'train_rmse':model['training_rmse'],'valid_rmse':valid_rmse.tolist(),
            'probe_predictions':predictions[:,:8].T.tolist(),
            'probe_tree_outputs':np.array([tree.predict(regression_X[probe_indices]) for tree in model['trees']]).T.tolist()})
    boost_asset={'source':bag_asset['source'],'sha256':digest,'scope':'Fixed depth2 squared-loss teaching runs; age/education_num -> hours_per_week; no early stopping selection.',
        'base':float(hours[train].mean()),'rounds':16,'train_rows':len(train),'valid_rows':len(valid),
        'probes':[{'source_row_1based':int(i+1),'target':float(hours[i])} for i in probe_indices],'runs':runs}
    report={'source':bag_asset['source'],'sha256':digest,'versions':{'python':platform.python_version(),'numpy':np.__version__,'pandas':pd.__version__,'sklearn':sklearn.__version__},
        'scope':'Reused historical development source, no external test, fresh confirmation, causal or deployment claim',
        'features':FEATURES,'seed':42,'train_rows':len(train),'valid_rows':len(valid),'inner_folds':3,'candidates':rows,'selected':chosen,
        'winner_train':metrics(winner,X[train],y[train]),'winner_validation':metrics(winner,X[valid],y[valid]),
        'baseline_validation':metrics(baseline,X[valid],y[valid]),'fixed_bagging_validation':metrics(bag,X[valid],y[valid]),
        'fixed_adaboost_samme_validation':metrics(ada,X[valid],y[valid]),'row_oob':{'covered_rows':int(supported.sum()),'total_rows':len(train),
            'average_member_count':float(oob_count.mean()),'ap_on_supported':float(average_precision_score(y[train][supported],oob[supported]))},
        'regression_runs':[{'rate':r['rate'],'round16_train_rmse':r['train_rmse'][-1],'round16_valid_rmse':r['valid_rmse'][-1]} for r in runs],
        'assumptions':['Raw-profile groups exclude both outcomes; proxy groups are not verified independent persons.',
            'fnlwgt weights unused; all metrics are unweighted rows.',
            'Inner grouped selection uses no outer-validation labels; internal HistGB early stopping explicitly disabled.',
            'Row-OOB may contain related profile peers in training; it is not group/time-safe evaluation.',
            'Lab curves are independent fixed teaching runs; viewing validation to choose rounds is development selection.',
            'XGBoost/LightGBM/CatBoost comparisons are conceptual; those packages are not installed or benchmarked here.']}
    return report,bag_asset,boost_asset

def run_analysis(path):
    with threadpool_limits(limits=1): return analyse_source(path)

# %% Import-safe CLI and explicit derived-asset generation
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--write-labs',action='store_true')
    args=parser.parse_args(argv)
    report,bag,boost=run_analysis(DATA/'adult.data')
    if args.write_labs:
        for name,asset in [('ensemble_bagging_lab.json',bag),('ensemble_boosting_lab.json',boost)]:
            (DATA/name).write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        temporary=args.output.with_name(args.output.name+'.tmp')
        temporary.write_text(rendered+'\n',encoding='utf-8'); temporary.replace(args.output)
    print(rendered)
    return report

if __name__=='__main__': main()
