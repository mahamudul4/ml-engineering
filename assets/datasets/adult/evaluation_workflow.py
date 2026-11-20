"""Chapter 5: group-aware nested selection and scoped paired uncertainty.

Run: python assets/datasets/adult/evaluation_workflow.py
Local original UCI Adult files only. Requires numpy, pandas, scikit-learn.
See README.md for attribution/license. Not the canonical UCI benchmark.
External labels are used only after freezing the final search and threshold.
This test source was used in Chapter 4: it is not fresh confirmatory evidence.
"""
# %% Contract and local parsing
from pathlib import Path
import json
import platform
import numpy as np
import pandas as pd
import sklearn
from sklearn.base import clone
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.dummy import DummyClassifier
from sklearn.model_selection import GroupKFold, GridSearchCV
from sklearn.metrics import log_loss, f1_score, average_precision_score

DATA = Path(__file__).resolve().parent
COLUMNS = ['age', 'workclass', 'fnlwgt', 'education', 'education_num',
           'marital_status', 'occupation', 'relationship', 'race', 'sex',
           'capital_gain', 'capital_loss', 'hours_per_week', 'native_country',
           'income']
NUMERIC = ['age', 'education_num', 'capital_gain', 'capital_loss', 'hours_per_week']
CATEGORICAL = ['workclass', 'marital_status', 'occupation', 'native_country']
FEATURES = NUMERIC + CATEGORICAL
GRID = {'classifier__C': [0.1, 1.0, 10.0]}
THRESHOLD = 0.5  # Fixed in advance; no threshold tuning in this experiment.

def load_frame(name, test=False):
    frame = pd.read_csv(DATA / name, names=COLUMNS, header=None,
                        skipinitialspace=True, na_values='?',
                        skiprows=1 if test else 0)
    frame['income'] = frame['income'].str.strip().str.removesuffix('.')
    if not frame['income'].isin(['<=50K', '>50K']).all():
        raise ValueError('Missing/invalid target')
    for col in NUMERIC:
        frame[col] = pd.to_numeric(frame[col], errors='raise')
        if not np.isfinite(frame[col].dropna().to_numpy()).all():
            raise ValueError('Non-finite numeric input')
    for col in CATEGORICAL:
        values = frame[col].astype(object)
        frame[col] = values.where(pd.notna(values), np.nan)
    return frame

def profile_ids(frame):
    # Audit/split key only, excludes target; not proof of person identity.
    normalized = frame[COLUMNS[:-1]].astype('string').fillna('__MISSING__')
    return pd.util.hash_pandas_object(normalized, index=False).to_numpy()

development = load_frame('adult.data')
external = load_frame('adult.test', test=True)
groups = profile_ids(development)
external_groups = profile_ids(external)
mask = ~np.isin(external_groups, groups)
test = external.loc[mask].reset_index(drop=True)
test_groups = external_groups[mask]
X = development[FEATURES]
y = (development['income'] == '>50K').astype(int).to_numpy()

# %% Whole pipeline, inner selection and outer evaluation
numeric = Pipeline([
    ('impute', SimpleImputer(strategy='median', add_indicator=True,
                            keep_empty_features=True)),
    ('scale', StandardScaler()),
])
categorical = Pipeline([
    ('impute', SimpleImputer(strategy='constant', fill_value='__MISSING__',
                            keep_empty_features=True)),
    ('encode', OneHotEncoder(handle_unknown='infrequent_if_exist', min_frequency=20)),
])
recipe = Pipeline([
    ('prepare', ColumnTransformer([
        ('numeric', numeric, NUMERIC), ('categorical', categorical, CATEGORICAL),
    ], remainder='drop')),
    ('classifier', LogisticRegression(max_iter=2000)),
])

def make_search():
    return GridSearchCV(clone(recipe), GRID,
        cv=GroupKFold(n_splits=3, shuffle=True, random_state=17),
        scoring={'loss': 'neg_log_loss', 'ap': 'average_precision'},
        refit='loss', n_jobs=1, error_score='raise', return_train_score=True)

outer = GroupKFold(n_splits=3, shuffle=True, random_state=42)
oof = np.full(len(y), np.nan)
outer_rows = []
for fold, (train_idx, val_idx) in enumerate(outer.split(X, y, groups), start=1):
    assert set(groups[train_idx]).isdisjoint(set(groups[val_idx]))
    search = make_search()
    # Explicit groups reach the INNER splitter. The OUTER groups alone do not.
    search.fit(X.iloc[train_idx], y[train_idx], groups=groups[train_idx])
    probabilities = search.predict_proba(X.iloc[val_idx])[:, 1]
    oof[val_idx] = probabilities
    outer_rows.append({'fold': fold, 'train_rows': len(train_idx),
        'validation_rows': len(val_idx), 'selected_C': search.best_params_['classifier__C'],
        'log_loss': float(log_loss(y[val_idx], probabilities, labels=[0, 1]))})
assert np.isfinite(oof).all()

# %% Freeze final selection using development data only
final_search = make_search()
final_search.fit(X, y, groups=groups)
final_model = final_search.best_estimator_  # refit on ALL development rows.
baseline = DummyClassifier(strategy='prior').fit(X, y)
candidate_rows = []
for i, params in enumerate(final_search.cv_results_['params']):
    candidate_rows.append({'C': params['classifier__C'],
        'mean_cv_log_loss': float(-final_search.cv_results_['mean_test_loss'][i]),
        'descriptive_fold_sd': float(final_search.cv_results_['std_test_loss'][i]),
        'mean_cv_ap': float(final_search.cv_results_['mean_test_ap'][i])})
# Candidate grid, features, metric, split policy, slices and threshold were fixed
# before examining external results. Do not revise them to improve this test.
X_test = test[FEATURES]
y_test = (test['income'] == '>50K').astype(int).to_numpy()
p = final_model.predict_proba(X_test)[:, 1]
p_baseline = baseline.predict_proba(X_test)[:, 1]

# %% Paired profile-cluster bootstrap, slices and reproducible report
def row_log_loss(labels, probabilities):
    probabilities = np.clip(probabilities, 1e-15, 1 - 1e-15)
    return -(labels * np.log(probabilities) + (1 - labels) * np.log1p(-probabilities))

def cluster_interval(differences, group_ids, repetitions=1000, seed=42):
    differences = np.asarray(differences, dtype=float)
    group_ids = np.asarray(group_ids)
    if (differences.ndim != 1 or group_ids.ndim != 1 or
        len(differences) != len(group_ids) or len(differences) < 2 or
        not np.isfinite(differences).all() or repetitions < 100):
        raise ValueError('Need aligned finite differences and cluster IDs')
    _, inverse = np.unique(group_ids, return_inverse=True)
    count = np.bincount(inverse)
    sums = np.bincount(inverse, weights=differences)
    if len(count) < 2:
        raise ValueError('Need at least two independent clusters')
    rng = np.random.default_rng(seed)
    draws = np.empty(repetitions)
    for r in range(repetitions):
        chosen = rng.integers(0, len(count), size=len(count))
        # Resample entire clusters with replacement, keep model pairs aligned;
        # ratio of totals preserves the row-weighted metric for unequal groups.
        draws[r] = sums[chosen].sum() / count[chosen].sum()
    return {'estimate': float(differences.mean()),
            'percentile_95': np.quantile(draws, [0.025, 0.975]).tolist(),
            'clusters': len(count), 'repetitions': repetitions, 'seed': seed}

delta = row_log_loss(y_test, p_baseline) - row_log_loss(y_test, p)
uncertainty = cluster_interval(delta, test_groups)
slice_rows = []
# Predeclared age slices are diagnostic, not fairness certification.
for name, selection in [('age_under_30', test['age'].to_numpy() < 30),
                        ('age_30_plus', test['age'].to_numpy() >= 30)]:
    labels, probabilities = y_test[selection], p[selection]
    slice_rows.append({'slice': name, 'rows': int(selection.sum()),
        'positives': int(labels.sum()),
        'log_loss': float(log_loss(labels, probabilities, labels=[0, 1])),
        'f1_fixed_threshold': float(f1_score(labels, probabilities >= THRESHOLD, zero_division=0))})
report = {
    'protocol': 'profile-disjoint teaching evaluation; not canonical UCI benchmark',
    'test_reuse': 'Source used in Chapter 4; not fresh confirmatory evidence',
    'development_rows': len(X), 'original_test_rows': len(external),
    'excluded_overlap': int((~mask).sum()), 'evaluated_test_rows': len(test),
    'outer_folds': outer_rows,
    'outer_mean_log_loss': float(np.mean([r['log_loss'] for r in outer_rows])),
    'pooled_oof_log_loss': float(log_loss(y, oof, labels=[0, 1])),
    'selection_candidates': candidate_rows,
    'final_C': final_search.best_params_['classifier__C'],
    'fitted_features': len(final_model['prepare'].get_feature_names_out()),
    'fixed_threshold': THRESHOLD,
    'test_log_loss': float(log_loss(y_test, p, labels=[0, 1])),
    'baseline_log_loss': float(log_loss(y_test, p_baseline, labels=[0, 1])),
    'test_ap': float(average_precision_score(y_test, p)),
    'test_f1': float(f1_score(y_test, p >= THRESHOLD, zero_division=0)),
    'paired_loss_gain': uncertainty, 'predeclared_slices': slice_rows,
    'versions': {'python': platform.python_version(), 'numpy': np.__version__,
                 'pandas': pd.__version__, 'sklearn': sklearn.__version__},
}
print(json.dumps(report, indent=2))
# Interval is conditional on these fixed predictions and sampled profile-clusters.
# It omits training/search variability, unknown person-dependence and dataset shift.
# Age slices are not causal effects. The baseline comparison is not deployment proof.
