"""Chapter 7: linear algebra, gradient checking and optimization on real data.

Run: python assets/datasets/adult/math_workflow.py
Reads original local adult.data only; needs numpy, pandas, scikit-learn.
Source attribution/CC BY 4.0: sibling README.md. Target is hours_per_week,
not income. This is a fixed mathematical teaching experiment, not a canonical
benchmark, causal claim or fresh confirmatory evaluation. Source was explored
in earlier chapters. Identical raw profiles are groups, not proven person IDs.
"""
# %% Local source, split and training-only coordinates
from pathlib import Path
import hashlib
import json
import platform
import numpy as np
import pandas as pd
import sklearn
from sklearn.model_selection import GroupShuffleSplit

DATA = Path(__file__).resolve().parent
COLUMNS = ['age', 'workclass', 'fnlwgt', 'education', 'education_num',
           'marital_status', 'occupation', 'relationship', 'race', 'sex',
           'capital_gain', 'capital_loss', 'hours_per_week', 'native_country', 'income']
FEATURES = ['age', 'education_num', 'capital_gain', 'capital_loss']
TARGET = 'hours_per_week'
ALPHA = 0.1  # Fixed before diagnostics; intercept is not penalized.
path = DATA / 'adult.data'
source_hash = hashlib.sha256(path.read_bytes()).hexdigest()
if source_hash != '5b00264637dbfec36bdeaab5676b0b309ff9eb788d63554ca0a249491c86603d':
    raise ValueError('Expected original bundled adult.data')
frame = pd.read_csv(path, names=COLUMNS, header=None, skipinitialspace=True, na_values='?')
X = frame[FEATURES].to_numpy(dtype=np.float64, copy=True)
y = frame[TARGET].to_numpy(dtype=np.float64, copy=True)
if X.ndim != 2 or y.shape != (len(X),) or not np.isfinite(X).all() or not np.isfinite(y).all():
    raise ValueError('Expected aligned finite feature matrix and target')
# Exclude BOTH the regression outcome and income from the split/audit key.
profile_columns = [c for c in COLUMNS if c not in (TARGET, 'income')]
normalized = frame[profile_columns].astype('string').fillna('__MISSING__')
groups = pd.util.hash_pandas_object(normalized, index=False).to_numpy()
train, valid = next(GroupShuffleSplit(n_splits=1, test_size=.2, random_state=42).split(X, y, groups))
if not set(groups[train]).isdisjoint(groups[valid]):
    raise ValueError('Group overlap')
mean = X[train].mean(axis=0)
std = X[train].std(axis=0, ddof=0)
scale = np.where(std == 0, 1., std)
Z_train = (X[train] - mean) / scale
Z_valid = (X[valid] - mean) / scale
A = np.column_stack([np.ones(len(train)), Z_train])
A_valid = np.column_stack([np.ones(len(valid)), Z_valid])
y_train, y_valid = y[train], y[valid]
penalty = np.array([0., 1., 1., 1., 1.])

# %% One objective, its gradient and a numerical audit
def objective_gradient(A, y, theta, penalty, alpha):
    A, y, theta, penalty = [np.asarray(v, dtype=np.float64) for v in (A, y, theta, penalty)]
    if (A.ndim != 2 or A.shape[0] == 0 or A.shape[1] == 0 or
        y.shape != (A.shape[0],) or theta.shape != (A.shape[1],) or penalty.shape != theta.shape or
        not np.isfinite(alpha) or alpha < 0 or np.any(penalty < 0) or
        any(not np.isfinite(v).all() for v in (A, y, theta, penalty))):
        raise ValueError('Invalid objective shape/value contract')
    residual = A @ theta - y
    loss = .5 * np.mean(residual**2) + .5 * alpha * np.dot(penalty * theta, theta)
    gradient = A.T @ residual / len(y) + alpha * penalty * theta
    if not np.isfinite(loss) or not np.isfinite(gradient).all():
        raise ValueError('Objective or gradient overflow')
    return float(loss), gradient

def finite_difference(A, y, theta, penalty, alpha, epsilon=1e-5):
    if not np.isfinite(epsilon) or epsilon <= 0:
        raise ValueError('Positive finite epsilon required')
    theta = np.array(theta, dtype=np.float64, copy=True)
    objective_gradient(A, y, theta, penalty, alpha)  # Validate before perturbing.
    result = np.empty_like(theta)
    for j in range(len(theta)):
        step = epsilon * max(1., abs(theta[j]))
        plus, minus = theta.copy(), theta.copy()
        plus[j] += step; minus[j] -= step
        result[j] = (objective_gradient(A,y,plus,penalty,alpha)[0] -
                     objective_gradient(A,y,minus,penalty,alpha)[0]) / (2*step)
    return result

probe = np.array([1., -.4, .2, .1, -.2])
_, analytic = objective_gradient(A, y_train, probe, penalty, ALPHA)
numeric = finite_difference(A, y_train, probe, penalty, ALPHA)
gradient_relative_error = np.linalg.norm(analytic-numeric) / max(1., np.linalg.norm(analytic), np.linalg.norm(numeric))
if gradient_relative_error > 1e-6:
    raise ValueError('Gradient check failed')

# %% SVD reference, curvature and deterministic gradient descent
n, d = A.shape
H = A.T @ A / n + ALPHA * np.diag(penalty)
eigenvalues = np.linalg.eigvalsh(H)
if eigenvalues[0] <= 0:
    raise ValueError('Expected positive-definite Hessian in this fixed example')
rate = 1. / eigenvalues[-1]
# Augmented least squares solves THE SAME ridge objective; no matrix inverse.
augmented_A = np.vstack([A, np.diag(np.sqrt(n * ALPHA * penalty))])
augmented_y = np.concatenate([y_train, np.zeros(d)])
reference, _, augmented_rank, _ = np.linalg.lstsq(augmented_A, augmented_y, rcond=None)
theta = np.zeros(d)
history = []
for _ in range(500):
    loss, gradient = objective_gradient(A, y_train, theta, penalty, ALPHA)
    history.append(loss)
    theta = theta - rate * gradient
final_loss, final_gradient = objective_gradient(A, y_train, theta, penalty, ALPHA)
history.append(final_loss)
reference_loss, _ = objective_gradient(A, y_train, reference, penalty, ALPHA)
if not np.all(np.diff(history) <= 1e-9) or np.linalg.norm(final_gradient) > 1e-7:
    raise ValueError('Unexpected descent behavior')
np.testing.assert_allclose(theta, reference, rtol=1e-8, atol=1e-8)
# Duplicate a column to demonstrate nonunique unregularized coefficients.
duplicate_A = np.column_stack([A, A[:, 1]])
plain, _, plain_rank, singular = np.linalg.lstsq(A, y_train, rcond=None)
duplicate, _, duplicate_rank, _ = np.linalg.lstsq(duplicate_A, y_train, rcond=None)
np.testing.assert_allclose(A @ plain, duplicate_A @ duplicate, rtol=1e-9, atol=1e-9)

# %% Frozen diagnostics and clearly scoped validation report
prediction = A_valid @ theta
baseline = np.full_like(y_valid, y_train.mean())
report = {
    'source': 'UCI Adult, Becker & Kohavi (1996), CC BY 4.0', 'sha256': source_hash,
    'scope': 'Fixed teaching experiment; reused source, no external test or causal claim',
    'target': TARGET, 'features': FEATURES, 'rows': len(frame),
    'train_rows': len(train), 'validation_rows': len(valid),
    'profile_key_excludes': [TARGET, 'income'],
    'training_mean': mean.tolist(), 'training_scale_ddof0': scale.tolist(),
    'design_shape': list(A.shape), 'unregularized_rank': int(plain_rank),
    'singular_values': singular.tolist(), 'design_condition_number': float(singular[0]/singular[-1]),
    'duplicate_columns': duplicate_A.shape[1], 'duplicate_rank': int(duplicate_rank),
    'alpha': ALPHA, 'penalty_mask': penalty.tolist(), 'hessian_eigenvalues': eigenvalues.tolist(),
    'hessian_condition_number': float(eigenvalues[-1]/eigenvalues[0]),
    'learning_rate': float(rate), 'steps': 500,
    'gradient_relative_error': float(gradient_relative_error),
    'initial_objective': history[0], 'final_objective': final_loss,
    'reference_objective': reference_loss, 'final_gradient_norm': float(np.linalg.norm(final_gradient)),
    'theta_distance_to_reference': float(np.linalg.norm(theta-reference)),
    'validation_mae_hours': float(np.mean(np.abs(prediction-y_valid))),
    'validation_rmse_hours': float(np.sqrt(np.mean((prediction-y_valid)**2))),
    'baseline_rmse_hours': float(np.sqrt(np.mean((baseline-y_valid)**2))),
    'versions': {'python': platform.python_version(), 'numpy': np.__version__,
                 'pandas': pd.__version__, 'sklearn': sklearn.__version__},
}
print(json.dumps(report, indent=2, allow_nan=False))
# Convergence to a training objective does not establish generalization quality.
# Feature scaling changes the coordinates in which ridge is defined. No tuning
# on validation results; reporting a fixed reference is not a benchmark search.
