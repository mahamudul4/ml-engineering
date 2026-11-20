"""Chapter12 offline clustering/PCA audit on original UCI Adult (CC BY4.0).

No income labels used for fitting, selection or scoring. Historical source reused;
clusters are exploratory model partitions, not natural demographic categories.
"""
# %% Local source, group-safe split and explicit bounded exploration budget
from pathlib import Path
import argparse
import hashlib
import json
import platform
import numpy as np
import pandas as pd
import sklearn
from scipy.cluster.hierarchy import linkage, fcluster
from threadpoolctl import threadpool_limits
from sklearn.model_selection import GroupShuffleSplit
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans, DBSCAN
from sklearn.decomposition import PCA
from sklearn.metrics import silhouette_score, adjusted_rand_score

DATA=Path(__file__).resolve().parent
SOURCE_HASH='5b00264637dbfec36bdeaab5676b0b309ff9eb788d63554ca0a249491c86603d'
COLUMNS=['age','workclass','fnlwgt','education','education_num','marital_status','occupation','relationship','race','sex','capital_gain','capital_loss','hours_per_week','native_country','income']
FEATURES=['age','education_num','hours_per_week']

def load_source(path):
    digest=hashlib.sha256(path.read_bytes()).hexdigest()
    if digest!=SOURCE_HASH:raise ValueError('Expected original adult.data')
    frame=pd.read_csv(path,names=COLUMNS,skipinitialspace=True,na_values='?')
    X=frame[FEATURES].to_numpy(dtype=float,copy=True)
    if not np.isfinite(X).all():raise ValueError('Finite numeric clustering features required')
    keys=frame[[c for c in COLUMNS if c not in ('income','hours_per_week')]].astype('string').fillna('__MISSING__')
    groups=pd.util.hash_pandas_object(keys,index=False).to_numpy()
    return frame,X,groups,digest

def split_budget(X,groups):
    outer,valid=next(GroupShuffleSplit(n_splits=1,test_size=.2,random_state=42).split(X,groups=groups))
    chosen=np.random.default_rng(42).permutation(np.unique(groups[outer]))[:6000]
    train=outer[np.isin(groups[outer],chosen)]
    if not set(groups[train]).isdisjoint(groups[valid]):raise ValueError('Group overlap')
    return outer,train,valid

# %% Transparent Lloyd, core-connectivity DBSCAN and SVD projection helpers
def finite_matrix(X):
    X=np.asarray(X,dtype=float)
    if X.ndim!=2 or min(X.shape)<1 or not np.isfinite(X).all():raise ValueError('Nonempty finite matrix')
    return X

def lloyd_steps(X,initial,*,max_steps=12):
    X,centers=finite_matrix(X),finite_matrix(initial).copy()
    if centers.shape[1]!=X.shape[1] or len(centers)>len(X) or not isinstance(max_steps,int) or isinstance(max_steps,bool) or not 0<=max_steps<=100:
        raise ValueError('Aligned centers and bounded step count')
    def state(step,centers,empty):
        squared=np.sum((X[:,None,:]-centers[None,:,:])**2,axis=2)
        labels=squared.argmin(axis=1)  # Smallest center index on ties.
        return {'step':step,'centers':centers.tolist(),'labels':labels.tolist(),
                'inertia':float(squared[np.arange(len(X)),labels].sum()),'empty_before_update':empty}
    states=[state(0,centers,[])]
    for step in range(1,max_steps+1):
        labels=np.asarray(states[-1]['labels']);new=centers.copy();empty=[]
        for c in range(len(centers)):
            selected=X[labels==c]
            if len(selected):new[c]=selected.mean(axis=0)
            else:empty.append(c)  # Explicit policy: retain previous empty center.
        following=state(step,new,empty);states.append(following);centers=new
        if following['labels']==states[-2]['labels']:break
    return states

def density_partition(X,eps,min_samples):
    X=finite_matrix(X)
    if not np.isfinite(eps) or eps<0 or not isinstance(min_samples,int) or isinstance(min_samples,bool) or min_samples<1:
        raise ValueError('Finite eps>=0 and positive integer min_samples')
    adjacency=np.sum((X[:,None,:]-X[None,:,:])**2,axis=2)<=eps*eps
    core=adjacency.sum(axis=1)>=min_samples  # Includes the observation itself.
    labels=np.full(len(X),-1,dtype=int);cluster=0
    for start in np.flatnonzero(core):
        if labels[start]>=0:continue
        labels[start]=cluster;queue=[int(start)]
        for current in queue:
            for neighbor in np.flatnonzero(adjacency[current]&core):
                if labels[neighbor]<0:labels[neighbor]=cluster;queue.append(int(neighbor))
        cluster+=1
    # Non-core border points never connect core components. Ambiguous borders
    # attach to the lowest adjacent component ID for this explicit ordering.
    for i in np.flatnonzero(~core):
        adjacent=labels[adjacency[i]&core]
        if len(adjacent):labels[i]=int(adjacent.min())
    return labels,core,adjacency.sum(axis=1)

def fit_pca(X):
    X=finite_matrix(X)
    if len(X)<2:raise ValueError('At least two observations for sample variance')
    mean=X.mean(axis=0);centered=X-mean
    _,singular,components=np.linalg.svd(centered,full_matrices=False)
    for i in range(len(components)):
        anchor=np.argmax(np.abs(components[i]))
        if components[i,anchor]<0:components[i]*=-1
    variance=singular**2/(len(X)-1);total=variance.sum()
    if total<=0:raise ValueError('Explained-variance ratio undefined for zero total variance')
    return {'mean':mean,'components':components,'singular':singular,'variance':variance,'ratio':variance/total}

def reconstruct(model,X,q):
    X=finite_matrix(X)
    if (X.shape[1]!=len(model['mean']) or not isinstance(q,int) or isinstance(q,bool) or not 0<=q<=len(model['components'])):
        raise ValueError('Aligned PCA query and retained component count')
    V=model['components'][:q]
    return (X-model['mean'])@V.T@V+model['mean']

def safe_silhouette(X,labels):
    labels=np.asarray(labels);count=len(np.unique(labels))
    return None if not 2<=count<len(labels) else float(silhouette_score(X,labels))

# %% Development diagnostics and three reproducible real-observation lab assets
def analyse_source(path):
    frame,X,groups,digest=load_source(path);outer,train,valid=split_budget(X,groups)
    scaler=StandardScaler().fit(X[train]);Z=scaler.transform(X[train]);Z_valid=scaler.transform(X[valid])
    sample=np.random.default_rng(42).choice(len(Z),size=1200,replace=False)
    diagnostics=[]
    for k in [2,3,4,5]:
        model=KMeans(n_clusters=k,n_init=10,random_state=42,algorithm='lloyd').fit(Z)
        diagnostics.append({'k':k,'train_mean_sse':float(model.inertia_/len(Z)),
            'validation_mean_sse':float(np.min(model.transform(Z_valid)**2,axis=1).mean()),
            'sample_train_silhouette':safe_silhouette(Z[sample],model.labels_[sample]),
            'sizes':np.bincount(model.labels_,minlength=k).tolist()})
    fixed=KMeans(n_clusters=3,n_init=10,random_state=42).fit(Z)
    alternative=KMeans(n_clusters=3,n_init=10,random_state=43).fit(Z)
    stability=float(adjusted_rand_score(fixed.labels_,alternative.labels_))
    pca=fit_pca(Z);reference=PCA(svd_solver='full').fit(Z)
    np.testing.assert_allclose(pca['variance'],reference.explained_variance_,atol=1e-10)
    compression=[]
    for q in range(4):
        restored=reconstruct(pca,Z_valid,q)
        compression.append({'q':q,'training_variance_kept':float(pca['ratio'][:q].sum()),
            'validation_coordinate_mse':float(np.mean((Z_valid-restored)**2))})
    # Separate, bounded 2-D teaching pool; income never enters coordinates/colors.
    indices=train[:96];raw=X[indices][:,[0,2]];coordinates=(raw-scaler.mean_[[0,2]])/scaler.scale_[[0,2]]
    points=[{'source_row_1based':int(i+1),'values':v.tolist(),'coordinates':z.tolist()} for i,v,z in zip(indices,raw,coordinates)]
    source={'source':'UCI Adult, Becker & Kohavi (1996), CC BY4.0','sha256':digest}
    runs=[]
    _,unique_indices=np.unique(coordinates,axis=0,return_index=True)
    unique_indices=np.sort(unique_indices)
    for k,seed in [(2,42),(3,42),(4,42),(3,7)]:
        chosen=np.random.default_rng(seed).choice(unique_indices,k,replace=False)
        initial=coordinates[chosen];states=lloyd_steps(coordinates,initial,max_steps=20)
        final=np.asarray(states[-1]['centers'])
        # Library empty-cluster policy differs, so compare only nonempty stable cases.
        labels=np.asarray(states[-1]['labels'])
        if len(np.unique(labels))==k and len(states)<21:
            ref=KMeans(n_clusters=k,init=initial,n_init=1,tol=1e-10,max_iter=300,algorithm='lloyd').fit(coordinates)
            self_objective=float(np.min(np.sum((coordinates[:,None,:]-final[None,:,:])**2,axis=2),axis=1).sum())
            np.testing.assert_allclose(self_objective,ref.inertia_,atol=1e-8)
        if np.any(np.diff([s['inertia'] for s in states])>1e-8):raise ValueError('Unexpected Lloyd objective increase')
        runs.append({'k':k,'seed':seed,'initial_source_rows':[int(indices[i]+1) for i in chosen],'states':states})
    kmeans_asset={**source,'scope':'First96 budget-training observations, age/hours only; fixed starts, keep empty centers; no target labels.',
        'points':points,'runs':runs}
    density_refs=[]
    for eps in [.15,.35,.75]:
        own,core,counts=density_partition(coordinates,eps,5);ref=DBSCAN(eps=eps,min_samples=5,algorithm='brute').fit(coordinates)
        ref_core=np.zeros(len(coordinates),dtype=bool);ref_core[ref.core_sample_indices_]=True
        np.testing.assert_array_equal(core,ref_core)
        if not np.array_equal(own<0,ref.labels_<0) or adjusted_rand_score(own,ref.labels_)<1-1e-12:raise ValueError('DBSCAN reference mismatch')
        density_refs.append({'eps':eps,'min_samples':5,'labels':own.tolist(),'core':core.tolist(),'counts':counts.tolist()})
    density_asset={**source,'scope':'Same96 real coordinates; deterministic core components then border assignment; eps-neighborhood includes self.',
        'points':points,'references':density_refs}
    pca_runs=[]
    for name,values in [('raw',raw),('standardized',coordinates)]:
        model=fit_pca(values);ref=PCA(svd_solver='full').fit(values)
        np.testing.assert_allclose(model['ratio'],ref.explained_variance_ratio_,atol=1e-10)
        np.testing.assert_allclose(reconstruct(model,values,1),ref.inverse_transform(ref.transform(values)[:,:1]@np.eye(1,2)),atol=1e-9)
        pca_runs.append({'space':name,'data':values.tolist(),'mean':model['mean'].tolist(),'components':model['components'].tolist(),
            'singular':model['singular'].tolist(),'variance_ratio':model['ratio'].tolist(),
            'reconstruction_mse':[float(np.mean((values-reconstruct(model,values,q))**2)) for q in range(3)]})
    pca_asset={**source,'scope':'PCA fit on same96 displayed rows separately per raw/standardized space; centering after scaling; q0 mean-only.',
        'source_rows':[p['source_row_1based'] for p in points],'runs':pca_runs}
    hierarchy=[]
    for method in ['single','complete','ward']:
        tree=linkage(coordinates,method=method,metric='euclidean');labels=fcluster(tree,3,criterion='maxclust')
        hierarchy.append({'method':method,'merge_rows':len(tree),'cut_unique_clusters':int(len(np.unique(labels))),
            'last_three_merges':tree[-3:].tolist()})
    dbscan_diagnostics=[]
    for row in density_refs:
        labels=np.asarray(row['labels']);assigned=labels>=0
        dbscan_diagnostics.append({'eps':row['eps'],'coverage':float(assigned.mean()),'clusters':int(len(np.unique(labels[assigned]))),
            'assigned_only_silhouette':safe_silhouette(coordinates[assigned],labels[assigned]) if assigned.any() else None})
    report={**source,'versions':{'python':platform.python_version(),'numpy':np.__version__,'pandas':pd.__version__,'sklearn':sklearn.__version__},
        'scope':'Exploratory reused historical source, no income labels used, no semantic/fairness/causal/deployment claim',
        'features':FEATURES,'outer_train_rows':len(outer),'budget_groups':int(len(np.unique(groups[train]))),'budget_rows':len(train),'validation_rows':len(valid),'seed':42,
        'kmeans_diagnostics':diagnostics,'fixed_k':3,'seed_stability_ari':stability,'pca_training_variance_ratio':pca['ratio'].tolist(),
        'pca_compression':compression,'density_subset_diagnostics':dbscan_diagnostics,'hierarchy_subset':hierarchy,
        'assumptions':['Raw profiles are grouping proxies, not verified independent persons; income/hours excluded from group keys.',
            'Scaling fit only on budget training. Income is not used for training, color assignment or hyperparameter choice.',
            'Silhouette uses the same fixed1200 training subsample for k diagnostics; no automatic best-k claim.',
            'DBSCAN noise coverage reported; assigned-only silhouette is conditional and not comparable to full-data scores.',
            'Seed ARI is one same-data sensitivity check, not confidence over the full data/search process.',
            'fnlwgt weights unused; unweighted historical rows. Reused source is not fresh confirmation.',
            'The2D lab pool/PCA fits differ from the3D main experiment; visual separation is not ground truth.']}
    return report,kmeans_asset,density_asset,pca_asset

def run_analysis(path):
    with threadpool_limits(limits=1):return analyse_source(path)

# %% Import-safe CLI and explicit derived-asset generation
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--write-labs',action='store_true')
    args=parser.parse_args(argv);report,km,db,pc=run_analysis(DATA/'adult.data')
    if args.write_labs:
        for name,asset in [('unsupervised_kmeans_lab.json',km),('unsupervised_density_lab.json',db),('unsupervised_pca_lab.json',pc)]:
            (DATA/name).write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);temporary=args.output.with_name(args.output.name+'.tmp')
        temporary.write_text(rendered+'\n',encoding='utf-8');temporary.replace(args.output)
    print(rendered);return report

if __name__=='__main__':main()
