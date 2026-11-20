"""Chapter 13: offline exploratory anomaly/forecast audit, original UCI Bike Sharing.

No verified anomaly labels. Alerts are model flags, not proven real-world events.
Only 2011 training and Jan-Jun 2012 development outcomes are used in experiments.
"""
# %% Local source and causal features
from pathlib import Path
import argparse
import hashlib
import json
import platform
import numpy as np
import pandas as pd
import sklearn
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import make_pipeline
from sklearn.linear_model import Ridge
from sklearn.ensemble import IsolationForest
from sklearn.neighbors import LocalOutlierFactor
from sklearn.svm import OneClassSVM
from sklearn.model_selection import TimeSeriesSplit
from threadpoolctl import threadpool_limits

DATA=Path(__file__).resolve().parent
SOURCE_HASH='a6bcf826782d3c0fbfdcbeead17cd0884185a0dafe8ff10cd48a874ee7ba18be'

def load_source(path):
    if hashlib.sha256(path.read_bytes()).hexdigest()!=SOURCE_HASH:raise ValueError('Expected original day.csv')
    frame=pd.read_csv(path,parse_dates=['dteday'])
    expected=pd.date_range('2011-01-01','2012-12-31',freq='D')
    if not frame.dteday.equals(pd.Series(expected)) or len(frame)!=731:raise ValueError('Unique, sorted, complete daily calendar required')
    y=frame.cnt.to_numpy(dtype=float,copy=True)
    if not np.isfinite(y).all() or (y<0).any():raise ValueError('Finite nonnegative daily counts')
    return frame,y

def finite_vector(values):
    values=np.asarray(values,dtype=float)
    if values.ndim!=1 or not len(values) or not np.isfinite(values).all():raise ValueError('Nonempty finite vector')
    return values

def lag_features(y,dates):
    y=finite_vector(y)
    if len(y)!=len(dates) or len(y)<15:raise ValueError('Aligned daily observations, at least 15 rows')
    values=pd.Series(y)
    # shift before rolling: row t may use only targets with index <t.
    features=pd.DataFrame({'lag1':values.shift(1),'lag7':values.shift(7),'lag14':values.shift(14),
        'past_mean7':values.shift(1).rolling(7).mean(),
        'weekday_sin':np.sin(2*np.pi*dates.dt.dayofweek/7),
        'weekday_cos':np.cos(2*np.pi*dates.dt.dayofweek/7)})
    return features.iloc[14:].to_numpy(),y[14:].copy(),np.arange(14,len(y))

# %% Auditable scores, metrics and origin-safe forecasts
def robust_fit(values):
    values=finite_vector(values);median=float(np.median(values));mad=float(np.median(np.abs(values-median)))
    if mad<=0:raise ValueError('Zero MAD: use an explicit alternative scale; no silent epsilon')
    return median,mad

def robust_scores(values,median,mad):
    values=finite_vector(values)
    if not np.isfinite(median) or not np.isfinite(mad) or mad<=0:raise ValueError('Finite center and positive MAD')
    return .6744897501960817*np.abs(values-median)/mad

def forecast(history,horizon,method,*,period=7,gap=0):
    history=finite_vector(history)
    if any(not isinstance(v,int) or isinstance(v,bool) for v in [horizon,period,gap]) or horizon<1 or period<1 or gap<0:raise ValueError('Integer positive horizon/period, nonnegative gap')
    leads=gap+np.arange(1,horizon+1)
    if method=='naive':return np.full(horizon,history[-1])
    if method=='seasonal':
        if len(history)<period:raise ValueError('At least one complete season')
        return history[-period:][(leads-1)%period].copy()
    if method=='drift':
        if len(history)<2:raise ValueError('Drift requires two observations')
        return history[-1]+leads*(history[-1]-history[0])/(len(history)-1)
    raise ValueError('Unknown baseline')

def metrics(actual,prediction,scale_history):
    actual,prediction,history=finite_vector(actual),finite_vector(prediction),finite_vector(scale_history)
    if actual.shape!=prediction.shape or len(history)<8:raise ValueError('Aligned predictions and seasonal training denominator')
    error=actual-prediction;den=float(np.mean(np.abs(history[7:]-history[:-7])))
    return {'mae':float(np.mean(np.abs(error))),'rmse':float(np.sqrt(np.mean(error**2))),
        'mase7':None if den==0 else float(np.mean(np.abs(error))/den)}

def temporal_fold(n,origin,horizon,*,gap=0,window=None):
    if any(not isinstance(v,int) or isinstance(v,bool) for v in [n,origin,horizon,gap]) or origin<8 or horizon<1 or gap<0 or origin+gap+horizon>n:raise ValueError('Bounded chronological fold')
    if window is not None and (not isinstance(window,int) or isinstance(window,bool) or window<8):raise ValueError('Training window >=8')
    start=0 if window is None else max(0,origin-window)
    return np.arange(start,origin),np.arange(origin,origin+gap),np.arange(origin+gap,origin+gap+horizon)

# %% Reproducible training-only fits and development diagnostics
def analyse_source(path):
    frame,all_y=load_source(path)
    # Last 184 outcomes stay outside every experiment/asset; source validation only.
    y=all_y[:547];dates=frame.dteday.iloc[:547];train_end=365
    train_residual=y[7:train_end]-y[:train_end-7]
    valid_residual=y[train_end:]-y[train_end-7:len(y)-7]
    median,mad=robust_fit(train_residual);scores=robust_scores(valid_residual,median,mad)
    detectors={
        'isolation_forest':IsolationForest(n_estimators=100,max_samples=256,contamination=.05,random_state=42),
        'lof_novelty':make_pipeline(StandardScaler(),LocalOutlierFactor(n_neighbors=20,novelty=True,contamination=.05)),
        'one_class_svm':make_pipeline(StandardScaler(),OneClassSVM(nu=.05,gamma='scale')),
    }
    alert_report=[]
    for name,model in detectors.items():
        model.fit(train_residual[:,None]);decision=model.decision_function(valid_residual[:,None])
        alert_report.append({'method':name,'development_alerts':int(np.sum(decision<0)),
            'development_rate':float(np.mean(decision<0)),'score_orientation':'negative decision_function = flag, not anomaly probability'})
    X,target,positions=lag_features(y,dates)
    training=positions<train_end;development=~training
    candidates=[];splits=list(TimeSeriesSplit(n_splits=3,test_size=56,gap=7).split(X[training]))
    for alpha in [.1,10.,1000.]:
        fold_scores=[]
        for tr,va in splits:
            model=make_pipeline(StandardScaler(),Ridge(alpha=alpha)).fit(X[training][tr],target[training][tr])
            fold_scores.append(float(np.mean(np.abs(target[training][va]-model.predict(X[training][va])))))
        candidates.append({'alpha':alpha,'training_cv_mae':float(np.mean(fold_scores))})
    selected=min(candidates,key=lambda r:(r['training_cv_mae'],r['alpha']))
    ridge=make_pipeline(StandardScaler(),Ridge(alpha=selected['alpha'])).fit(X[training],target[training])
    one_step={
        'naive':y[train_end-1:len(y)-1],
        'seasonal7':y[train_end-7:len(y)-7],
        'ridge_lags':ridge.predict(X[development]),
    }
    one_step_report={name:metrics(y[train_end:],pred,y[:train_end]) for name,pred in one_step.items()}
    # Every forecast origin uses only its training prefix, never subsequent labels.
    origins=[365,421,477];backtests=[]
    for origin in origins:
        for method in ['naive','seasonal','drift']:
            pred=forecast(y[:origin],14,method)
            backtests.append({'origin_date':str(dates.iloc[origin-1].date()),'horizon':14,'method':method,
                **metrics(y[origin:origin+14],pred,y[:origin])})
    queries=[{'source_row_1based':i+1,'date':str(dates.iloc[i].date()),'actual':float(y[i]),'lag7':float(y[i-7]),
        'residual':float(y[i]-y[i-7]),'robust_score':float(scores[i-train_end])} for i in range(365,407)]
    provenance={'source':'UCI Bike Sharing, Fanaee-T (2013), CC BY 4.0','sha256':SOURCE_HASH}
    asset={**provenance,'scope':'547 development observations only: 2011 training, Jan-Jun2012 validation; no verified anomaly labels',
        'dates':[str(d.date()) for d in dates],'counts':y.tolist(),'train_end':365,'anomaly_fit':{'median':median,'mad':mad,'training_residuals':358},
        'anomaly_queries':queries,
        'forecast_references':[{'origin':o,'horizon':h,'gap':g,'method':m,'prediction':forecast(y[:o],h,m,gap=g).tolist()}
            for o,h,g,m in [(365,7,0,'naive'),(365,14,0,'seasonal'),(421,14,7,'drift')]]}
    report={**provenance,'versions':{'python':platform.python_version(),'numpy':np.__version__,'pandas':pd.__version__,'sklearn':sklearn.__version__},
        'source_rows':731,'training_rows':365,'development_rows':182,'reserved_outcomes_not_evaluated':184,
        'training_lag_rows':int(training.sum()),'anomaly_training_residuals':358,
        'robust_fit':{'median':median,'mad':mad},'robust_threshold_3_5_development_alerts':int((scores>3.5).sum()),
        'detector_flags_without_ground_truth':alert_report,'ridge_candidates_training_cv':candidates,'selected_alpha':selected['alpha'],
        'one_step_development_metrics':one_step_report,'fixed_origin_14day_backtests':backtests,
        'assumptions':['Daily counts available after day close; each one-step prediction can use previous observed validation outcomes.',
            'Fixed-origin multi-step baselines use prefix only; no future outcomes or realized weather features.',
            'casual and registered excluded: they sum to same-day target; weather excluded because future realized values unavailable.',
            'Training CV gaps are row gaps, not an automatic guarantee for delayed labels or multi-step horizons.',
            'Lag features are causal; folds simulate one-step predictions with observed prior outcomes, not one fixed-origin 56-day forecast.',
            'No verified anomaly labels: counts/rates do not establish detection accuracy, event causes or alert utility.',
            'Historical aggregate series, no causal/current-demand/deployment claim; no automated model ranking across distinct protocols.']}
    return report,asset

def run_analysis(path):
    with threadpool_limits(limits=1):return analyse_source(path)

# %% Import-safe CLI; asset regeneration is explicit
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--write-labs',action='store_true')
    args=parser.parse_args(argv);report,asset=run_analysis(DATA/'day.csv');rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.write_labs:(DATA/'temporal_lab.json').write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);temporary=args.output.with_name(args.output.name+'.tmp')
        temporary.write_text(rendered+'\n',encoding='utf-8');temporary.replace(args.output)
    print(rendered);return report

if __name__=='__main__':main()
