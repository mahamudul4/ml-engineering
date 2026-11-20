"""Chapter 4: leakage-aware mixed-data preparation on the real UCI Adult files.

Run from any working directory: python assets/datasets/adult/workflow.py
Requires pandas, numpy, scikit-learn. Reads local bundled files, no network.
Data attribution/license are in the sibling README.md. This is a teaching
protocol with profile-disjoint evaluation, not UCI's canonical benchmark.
"""
# %% Load and validate
from pathlib import Path
import json
import numpy as np
import pandas as pd
from sklearn.model_selection import GroupShuffleSplit
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.dummy import DummyClassifier
from sklearn.metrics import f1_score, average_precision_score, log_loss

DATA = Path(__file__).resolve().parent
COLUMNS = ["age", "workclass", "fnlwgt", "education", "education_num",
           "marital_status", "occupation", "relationship", "race", "sex",
           "capital_gain", "capital_loss", "hours_per_week", "native_country",
           "income"]
NUMERIC = ["age", "education_num", "capital_gain", "capital_loss", "hours_per_week"]
CATEGORICAL = ["workclass", "marital_status", "occupation", "native_country"]
FEATURES = NUMERIC + CATEGORICAL

def load_adult(path, test=False):
    frame = pd.read_csv(path, names=COLUMNS, header=None, skipinitialspace=True,
                        na_values="?", skiprows=1 if test else 0)
    frame["income"] = frame["income"].str.strip().str.removesuffix(".")
    if frame["income"].isna().any() or not frame["income"].isin(["<=50K", ">50K"]).all():
        raise ValueError("Unexpected or missing target")
    for name in NUMERIC:
        frame[name] = pd.to_numeric(frame[name], errors="raise")
        if not np.isfinite(frame[name].dropna().to_numpy()).all():
            raise ValueError("Non-finite numeric feature")
    # Normalize pandas string missing values to np.nan for sklearn imputers.
    for name in CATEGORICAL:
        values = frame[name].astype(object)
        frame[name] = values.where(pd.notna(values), np.nan)
    return frame

development = load_adult(DATA / "adult.data")
external_test = load_adult(DATA / "adult.test", test=True)

# %% Split before fitting any learned transformation
def profile_ids(frame):
    # Split/audit key, never a model input. Excludes the target.
    values = frame[COLUMNS[:-1]].astype("string").fillna("__MISSING__")
    return pd.util.hash_pandas_object(values, index=False)

dev_groups = profile_ids(development)
test_groups = profile_ids(external_test)
splitter = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=42)
train_idx, val_idx = next(splitter.split(development, groups=dev_groups))
assert set(dev_groups.iloc[train_idx]).isdisjoint(set(dev_groups.iloc[val_idx]))
# Conservatively exclude exact feature profiles already in development data.
test_mask = ~test_groups.isin(set(dev_groups))
test_frame = external_test.loc[test_mask].copy()
train_frame = development.iloc[train_idx].copy()
val_frame = development.iloc[val_idx].copy()
X_train, X_val, X_test = [f[FEATURES] for f in [train_frame, val_frame, test_frame]]
y_train, y_val, y_test = [(f["income"] == ">50K").astype(int)
                        for f in [train_frame, val_frame, test_frame]]
assert set(profile_ids(test_frame)).isdisjoint(set(dev_groups))

# %% Fit one complete pipeline on training data only
numeric = Pipeline([
    ("impute", SimpleImputer(strategy="median", add_indicator=True,
                            keep_empty_features=True)),
    ("scale", StandardScaler()),
])
categorical = Pipeline([
    ("impute", SimpleImputer(strategy="constant", fill_value="__MISSING__",
                            keep_empty_features=True)),
    ("encode", OneHotEncoder(handle_unknown="infrequent_if_exist",
                             min_frequency=20)),
])
prepare = ColumnTransformer([
    ("numeric", numeric, NUMERIC),
    ("categorical", categorical, CATEGORICAL),
], remainder="drop")
model = Pipeline([
    ("prepare", prepare),
    ("classifier", LogisticRegression(C=1.0, max_iter=2000)),
])
model.fit(X_train, y_train)
# Transform uses training-fitted statistics; never fit again on validation/test.
val_scores = model.predict_proba(X_val)[:, 1]
val_f1 = f1_score(y_val, val_scores >= 0.5, zero_division=0)
output_names = model["prepare"].get_feature_names_out()
assert model["prepare"].transform(X_val).shape[1] == len(output_names)

# %% Freeze the recipe and report a clearly scoped held-out result
test_scores = model.predict_proba(X_test)[:, 1]
baseline = DummyClassifier(strategy="prior").fit(X_train, y_train)
baseline_scores = baseline.predict_proba(X_test)[:, 1]
report = {
    "source": "UCI Adult, Becker & Kohavi (1996), CC BY 4.0",
    "protocol": "raw-profile-disjoint split; not the canonical benchmark",
    "source_development_rows": len(development),
    "source_test_rows": len(external_test),
    "train_rows": len(X_train), "validation_rows": len(X_val),
    "evaluated_test_rows": len(X_test),
    "excluded_test_profile_overlap": int((~test_mask).sum()),
    "development_full_row_duplicates": int(development.duplicated().sum()),
    "development_missing": development.isna().sum().to_dict(),
    "transformed_features": len(output_names),
    "validation_f1_fixed_threshold": float(val_f1),
    "test_f1_fixed_threshold": float(f1_score(y_test, test_scores >= 0.5, zero_division=0)),
    "test_average_precision": float(average_precision_score(y_test, test_scores)),
    "test_log_loss": float(log_loss(y_test, test_scores, labels=[0, 1])),
    "baseline_log_loss": float(log_loss(y_test, baseline_scores, labels=[0, 1])),
}
print(json.dumps(report, indent=2))
# Save the whole fitted pipeline plus feature schema, target mapping, split
# policy and package versions when turning this experiment into an artifact.
# No clinical, employment, lending, fairness, or production claim is made.
