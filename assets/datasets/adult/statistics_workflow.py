"""Chapter 8: scoped statistical inference on original local Adult observations.

Run: python assets/datasets/adult/statistics_workflow.py --output build/chapter-08-report.json
Needs numpy, pandas, scipy. No network, model fitting or external-test access.
See README.md for UCI attribution/CC BY 4.0. This historical source has already
been explored in the course; no fresh confirmatory, population-census or causal
claim is made. Raw-profile clusters are not guaranteed independent persons.
"""
# %% Local source and two declared descriptive estimands
from pathlib import Path
import argparse
import hashlib
import json
import platform
import numpy as np
import pandas as pd
import scipy
from scipy import stats

DATA = Path(__file__).resolve().parent
COLUMNS = ['age', 'workclass', 'fnlwgt', 'education', 'education_num',
           'marital_status', 'occupation', 'relationship', 'race', 'sex',
           'capital_gain', 'capital_loss', 'hours_per_week', 'native_country', 'income']
EXPECTED_HASH = '5b00264637dbfec36bdeaab5676b0b309ff9eb788d63554ca0a249491c86603d'

def load_source(path):
    source_hash = hashlib.sha256(path.read_bytes()).hexdigest()
    if source_hash != EXPECTED_HASH:
        raise ValueError('Expected original bundled adult.data')
    frame = pd.read_csv(path, names=COLUMNS, header=None, skipinitialspace=True, na_values='?')
    frame['income'] = frame['income'].astype('string').str.strip()
    if not frame['income'].isin(['<=50K', '>50K']).all():
        raise ValueError('Invalid or missing income label')
    for column in ['age', 'education_num', 'hours_per_week']:
        frame[column] = pd.to_numeric(frame[column], errors='raise')
        if not np.isfinite(frame[column].to_numpy(dtype=float)).all():
            raise ValueError('Expected finite numeric inputs')
    return frame, source_hash

# %% Transparent interval, Welch and profile-cluster bootstrap helpers
def wilson_interval(successes, n, confidence=.95):
    if (not isinstance(n, int) or isinstance(n, bool) or not isinstance(successes, int)
        or isinstance(successes, bool) or n < 1 or not 0 <= successes <= n
        or not np.isfinite(confidence) or not 0 < confidence < 1):
        raise ValueError('Valid binomial counts and confidence required')
    z = stats.norm.ppf((1+confidence)/2)
    p = successes/n
    denominator = 1+z*z/n
    center = (p+z*z/(2*n))/denominator
    half = z/denominator*np.sqrt(p*(1-p)/n+z*z/(4*n*n))
    return [0. if successes == 0 else float(max(0., center-half)),
            1. if successes == n else float(min(1., center+half))]

def welch_difference(a, b, confidence=.95):
    a, b = np.asarray(a, dtype=float), np.asarray(b, dtype=float)
    if (a.ndim != 1 or b.ndim != 1 or len(a) < 2 or len(b) < 2 or
        not np.isfinite(a).all() or not np.isfinite(b).all() or
        not np.isfinite(confidence) or not 0 < confidence < 1):
        raise ValueError('Two finite 1-D samples with n >= 2 required')
    term_a, term_b = a.var(ddof=1)/len(a), b.var(ddof=1)/len(b)
    se = np.sqrt(term_a+term_b)
    if se == 0 or not np.isfinite(se):
        raise ValueError('Degenerate or non-finite standard error')
    df = (term_a+term_b)**2/(term_a**2/(len(a)-1)+term_b**2/(len(b)-1))
    difference = float(a.mean()-b.mean())
    critical = stats.t.ppf((1+confidence)/2, df)
    statistic = difference/se
    return {'difference': difference, 'standard_error': float(se), 'df': float(df),
            'statistic': float(statistic), 'p_two_sided': float(2*stats.t.sf(abs(statistic), df)),
            'confidence_interval': [float(difference-critical*se), float(difference+critical*se)]}

def profile_bootstrap_means(values, group_ids, *, resamples=1000, rng):
    values, group_ids = np.asarray(values, dtype=float), np.asarray(group_ids)
    if (values.ndim != 1 or group_ids.ndim != 1 or len(values) != len(group_ids)
        or len(values) < 2 or not np.isfinite(values).all()
        or not isinstance(resamples, int) or isinstance(resamples, bool) or not 100 <= resamples <= 10000):
        raise ValueError('Aligned finite observations and resample count100..10000 required')
    _, inverse = np.unique(group_ids, return_inverse=True)
    counts = np.bincount(inverse)
    sums = np.bincount(inverse, weights=values)
    if len(counts) < 2:
        raise ValueError('Need at least two profile clusters')
    draws = np.empty(resamples)
    for i in range(resamples):
        selected = rng.integers(0, len(counts), size=len(counts))
        # Ratio-of-totals preserves the ROW-weighted estimand for unequal clusters.
        draws[i] = sums[selected].sum()/counts[selected].sum()
    return draws

# %% Reproducible analysis with explicit working assumptions
def run_analysis(path, *, resamples=1000):
    frame, source_hash = load_source(path)
    binary = (frame['income'] == '>50K').astype(int).to_numpy()
    n, successes = len(binary), int(binary.sum())
    row_wilson = wilson_interval(successes, n)
    scipy_wilson = stats.binomtest(successes, n).proportion_ci(confidence_level=.95, method='wilson')
    np.testing.assert_allclose(row_wilson, [scipy_wilson.low, scipy_wilson.high])
    # Both analysis outcomes are excluded; profile groups remain only a proxy.
    key_columns = [c for c in COLUMNS if c not in ('income', 'hours_per_week')]
    normalized = frame[key_columns].astype('string').fillna('__MISSING__')
    groups = pd.util.hash_pandas_object(normalized, index=False).to_numpy()
    mask_a = frame['education_num'].to_numpy() == 10  # Some-college
    mask_b = frame['education_num'].to_numpy() == 9   # HS-grad
    hours = frame['hours_per_week'].to_numpy(dtype=float)
    a, b = hours[mask_a], hours[mask_b]
    if not set(groups[mask_a]).isdisjoint(groups[mask_b]):
        raise ValueError('Cohort profile overlap')
    welch = welch_difference(a, b)
    reference = stats.ttest_ind(a, b, equal_var=False, alternative='two-sided', nan_policy='raise')
    np.testing.assert_allclose([welch['statistic'],welch['p_two_sided'],welch['df']],
                               [reference.statistic,reference.pvalue,reference.df])
    np.testing.assert_allclose(welch['confidence_interval'],reference.confidence_interval(.95))
    seed_sequence = np.random.SeedSequence(42)
    streams = [np.random.default_rng(seed) for seed in seed_sequence.spawn(3)]
    proportion_draws = profile_bootstrap_means(binary, groups, resamples=resamples, rng=streams[0])
    a_draws = profile_bootstrap_means(a, groups[mask_a], resamples=resamples, rng=streams[1])
    b_draws = profile_bootstrap_means(b, groups[mask_b], resamples=resamples, rng=streams[2])
    # Working i.i.d. Bernoulli likelihood + explicit Beta(1,1) prior;
    # this illustrative Bayesian model does NOT correct unknown dependence/bias.
    posterior_alpha, posterior_beta = successes+1, n-successes+1
    return {
        'source': 'UCI Adult, Becker & Kohavi (1996), CC BY 4.0', 'sha256': source_hash,
        'scope': 'Reused historical source; descriptive working models, no causal/population/confirmatory claim',
        'rows': n, 'positive_income': successes, 'observed_income_proportion': float(binary.mean()),
        'iid_row_wilson_95': row_wilson,
        'profile_clusters': int(len(np.unique(groups))),
        'profile_bootstrap_proportion_percentile_95': np.quantile(proportion_draws,[.025,.975]).tolist(),
        'beta_bernoulli_working_model': {'prior': [1,1], 'posterior': [posterior_alpha,posterior_beta],
            'posterior_mean': posterior_alpha/(posterior_alpha+posterior_beta),
            'equal_tail_credible_95': stats.beta.ppf([.025,.975],posterior_alpha,posterior_beta).tolist()},
        'declared_contrast': 'Some-college (education_num10) minus HS-grad (education_num9), hours/week',
        'cohort_a': {'rows':len(a), 'profile_clusters':int(len(np.unique(groups[mask_a]))), 'mean_hours':float(a.mean())},
        'cohort_b': {'rows':len(b), 'profile_clusters':int(len(np.unique(groups[mask_b]))), 'mean_hours':float(b.mean())},
        'iid_row_welch': welch,
        'profile_bootstrap_difference_percentile_95': np.quantile(a_draws-b_draws,[.025,.975]).tolist(),
        'resamples':resamples, 'seed':42,
        'assumptions': ['Row Wilson/Welch/Beta models assume independent observations as stated.',
            'Bootstrap assumes exchangeable independent profile clusters within each declared cohort.',
            'Profiles are not verified person IDs; raw rows are not a documented random census sample.',
            'fnlwgt sampling weights are not used. Intervals do not fix selection, confounding or historical bias.',
            'Percentile bootstrap may have poor finite-sample coverage; repetitions do not add observations.'],
        'versions': {'python':platform.python_version(),'numpy':np.__version__,'pandas':pd.__version__,'scipy':scipy.__version__},
    }

# %% Import-safe CLI and explicit report output
def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--resamples', type=int, default=1000)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args(argv)
    report = run_analysis(DATA/'adult.data', resamples=args.resamples)
    rendered = json.dumps(report, indent=2, allow_nan=False)
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_name(args.output.name+'.tmp')
        temporary.write_text(rendered+'\n',encoding='utf-8')
        temporary.replace(args.output)
    print(rendered)
    return report

if __name__ == '__main__':
    main()
