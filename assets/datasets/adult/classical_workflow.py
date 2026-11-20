"""Chapter 11: offline SVM/kNN/Naive Bayes audit on original UCI Adult.

CC BY 4.0 attribution in sibling README.md. Reused historical development data;
no external test, network, current-population, fresh-confirmation or causal claim.
"""
# %% Source, outer group split and declared training budget
from pathlib import Path
import argparse
import hashlib
import json
import platform
import warnings
import numpy as np
import pandas as pd
import sklearn
from scipy.special import logsumexp
from threadpoolctl import threadpool_limits
from sklearn.model_selection import GroupShuffleSplit, StratifiedGroupKFold
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import make_pipeline
from sklearn.svm import SVC, LinearSVC
from sklearn.neighbors import KNeighborsClassifier
from sklearn.naive_bayes import GaussianNB
from sklearn.dummy import DummyClassifier
from sklearn.metrics import average_precision_score, accuracy_score, brier_score_loss
from sklearn.exceptions import ConvergenceWarning

DATA=Path(__file__).resolve().parent
SOURCE_HASH='5b00264637dbfec36bdeaab5676b0b309ff9eb788d63554ca0a249491c86603d'
COLUMNS=['age','workclass','fnlwgt','education','education_num','marital_status','occupation','relationship','race','sex','capital_gain','capital_loss','hours_per_week','native_country','income']
FEATURES=['age','education_num','capital_gain','capital_loss','hours_per_week']

def load_source(path):
    digest=hashlib.sha256(path.read_bytes()).hexdigest()
    if digest!=SOURCE_HASH: raise ValueError('Expected original adult.data')
    frame=pd.read_csv(path,names=COLUMNS,skipinitialspace=True,na_values='?')
    label=frame['income'].astype('string').str.strip()
    if not label.isin(['<=50K','>50K']).all(): raise ValueError('Binary income labels required')
    X=frame[FEATURES].to_numpy(dtype=float,copy=True);y=(label=='>50K').to_numpy(dtype=int)
    if not np.isfinite(X).all(): raise ValueError('Finite numeric feature contract')
    keys=frame[[c for c in COLUMNS if c not in ('income','hours_per_week')]].astype('string').fillna('__MISSING__')
    groups=pd.util.hash_pandas_object(keys,index=False).to_numpy()
    return frame,X,y,groups,digest

def split_and_budget(X,y,groups):
    outer,valid=next(GroupShuffleSplit(n_splits=1,test_size=.2,random_state=42).split(X,y,groups))
    selected=np.random.default_rng(42).permutation(np.unique(groups[outer]))[:6000]
    train=outer[np.isin(groups[outer],selected)]
    if not set(groups[train]).isdisjoint(groups[valid]): raise ValueError('Group overlap')
    return outer,train,valid

# %% Transparent mathematical helpers: explicit contracts, no hidden fitting
def hinge_objective(X,y,w,b,C=1.):
    X,y,w=np.asarray(X,dtype=float),np.asarray(y),np.asarray(w,dtype=float)
    if (X.ndim!=2 or min(X.shape)<1 or y.shape!=(len(X),) or w.shape!=(X.shape[1],) or
        not np.isfinite(X).all() or not np.isfinite(w).all() or not np.isin(y,[-1,1]).all() or
        not np.isfinite(b) or not np.isfinite(C) or C<0): raise ValueError('Finite aligned signed hinge inputs')
    margin=y*(X@w+b);active=margin<1
    loss=.5*np.dot(w,w)+C*np.maximum(0,1-margin).mean()
    gradient=w-C*(X[active].T@y[active])/len(y)
    bias_gradient=-C*y[active].sum()/len(y)
    return float(loss),gradient,float(bias_gradient)

def rbf_kernel(X,Z,gamma):
    X,Z=np.asarray(X,dtype=float),np.asarray(Z,dtype=float)
    if (X.ndim!=2 or Z.ndim!=2 or X.shape[1]!=Z.shape[1] or X.shape[1]==0 or
        not np.isfinite(X).all() or not np.isfinite(Z).all() or not np.isfinite(gamma) or gamma<0):
        raise ValueError('Finite aligned kernel inputs, gamma>=0')
    # Direct differences avoid cancellation in ||x||²+||z||²-2x.z on tiny teaching arrays.
    return np.exp(-gamma*np.sum((X[:,None,:]-Z[None,:,:])**2,axis=2))

def knn_predict(X,y,queries,*,k=5,p=2,weighted=False):
    X,y,Q=np.asarray(X,dtype=float),np.asarray(y),np.asarray(queries,dtype=float)
    if (X.ndim!=2 or min(X.shape)<1 or y.shape!=(len(X),) or Q.ndim!=2 or Q.shape[1]!=X.shape[1] or
        not np.isfinite(X).all() or not np.isfinite(Q).all() or not np.isin(y,[0,1]).all() or
        not isinstance(k,int) or isinstance(k,bool) or not 1<=k<=len(X) or p not in (1,2)):
        raise ValueError('Finite binary neighbor schema, k and p1/2')
    predictions=[];details=[]
    for query in Q:
        delta=np.abs(X-query);distance=delta.sum(axis=1) if p==1 else np.sqrt((delta*delta).sum(axis=1))
        order=np.lexsort((np.arange(len(X)),distance))[:k]  # Distance then pool order.
        selected=distance[order]
        if weighted:
            zero=selected==0
            weights=zero.astype(float) if zero.any() else selected.min()/selected  # Common scale cancels.
        else: weights=np.ones(k)
        probability=float(np.dot(weights,y[order])/weights.sum())
        predictions.append(probability);details.append({'indices':order,'distances':selected,'weights':weights})
    return np.asarray(predictions),details

def gaussian_log_scores(X,means,variances,priors):
    X,means,variances,priors=[np.asarray(v,dtype=float) for v in (X,means,variances,priors)]
    if (X.ndim!=2 or X.shape[1]==0 or means.shape!=(2,X.shape[1]) or variances.shape!=means.shape or priors.shape!=(2,) or
        any(not np.isfinite(v).all() for v in (X,means,variances,priors)) or np.any(variances<=0) or
        np.any(priors<=0) or not np.isclose(priors.sum(),1)):
        raise ValueError('Positive finite Gaussian variances/priors and aligned schema')
    contributions=-.5*(np.log(2*np.pi*variances)[None,:,:]+(X[:,None,:]-means[None,:,:])**2/variances[None,:,:])
    joint=np.log(priors)[None,:]+contributions.sum(axis=2)
    normalized=joint-logsumexp(joint,axis=1,keepdims=True)
    return joint,normalized,contributions

# %% Inner grouped family comparison and three independently scoped lab assets
def metric_report(estimator,X,y):
    score=estimator.decision_function(X) if hasattr(estimator,'decision_function') else estimator.predict_proba(X)[:,1]
    result={'ap':float(average_precision_score(y,score)),'accuracy':float(accuracy_score(y,estimator.predict(X)))}
    if hasattr(estimator,'predict_proba'):result['brier']=float(brier_score_loss(y,estimator.predict_proba(X)[:,1]))
    return result

def analyse_source(path):
    frame,X,y,groups,digest=load_source(path);outer,train,valid=split_and_budget(X,y,groups)
    specs=[('linear_c01','linear',.1),('linear_c1','linear',1.),('knn15','knn',15),('knn51','knn',51),('gaussian_small','nb',1e-9),('gaussian_large','nb',.01)]
    def build(kind,value):
        if kind=='linear':return make_pipeline(StandardScaler(),LinearSVC(C=value,dual=False,max_iter=20000,tol=1e-5,random_state=42))
        if kind=='knn':return make_pipeline(StandardScaler(),KNeighborsClassifier(n_neighbors=value,weights='distance',algorithm='brute',n_jobs=1))
        return GaussianNB(var_smoothing=value)
    folds=list(StratifiedGroupKFold(n_splits=3,shuffle=True,random_state=42).split(X[train],y[train],groups[train]))
    candidates=[]
    with warnings.catch_warnings():
        warnings.simplefilter('error',ConvergenceWarning)
        for name,kind,value in specs:
            scores=[]
            for fit,held in folds:
                fit,held=train[fit],train[held]
                if not set(groups[fit]).isdisjoint(groups[held]):raise ValueError('Inner overlap')
                model=build(kind,value).fit(X[fit],y[fit]);scores.append(metric_report(model,X[held],y[held])['ap'])
            candidates.append({'name':name,'family':kind,'value':value,'inner_ap':float(np.mean(scores))})
        chosen=max(candidates,key=lambda r:r['inner_ap'])  # Exact ties keep declared order.
        winner=build(chosen['family'],chosen['value']).fit(X[train],y[train])
    baseline=DummyClassifier(strategy='prior').fit(X[train],y[train])
    # Lab geometry uses a separate bounded training subset and its own scaler.
    lab_train=train[:1024];lab_scaler=StandardScaler().fit(X[lab_train,:2]);Z=lab_scaler.transform(X[lab_train,:2])
    query_indices=valid[:6];Q=lab_scaler.transform(X[query_indices,:2]);snapshots=[]
    for C in [.01,.1,1.]:
        with warnings.catch_warnings():
            warnings.simplefilter('error',ConvergenceWarning)
            svc=SVC(kernel='linear',C=C,class_weight='balanced',tol=1e-5,max_iter=200000).fit(Z,y[lab_train])
        w=svc.coef_[0];bias=float(svc.intercept_[0]);norm=float(np.linalg.norm(w));margin=(2*y[lab_train]-1)*(Z@w+bias)
        if norm<1e-8:raise ValueError('Degenerate teaching margin')
        class_weights=svc.class_weight_;alpha=np.zeros(len(Z));alpha[svc.support_]=np.abs(svc.dual_coef_[0])
        upper=C*class_weights[y[lab_train]]
        if np.max(alpha-upper)>1e-6 or abs(np.dot(alpha,2*y[lab_train]-1))>1e-6:raise ValueError('Dual feasibility')
        np.testing.assert_allclose(Q@w+bias,svc.decision_function(Q),atol=1e-10)
        snapshots.append({'C':C,'weights':w.tolist(),'bias':bias,'norm':norm,'support_count':int(len(svc.support_)),
            'class_weights':class_weights.tolist(),'query_scores':svc.decision_function(Q).tolist(),
            'support_flags':[bool(i in set(svc.support_)) for i in range(48)],
            'primal_weighted_hinge_sum':float(.5*norm**2+C*np.dot(class_weights[y[lab_train]],np.maximum(0,1-margin)))})
    source={'source':'UCI Adult, Becker & Kohavi (1996), CC BY 4.0','sha256':digest}
    def observation(i):return {'source_row_1based':int(i+1),'values':X[i,:2].tolist(),'positive':int(y[i])}
    svm_asset={**source,'scope':'Fixed balanced-weight linear SVC on first1024 budget-training rows, age/education only; separate lab specification.',
        'mean':lab_scaler.mean_.tolist(),'scale':lab_scaler.scale_.tolist(),'training_rows':len(lab_train),
        'points':[observation(i) for i in lab_train[:48]],'queries':[observation(i) for i in query_indices],'snapshots':snapshots}
    # Neighbor pool is a bounded real subset. Its tie policy is distance then pool order.
    pool_indices=train[:64];neighbor_scaler=StandardScaler().fit(X[train,:2])
    knn_asset={**source,'scope':'64 actual budget-training rows, two features; calculator, not full-model performance.',
        'mean':neighbor_scaler.mean_.tolist(),'scale':neighbor_scaler.scale_.tolist(),
        'pool':[observation(i) for i in pool_indices],'queries':[observation(i) for i in query_indices]}
    gaussian=GaussianNB(var_smoothing=1e-9).fit(X[train,:2],y[train])
    joint,log_probability,contributions=gaussian_log_scores(X[query_indices,:2],gaussian.theta_,gaussian.var_,gaussian.class_prior_)
    np.testing.assert_allclose(log_probability,gaussian.predict_log_proba(X[query_indices,:2]),atol=1e-10)
    nb_asset={**source,'scope':'Fixed two-feature GaussianNB fitted on budget-training rows; log densities, not discrete masses.',
        'means':gaussian.theta_.tolist(),'variances':gaussian.var_.tolist(),'priors':gaussian.class_prior_.tolist(),
        'epsilon':float(gaussian.epsilon_),'queries':[observation(i) for i in query_indices],
        'reference_log_probability':log_probability.tolist()}
    report={**source,'versions':{'python':platform.python_version(),'numpy':np.__version__,'pandas':pd.__version__,'sklearn':sklearn.__version__},
        'scope':'Reused historical development source; bounded compute, no fresh confirmation or deployment claim',
        'features':FEATURES,'seed':42,'outer_training_rows':len(outer),'budget_training_groups':int(len(np.unique(groups[train]))),
        'budget_training_rows':len(train),'validation_rows':len(valid),'inner_folds':3,'candidates':candidates,'selected':chosen,
        'winner_train':metric_report(winner,X[train],y[train]),'winner_validation':metric_report(winner,X[valid],y[valid]),
        'baseline_validation':metric_report(baseline,X[valid],y[valid]),'svm_lab_support_counts':[s['support_count'] for s in snapshots],
        'svm_lab_widths':[2/s['norm'] for s in snapshots],'nb_lab_epsilon':float(gaussian.epsilon_),
        'assumptions':['6000 groups chosen from outer training with fixed label-independent RNG; compute-budget protocol differs from earlier chapters.',
            'Raw-profile grouping excludes income/hours outcomes; groups are proxies, not verified independent people.',
            'Scalers fit within each training fold; lab scalers have separately stated training scopes.',
            'LinearSVC squared hinge/intercept regularization differs from the standard unpenalized-bias hinge derivation.',
            'No invented SVM probabilities: AP uses decision scores, and Brier is omitted when predict_proba is unavailable.',
            'Neighbor tie policy is explicit; equal-distance cutoff ties need not match a library arbitrary ordering.',
            'fnlwgt unused; unweighted row metrics, no causal/current-population/canonical benchmark claim.']}
    return report,svm_asset,knn_asset,nb_asset

def run_analysis(path):
    with threadpool_limits(limits=1):return analyse_source(path)

# %% Import-safe CLI and explicitly regenerated derived lab assets
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--write-labs',action='store_true')
    args=parser.parse_args(argv);report,svm,knn,nb=run_analysis(DATA/'adult.data')
    if args.write_labs:
        for name,asset in [('classical_svm_lab.json',svm),('classical_knn_lab.json',knn),('classical_nb_lab.json',nb)]:
            (DATA/name).write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);temporary=args.output.with_name(args.output.name+'.tmp')
        temporary.write_text(rendered+'\n',encoding='utf-8');temporary.replace(args.output)
    print(rendered);return report

if __name__=='__main__':main()
