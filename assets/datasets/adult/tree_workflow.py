"""Chapter 9 Decision Trees on original local UCI Adult (CC BY 4.0).

Run from any directory; no network or adult.test access. This reused historical
source provides development diagnostics, not fresh confirmatory or causal evidence.
"""
# %% Source, numerical contract and group-safe development split
from pathlib import Path
import argparse
import hashlib
import json
import platform
import numpy as np
import pandas as pd
import sklearn
from sklearn.model_selection import GroupShuffleSplit, StratifiedGroupKFold
from sklearn.tree import DecisionTreeClassifier, DecisionTreeRegressor
from sklearn.dummy import DummyClassifier
from sklearn.metrics import average_precision_score, accuracy_score, brier_score_loss, mean_squared_error

DATA = Path(__file__).resolve().parent
COLUMNS = ['age','workclass','fnlwgt','education','education_num','marital_status',
           'occupation','relationship','race','sex','capital_gain','capital_loss',
           'hours_per_week','native_country','income']
FEATURES = ['age','education_num','capital_gain','capital_loss','hours_per_week']
SOURCE_HASH = '5b00264637dbfec36bdeaab5676b0b309ff9eb788d63554ca0a249491c86603d'

def load_source(path):
    digest=hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != SOURCE_HASH: raise ValueError('Expected original adult.data')
    frame=pd.read_csv(path,names=COLUMNS,skipinitialspace=True,na_values='?')
    labels=frame['income'].astype('string').str.strip()
    if not labels.isin(['<=50K','>50K']).all(): raise ValueError('Invalid income labels')
    X=frame[FEATURES].to_numpy(dtype=float,copy=True)
    if not np.isfinite(X).all(): raise ValueError('Finite numeric features required')
    y=(labels=='>50K').to_numpy(dtype=int)
    keys=frame[[c for c in COLUMNS if c not in ('income','hours_per_week')]].astype('string').fillna('__MISSING__')
    groups=pd.util.hash_pandas_object(keys,index=False).to_numpy()
    return frame,X,y,groups,digest

def development_split(X,y,groups):
    train,valid=next(GroupShuffleSplit(n_splits=1,test_size=.2,random_state=42).split(X,y,groups))
    if not set(groups[train]).isdisjoint(groups[valid]): raise ValueError('Group overlap')
    return train,valid

# %% Transparent CART teaching implementation: finite numeric, binary Gini only
def binary_data(X,y):
    X,y=np.asarray(X,dtype=float),np.asarray(y)
    if (X.ndim!=2 or min(X.shape)<1 or y.shape!=(len(X),) or
        not np.isfinite(X).all() or not np.isin(y,[0,1]).all()):
        raise ValueError('Finite matrix and aligned binary labels required')
    return X,y.astype(int,copy=True)

def gini(y):
    y=np.asarray(y)
    if y.ndim!=1 or len(y)==0 or not np.isin(y,[0,1]).all(): raise ValueError('Nonempty binary labels')
    p=float(y.mean())
    return 2*p*(1-p)

def best_split(X,y,min_leaf=1):
    X,y=binary_data(X,y)
    if not isinstance(min_leaf,int) or isinstance(min_leaf,bool) or min_leaf<1: raise ValueError('Positive min_leaf')
    n=len(y); parent=gini(y); best=None
    for j in range(X.shape[1]):
        order=np.argsort(X[:,j],kind='stable'); values=X[order,j]; ordered=y[order]
        positives=np.cumsum(ordered)
        for left_n in range(min_leaf,n-min_leaf+1):
            if values[left_n-1]==values[left_n]: continue  # Never separate equal feature values.
            lp=positives[left_n-1]/left_n
            rp=(positives[-1]-positives[left_n-1])/(n-left_n)
            child=(left_n*2*lp*(1-lp)+(n-left_n)*2*rp*(1-rp))/n
            gain=parent-child
            # Positive gain only; ties keep earlier feature/threshold. This policy is explicit.
            if gain>1e-12 and (best is None or gain>best['gain']+1e-12):
                threshold=float(values[left_n-1]/2+values[left_n]/2)
                if not values[left_n-1]<=threshold<values[left_n]: threshold=float(values[left_n-1])
                best={'feature':j,'threshold':threshold,'gain':float(gain)}
    return best

def fit_cart(X,y,*,max_depth=3,min_leaf=1):
    X,y=binary_data(X,y)
    if not isinstance(max_depth,int) or isinstance(max_depth,bool) or not 0<=max_depth<=20: raise ValueError('Bounded max_depth0..20')
    if not isinstance(min_leaf,int) or isinstance(min_leaf,bool) or min_leaf<1: raise ValueError('Positive min_leaf')
    def grow(matrix,labels,depth):
        node={'n':len(labels),'p':float(labels.mean())}
        split=best_split(matrix,labels,min_leaf) if depth<max_depth and gini(labels)>0 else None
        if split is not None:
            left=matrix[:,split['feature']]<=split['threshold']
            node.update(split)
            node['left']=grow(matrix[left],labels[left],depth+1)
            node['right']=grow(matrix[~left],labels[~left],depth+1)
        return node
    return {'features':X.shape[1],'root':grow(X,y,0)}

def predict_cart(model,X):
    X=np.asarray(X,dtype=float)
    if X.ndim!=2 or X.shape[1]!=model['features'] or not np.isfinite(X).all(): raise ValueError('Prediction shape/value mismatch')
    result=[]
    for row in X:
        node=model['root']
        while 'feature' in node:
            node=node['left'] if row[node['feature']]<=node['threshold'] else node['right']
        result.append(node['p'])
    return np.asarray(result,dtype=float)

# %% Inner grouped selection, fixed pruning path, interpretation and regression
def classification_report(model,X,y):
    probabilities=model.predict_proba(X)[:,1]
    return {'accuracy':float(accuracy_score(y,model.predict(X))),
            'average_precision':float(average_precision_score(y,probabilities)),
            'brier':float(brier_score_loss(y,probabilities))}

def leaf_risk(model):
    t=model.tree_; leaf=t.children_left==-1
    return float(np.dot(t.weighted_n_node_samples[leaf],t.impurity[leaf])/t.weighted_n_node_samples[0])

def run_analysis(path):
    frame,X,y,groups,digest=load_source(path)
    train,valid=development_split(X,y,groups)
    folds=list(StratifiedGroupKFold(n_splits=3,shuffle=True,random_state=42).split(X[train],y[train],groups[train]))
    candidates=[]
    for depth in [3,6]:
        for minimum in [50,200]:
            for alpha in [0.,.002]:
                params={'max_depth':depth,'min_samples_leaf':minimum,'ccp_alpha':alpha}
                scores=[]
                for fit,check in folds:
                    fit,check=train[fit],train[check]
                    if not set(groups[fit]).isdisjoint(groups[check]): raise ValueError('Inner group overlap')
                    estimator=DecisionTreeClassifier(**params,random_state=42).fit(X[fit],y[fit])
                    scores.append(average_precision_score(y[check],estimator.predict_proba(X[check])[:,1]))
                candidates.append({'params':params,'mean_inner_ap':float(np.mean(scores))})
    # Rank only on inner folds; exact-score ties prefer smaller depth, larger leaves, larger alpha.
    winner=max(candidates,key=lambda row:(row['mean_inner_ap'],-row['params']['max_depth'],row['params']['min_samples_leaf'],row['params']['ccp_alpha']))
    model=DecisionTreeClassifier(**winner['params'],random_state=42).fit(X[train],y[train])
    baseline=DummyClassifier(strategy='prior').fit(X[train],y[train])
    # A separate fixed teaching tree/path, never used to select the reported winner.
    base=DecisionTreeClassifier(max_depth=5,min_samples_leaf=100,random_state=42).fit(X[train,:2],y[train])
    alphas=np.unique(base.cost_complexity_pruning_path(X[train,:2],y[train]).ccp_alphas)
    snapshots=[]
    for alpha in alphas:
        fitted=DecisionTreeClassifier(max_depth=5,min_samples_leaf=100,ccp_alpha=float(alpha),random_state=42).fit(X[train,:2],y[train])
        snapshots.append({'alpha':float(alpha),'leaves':int(fitted.get_n_leaves()),'depth':int(fitted.get_depth()),
            'risk':leaf_risk(fitted),'train_accuracy':float(fitted.score(X[train,:2],y[train])),
            'valid_accuracy':float(fitted.score(X[valid,:2],y[valid]))})
    # Verify that nondecreasing alpha produces a nested complexity/risk trend.
    if np.any(np.diff([s['leaves'] for s in snapshots])>0) or np.any(np.diff([s['risk'] for s in snapshots]) < -1e-12):
        raise ValueError('Unexpected pruning path')
    regression=DecisionTreeRegressor(max_depth=4,min_samples_leaf=100,random_state=42).fit(X[train,:2],frame['hours_per_week'].to_numpy()[train])
    hours=frame['hours_per_week'].to_numpy(dtype=float)
    reg_pred=regression.predict(X[valid,:2])
    # The teaching CART deliberately excludes zero-gain splits (e.g. XOR root).
    small_X=np.array([[0.],[1.],[2.],[3.],[4.],[5.]])
    small_y=np.array([0,0,0,1,1,1])
    scratch=fit_cart(small_X,small_y,max_depth=1)
    reference=DecisionTreeClassifier(max_depth=1,random_state=42).fit(small_X,small_y)
    np.testing.assert_allclose(predict_cart(scratch,small_X),reference.predict_proba(small_X)[:,1])
    row=0; tree=model.tree_; node_ids=model.decision_path(X[valid[row:row+1]]).indices.tolist()
    lab={'source':'UCI Adult, Becker & Kohavi (1996), CC BY 4.0','sha256':digest,
         'scope':'First 24 original source rows; age and income label only. Descriptive split calculator, not validation.',
         'rows':[{'source_row_1based':i+1,'age':float(X[i,0]),'positive':int(y[i])} for i in range(24)]}
    pruning={'source':lab['source'],'sha256':digest,'scope':'Fixed depth5/min_leaf100 teaching tree, age/education_num only; training path and reused development validation.',
             'train_rows':len(train),'valid_rows':len(valid),'snapshots':snapshots}
    report={'source':lab['source'],'sha256':digest,'versions':{'python':platform.python_version(),'numpy':np.__version__,'pandas':pd.__version__,'sklearn':sklearn.__version__},
        'scope':'Reused historical development source; no external test, fresh confirmation, causal or deployment claim',
        'features':FEATURES,'train_rows':len(train),'valid_rows':len(valid),'groups':int(len(np.unique(groups))),
        'seed':42,'inner_folds':3,'candidate_count':len(candidates),'candidates':candidates,'selected':winner,
        'train':classification_report(model,X[train],y[train]),'validation':classification_report(model,X[valid],y[valid]),
        'baseline_validation':classification_report(baseline,X[valid],y[valid]),'selected_leaves':int(model.get_n_leaves()),'selected_depth':int(model.get_depth()),
        'feature_importance_mdi':dict(zip(FEATURES,model.feature_importances_.tolist())),
        'example_path':{'validation_position':row,'node_ids':node_ids,'leaf':int(model.apply(X[valid[row:row+1]])[0]),'positive_probability':float(model.predict_proba(X[valid[row:row+1]])[0,1])},
        'regression_fixed':{'features':FEATURES[:2],'target':'hours_per_week','depth':4,'min_leaf':100,
            'validation_rmse':float(np.sqrt(mean_squared_error(hours[valid],reg_pred))),
            'training_mean_baseline_rmse':float(np.sqrt(mean_squared_error(hours[valid],np.full(len(valid),hours[train].mean()))))},
        'assumptions':['Raw profile groups exclude both outcomes; they are proxies, not verified independent people.',
            'fnlwgt weights are unused; all metrics are unweighted rows, not population estimates.',
            'No global preprocessing is fitted. Numeric finite inputs use fixed declared features.',
            'Validation/path inspection is development exploration; no retuning claim based on these diagnostics.',
            'MDI is a fitted training impurity attribution, not causal importance or a stability guarantee.']}
    return report,lab,pruning

# %% Import-safe CLI; packaged lab snapshots are generated explicitly
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--write-labs',action='store_true',help='Regenerate the two bundled lab JSON assets')
    args=parser.parse_args(argv)
    report,lab,pruning=run_analysis(DATA/'adult.data')
    if args.write_labs:
        for name,asset in [('tree_split_lab.json',lab),('tree_pruning_lab.json',pruning)]:
            (DATA/name).write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        temporary=args.output.with_name(args.output.name+'.tmp')
        temporary.write_text(rendered+'\n',encoding='utf-8'); temporary.replace(args.output)
    print(rendered)
    return report

if __name__=='__main__': main()
