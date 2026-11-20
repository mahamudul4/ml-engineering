"""Chapter37: real historical NSW contrasts and explicitly scoped design rehearsals.

Original public data: CC BY-NC2.0,Dehejia/Wahba/LaLonde;see source_manifest.json.
No invented potential outcomes,live experiment,medical/policy advice or GPU work.
Import/default CLI preserve assets;--write-lab explicitly regenerates derived JSON.
"""
from pathlib import Path
import argparse,hashlib,json,math
import numpy as np
from scipy import stats

DATA=Path(__file__).resolve().parent
OUTCOMES=('earnings','positive')
CONFIDENCES=(.9,.95,.99)
SOURCE_FILES=('nswre74_treated.txt','nswre74_control.txt','psid_controls.txt')
def payload(x):return json.dumps(x,sort_keys=True,ensure_ascii=False,separators=(',',':'))+'\n'
def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def source_manifest():return json.loads((DATA/'source_manifest.json').read_text(encoding='utf-8'))
def load():
    manifest=source_manifest();cohorts={}
    for name,n,treated,cohort in [('nswre74_treated.txt',185,1,'treated'),('nswre74_control.txt',260,0,'experimental'),('psid_controls.txt',2490,0,'psid')]:
        if digest(DATA/name)!=manifest['files'][name]['sha256']:raise ValueError('Source hash mismatch:'+name)
        result=[]
        for i,line in enumerate((DATA/name).read_text().splitlines()):
            values=[float(v)for v in line.split()]
            if len(values)!=10 or not all(math.isfinite(v)for v in values)or values[0]!=treated or any(v not in(0,1)for v in values[3:7])or any(v<0 for v in values):raise ValueError('Invalid source record')
            for j in [0,1,2,3,4,5,6]:
                if not values[j].is_integer():raise ValueError('Invalid integer field')
            result.append(dict(key=cohort+':'+str(i+1),treat=treated,age=int(values[1]),education=int(values[2]),re74=values[7],re75=values[8],re78=values[9]))
        if len(result)!=n:raise ValueError('Source count mismatch')
        cohorts[cohort]=result
    return cohorts
def values(rows,outcome='earnings'):
    if outcome not in OUTCOMES:raise ValueError('Unknown outcome')
    return [r['re78']if outcome=='earnings'else float(r['re78']>0)for r in rows]
def summary(x):
    n=len(x)
    if n<2:raise ValueError('At least two units required')
    mean=sum(x)/n;variance=sum((v-mean)**2 for v in x)/(n-1)
    return dict(n=n,mean=mean,variance=variance)
def welch(treated,control,confidence=.95):
    if not 0<confidence<1:raise ValueError('Invalid confidence')
    t=summary(treated);c=summary(control);a=t['variance']/t['n'];b=c['variance']/c['n'];se=math.sqrt(a+b);delta=t['mean']-c['mean']
    if se==0:raise ValueError('No sampling variance')
    df=(a+b)**2/(a*a/(t['n']-1)+b*b/(c['n']-1));critical=float(stats.t.ppf((1+confidence)/2,df));p=float(2*stats.t.sf(abs(delta/se),df))
    return dict(treated=t,control=c,delta=delta,se=se,df=df,critical=critical,confidence=confidence,lower=delta-critical*se,upper=delta+critical*se,p_value=p,relative=delta/c['mean']if c['mean']!=0 else None)
def holm(pvalues):
    if any(not math.isfinite(p)or not 0<=p<=1 for p in pvalues):raise ValueError('Invalid p-value')
    result=[0.]*len(pvalues);running=0.
    for rank,j in enumerate(sorted(range(len(pvalues)),key=lambda i:(pvalues[i],i))):running=max(running,min(1.,(len(pvalues)-rank)*pvalues[j]));result[j]=running
    return result
def randomization(null_values,observed,draws=1000):
    if type(draws)is not int or not 1<=draws<=len(null_values):raise ValueError('Invalid draw count')
    selected=null_values[:draws];tol=1e-10*max(1,abs(observed));extreme=sum(abs(v)>=abs(observed)-tol for v in selected);p=(extreme+1)/(draws+1)
    lo=min(min(selected),observed);hi=max(max(selected),observed);width=(hi-lo)/12 if hi>lo else 1.;bins=[0]*12
    for v in selected:bins[min(11,max(0,int((v-lo)/width)))]+=1
    return dict(draws=draws,extreme=extreme,p_value=p,mc_se=math.sqrt(p*(1-p)/(draws+1)),minimum=lo,maximum=hi,bins=bins,scope='Absolute-tail Monte Carlo under sharp null,conditional complete-randomization illustration;not original assignment protocol or exact enumeration')
def bucket(key):
    h=2166136261
    for b in key.encode():h=((h^b)*16777619)&0xffffffff
    return h%10000
def logging_rehearsal(rows,loss=False):
    counts=[0,0];dropped=0
    for j,r in enumerate(rows):
        arm=int(bucket('ch37-assignment:'+r['key'])<5000)
        if loss and arm==1 and j%3==0:dropped+=1
        else:counts[arm]+=1
    total=sum(counts);expected=total/2;chi=sum((n-expected)**2/expected for n in counts);p=float(stats.chi2.sf(chi,1))
    return dict(source_units=len(rows),observed_units=total,control=counts[0],treated=counts[1],dropped=dropped,chi_square=chi,p_value=p,expected_treated=.5,threshold=.001,flag=p<.001,scope='SOFTWARE FIXTURE:reassigned ordinal source keys and optional treatment-dependent logging loss;not NSW assignment/exposure logs or original SRM test')
def normal_power(sigma,delta,n1,n0,alpha=.05):
    if sigma<=0 or delta<=0 or n1<2 or n0<2 or not 0<alpha<1:raise ValueError('Invalid power inputs')
    mu=delta/(sigma*math.sqrt(1/n1+1/n0));z=float(stats.norm.ppf(1-alpha/2));return float(stats.norm.cdf(mu-z)+stats.norm.cdf(-mu-z))
def plan(sigma,delta=2000,allocation=.5,alpha=.05,power=.8,cluster_size=1,icc=0):
    if not(sigma>0 and delta>0 and 0<allocation<1 and 0<alpha<1 and .5<power<1 and type(cluster_size)is int and cluster_size>=1 and 0<=icc<1):raise ValueError('Invalid design inputs')
    za=float(stats.norm.ppf(1-alpha/2));zb=float(stats.norm.ppf(power));total=sigma*sigma*(za+zb)**2/(delta*delta*allocation*(1-allocation));de=1+(cluster_size-1)*icc;n1=max(2,math.ceil(total*allocation));n0=max(2,math.ceil(total*(1-allocation)));adjusted=math.ceil((n1+n0)*de)
    return dict(sigma=sigma,delta=delta,allocation=allocation,alpha=alpha,power_target=power,z_alpha=za,z_power=zb,unrounded_total=total,treated=n1,control=n0,total=n1+n0,achieved_normal_power=normal_power(sigma,delta,n1,n0,alpha),cluster_size=cluster_size,icc=icc,design_effect=de,adjusted_units=adjusted,clusters=math.ceil(adjusted/cluster_size),scope='Approximate prospective common-variance independent-unit normal calculation;historical control SD is only a planning plug-in. DE is an equal-cluster planning assumption,not cluster-robust inference or measured NSW ICC')
def smd(a,b):
    ta=summary(a);cb=summary(b);denom=math.sqrt((ta['variance']+cb['variance'])/2);return (ta['mean']-cb['mean'])/denom if denom else None
def observational(cohorts,comparison='psid',outcome='earnings',adjust=False):
    if comparison not in ('experimental','psid'):raise ValueError('Unknown comparison')
    t=cohorts['treated'];c=cohorts[comparison];ty=values(t,outcome);cy=values(c,outcome);raw=sum(ty)/len(ty)-sum(cy)/len(cy);strata=[];adjusted=0.;overlap=True
    for positive in (False,True):
        tr=[r for r in t if (r['re74']>0)==positive];cr=[r for r in c if (r['re74']>0)==positive];weight=len(tr)/len(t);tm=sum(values(tr,outcome))/len(tr)if tr else None;cm=sum(values(cr,outcome))/len(cr)if cr else None;gap=tm-cm if tm is not None and cm is not None else None
        if weight>0 and gap is None:overlap=False
        if gap is not None:adjusted+=weight*gap
        strata.append(dict(prior_positive=positive,treated=len(tr),control=len(cr),weight=weight,treated_mean=tm,control_mean=cm,gap=gap))
    return dict(comparison=comparison,outcome=outcome,treated=len(t),control=len(c),raw_gap=raw,adjusted_gap=adjusted if overlap else None,shown_gap=(adjusted if overlap else None)if adjust else raw,adjusted=adjust,empirical_overlap=overlap,strata=strata,smd={k:smd([r[k]for r in t],[r[k]for r in c])for k in ['age','education','re74','re75']},scope='Descriptive pre74-positive strata weighted to185 treated units;ATT-like standardization,not an identified causal ATT. Two occupied coarse strata do not establish full positivity/no hidden confounding. Experimental raw contrast has a different weighting/estimand.')
def ancova(cohorts):
    rows=cohorts['treated']+cohorts['experimental'];x=np.array([r['re75']for r in rows]);x=(x-x.mean())/x.std();t=np.array([r['treat']for r in rows]);y=np.array(values(rows));design=np.column_stack([np.ones(len(y)),t,x,t*x]);beta=np.linalg.lstsq(design,y,rcond=None)[0];inv=np.linalg.inv(design.T@design);res=y-design@beta;h=np.einsum('ij,jk,ik->i',design,inv,design);cov=inv@(design.T@((res*res/(1-h))[:,None]*design))@inv;se=float(np.sqrt(cov[1,1]));return dict(coefficients=beta.tolist(),delta=float(beta[1]),hc2_se=se,lower=float(beta[1]-stats.norm.ppf(.975)*se),upper=float(beta[1]+stats.norm.ppf(.975)*se),covariate='re75,pooled centered/scaled,fully interacted with treatment',scope='Retrospective Lin-style OLS adjustment with HC2 normal interval,not original preregistration or automatically better variance')
def analyse():
    cohorts=load();rows=cohorts['treated']+cohorts['experimental'];trial={};null={k:[]for k in OUTCOMES};bank=[];n1=len(cohorts['treated'])
    for k in OUTCOMES:trial[k]={str(conf):welch(values(cohorts['treated'],k),values(cohorts['experimental'],k),conf)for conf in CONFIDENCES}
    for draw in range(1000):
        indices=np.random.default_rng(37000+draw).permutation(len(rows))[:n1].tolist();record=dict(seed=37000+draw,treated_indices=indices)
        for k in OUTCOMES:
            y=values(rows,k);treated_sum=sum(y[i]for i in indices);delta=treated_sum/n1-(sum(y)-treated_sum)/(len(rows)-n1);record[k]=delta;null[k].append(delta)
        bank.append(record)
    sigma=math.sqrt(trial['earnings']['0.95']['control']['variance']);references={}
    for delta in (1000,2000,4000):
        for allocation in (.4,.5,.7):
            for alpha in (.05,.01):
                for power in (.8,.9):
                    for size,icc in [(1,0),(5,.05),(10,.2)]:
                        key=':'.join(map(str,[delta,allocation,alpha,power,size,icc]));references[key]=plan(sigma,delta,allocation,alpha,power,size,icc)
    return dict(report=dict(source_sha256={n:digest(DATA/n)for n in SOURCE_FILES},experimental_units=445,treated=185,experimental_controls=260,external_psid_controls=2490,license='CC BY-NC 2.0',source=source_manifest()['source_page'],protocol='Historical DW pre-intervention selected male NSW subset;original allocation/exposure/attrition protocol and individual counterfactuals unavailable. Retrospective teaching analysis,not preregistered or current policy advice. Monetary units unchanged,no inflation conversion;positive outcome means re78>0,not independently observed employment.'),cohorts=cohorts,trial=trial,permutation_bank=bank,randomization={k:{str(n):randomization(null[k],trial[k]['0.95']['delta'],n)for n in (100,500,1000)}for k in OUTCOMES},planning_sigma=sigma,planning=references,normal_quantiles={str(p):float(stats.norm.ppf(p))for p in (.6,.8,.9,.95,.975,.995)},logging={str(loss):logging_rehearsal(rows,loss)for loss in (False,True)},observational={comp:{outcome:{str(adj):observational(cohorts,comp,outcome,adj)for adj in (False,True)}for outcome in OUTCOMES}for comp in ('experimental','psid')},multiplicity=dict(outcomes=list(OUTCOMES),raw=[trial[k]['0.95']['p_value']for k in OUTCOMES],holm=holm([trial[k]['0.95']['p_value']for k in OUTCOMES])),ancova=ancova(cohorts))
def export_bundle(directory,lab):
    directory=Path(directory);directory.mkdir(parents=True,exist_ok=True)
    contract=dict(source_sha256=lab['report']['source_sha256'],experimental_units=445,outcomes=['earnings=re78','positive=1[re78>0]'],null='sharp zero effect;conditional complete randomization185/445 illustration',permutation_seeds=[37000,37999],assignment_protocol_recovered=False,individual_counterfactuals_observed=False)
    for name,data in [('experiment_lab.json',lab),('analysis_contract.json',contract),('source_manifest.json',source_manifest())]:(directory/name).write_text(payload(data),encoding='utf-8',newline='\n')
    (directory/'LICENSE.txt').write_bytes((DATA/'LICENSE.txt').read_bytes());(directory/'ATTRIBUTION.txt').write_text('Source: '+source_manifest()['source_page']+'\nLaLonde(1986);Dehejia and Wahba(1999,2002). CC BY-NC2.0.\nOriginal source files unchanged;retrospective derived analysis,randomization/design/logging rehearsals labeled. No individual counterfactuals invented.\n',encoding='utf-8')
    names=['experiment_lab.json','analysis_contract.json','source_manifest.json','LICENSE.txt','ATTRIBUTION.txt'];(directory/'checksums.json').write_text(payload({n:digest(directory/n)for n in names}),encoding='utf-8')
def verify_bundle(directory):
    directory=Path(directory);checks=json.loads((directory/'checksums.json').read_text());names={'experiment_lab.json','analysis_contract.json','source_manifest.json','LICENSE.txt','ATTRIBUTION.txt'}
    if set(checks)!=names:raise ValueError('Incomplete analysis bundle')
    for name,h in checks.items():
        if digest(directory/name)!=h:raise ValueError('Checksum mismatch:'+name)
    lab=json.loads((directory/'experiment_lab.json').read_text(encoding='utf-8'));contract=json.loads((directory/'analysis_contract.json').read_text());manifest=json.loads((directory/'source_manifest.json').read_text())
    if contract['source_sha256']!=lab['report']['source_sha256']or any(manifest['files'][k]['sha256']!=v for k,v in contract['source_sha256'].items())or contract['experimental_units']!=445 or contract['individual_counterfactuals_observed']or contract['assignment_protocol_recovered']:raise ValueError('Analysis contract mismatch')
    if [len(lab['cohorts'][k])for k in ['treated','experimental','psid']]!=[185,260,2490]or digest(directory/'LICENSE.txt')!=manifest['files']['LICENSE.txt']['sha256']:raise ValueError('Analysis source mismatch')
    return dict(verified=True,files=5,experimental_units=445,external_controls=2490)
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--write-lab',action='store_true');parser.add_argument('--artifact-dir',type=Path);parser.add_argument('--verify-dir',type=Path);args=parser.parse_args()
    if args.verify_dir:print(json.dumps(verify_bundle(args.verify_dir)));return
    lab=analyse()
    if args.write_lab:(DATA/'experiment_lab.json').write_text(payload(lab),encoding='utf-8',newline='\n')
    if args.artifact_dir:export_bundle(args.artifact_dir,lab)
    print(json.dumps({k:lab[k]for k in ['report','trial','planning_sigma','logging','multiplicity','ancova']},indent=2))
if __name__=='__main__':main()
