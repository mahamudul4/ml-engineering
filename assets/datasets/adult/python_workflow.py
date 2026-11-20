"""Chapter 6: tested, chunked local Adult data audit, not model evaluation.

Run: python assets/datasets/adult/python_workflow.py --chunk-size 1024
Optional: --output build/chapter-06-audit.json
Requires numpy/pandas; reads only adult.data. No APIs or downloads.
Original source attribution/CC BY 4.0 are in README.md. Profile row IDs here
are source positions, not person identifiers. Full-source summaries are audit
outputs; do not reuse them as training-fitted features in validation/test.
"""
# %% Imports and explicit data contract
from __future__ import annotations
import argparse
from collections import Counter
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import platform
from typing import Iterator
import numpy as np
import pandas as pd

DATA = Path(__file__).resolve().parent
COLUMNS = ['age', 'workclass', 'fnlwgt', 'education', 'education_num',
           'marital_status', 'occupation', 'relationship', 'race', 'sex',
           'capital_gain', 'capital_loss', 'hours_per_week', 'native_country', 'income']
NUMERIC = ('age', 'education_num', 'capital_gain', 'capital_loss', 'hours_per_week')
EXPECTED_SHA256 = '5b00264637dbfec36bdeaab5676b0b309ff9eb788d63554ca0a249491c86603d'

def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()

def validate_frame(frame: pd.DataFrame) -> pd.DataFrame:
    if frame.columns.tolist() != COLUMNS:
        raise ValueError('Unexpected names/order or duplicate columns')
    clean = frame.copy()
    clean['income'] = clean['income'].astype('string').str.strip()
    if not clean['income'].isin(['<=50K', '>50K']).all():
        raise ValueError('Missing or unexpected training label')
    for column in NUMERIC:
        clean[column] = pd.to_numeric(clean[column], errors='raise')
        observed = clean[column].dropna().to_numpy(dtype=np.float64)
        if not np.isfinite(observed).all():
            raise ValueError(f'Non-finite numeric value: {column}')
    if not clean['age'].dropna().between(0, 120).all():
        raise ValueError('Age outside this exercise contract, 0..120 years')
    return clean

def iter_validated_chunks(path: Path, chunk_size: int) -> Iterator[pd.DataFrame]:
    if not isinstance(chunk_size, int) or isinstance(chunk_size, bool) or not 1 <= chunk_size <= 1_000_000:
        raise ValueError('chunk_size must be an integer in 1..1,000,000')
    # Context manager closes the reader even when iteration raises or ends early.
    with pd.read_csv(path, names=COLUMNS, header=None, skipinitialspace=True,
                     na_values='?', chunksize=chunk_size) as reader:
        for frame in reader:
            yield validate_frame(frame)

# %% Array boundary and mergeable online state
def numeric_matrix(frame: pd.DataFrame, columns: tuple[str, ...] = NUMERIC) -> np.ndarray:
    if not columns or len(set(columns)) != len(columns):
        raise ValueError('Need unique ordered feature names')
    matrix = np.array(frame.loc[:, list(columns)].to_numpy(dtype=np.float64, na_value=np.nan),
                      dtype=np.float64, copy=True, order='C')
    if matrix.ndim != 2 or matrix.shape[1] != len(columns) or np.isinf(matrix).any():
        raise ValueError('Invalid numeric matrix')
    # Missing numeric values remain NaN for this audit; no global imputation.
    return matrix

@dataclass
class OnlineMoments:
    count: int = 0
    mean: float = 0.0
    m2: float = 0.0

    def update(self, values: np.ndarray) -> None:
        values = np.asarray(values, dtype=np.float64)
        if values.ndim != 1 or not np.isfinite(values).all():
            raise ValueError('Expected a finite one-dimensional observed batch')
        if values.size == 0:
            return
        batch_count = int(values.size)
        batch_mean = float(values.mean())
        centered = values - batch_mean
        batch_m2 = float(centered @ centered)
        total = self.count + batch_count
        delta = batch_mean - self.mean
        new_mean = self.mean + delta * (batch_count / total)
        new_m2 = self.m2 + batch_m2 + delta * delta * (self.count / total) * batch_count
        if not np.isfinite([new_mean, new_m2]).all():
            raise ValueError('Moment calculation overflow; state was not updated')
        self.count, self.mean, self.m2 = total, new_mean, new_m2

    def summary(self) -> dict:
        return {'observed': self.count, 'mean': self.mean if self.count else None,
                'population_variance': self.m2 / self.count if self.count else None}

def attach_audit_counts(rows: pd.DataFrame, lookup: pd.DataFrame) -> pd.DataFrame:
    if rows['source_row'].duplicated().any() or rows['workclass'].isna().any() or lookup['workclass'].isna().any():
        raise ValueError('Need unique source positions and explicit missing-key sentinel')
    joined = rows.merge(lookup, on='workclass', how='left', sort=False,
                        validate='many_to_one', indicator=True)
    if (len(joined) != len(rows) or joined['source_row'].tolist() != rows['source_row'].tolist()
        or not joined['_merge'].eq('both').all()):
        raise ValueError('Merge changed row identity or lookup coverage')
    return joined.drop(columns='_merge')

# %% Bounded chunk audit, with a deliberately bounded inspection sample
def audit_file(path: Path, chunk_size: int = 1024) -> dict:
    source_hash = sha256_file(path)
    if source_hash != EXPECTED_SHA256:
        raise ValueError('This reproducibility workflow expects the original bundled adult.data')
    moments = {name: OnlineMoments() for name in NUMERIC}
    labels, missing, workclasses = Counter(), Counter(), Counter()
    rows = chunks = max_rows = max_payload = 0
    sample_parts = []
    sample_count = 0
    for frame in iter_validated_chunks(path, chunk_size):
        matrix = numeric_matrix(frame)
        for j, name in enumerate(NUMERIC):
            observed = matrix[:, j]
            moments[name].update(observed[~np.isnan(observed)])
        labels.update(frame['income'].value_counts().to_dict())
        missing.update(frame.isna().sum().to_dict())
        normalized_key = frame['workclass'].astype('string').fillna('__MISSING__')
        workclasses.update(normalized_key.value_counts().to_dict())
        # Retain at most 12 audit-only records, not every chunk.
        if sample_count < 12:
            take = min(12 - sample_count, len(frame))
            sample = pd.DataFrame({'source_row': np.arange(rows, rows + take),
                                   'workclass': normalized_key.iloc[:take].to_numpy()})
            sample_parts.append(sample)
            sample_count += take
        rows += len(frame)
        chunks += 1
        max_rows = max(max_rows, len(frame))
        max_payload = max(max_payload, matrix.nbytes)
    if rows == 0:
        raise ValueError('No validated records')
    inspection = pd.concat(sample_parts, ignore_index=True)
    lookup = pd.DataFrame({'workclass': list(workclasses), 'source_count': list(workclasses.values())})
    joined = attach_audit_counts(inspection, lookup)
    # Counter cardinality can grow with category vocabulary; this is not a claim
    # that arbitrary high-cardinality inputs use constant total process memory.
    return {'source': 'UCI Adult, Becker & Kohavi (1996), CC BY 4.0',
        'scope': 'adult.data audit only; no model fitting or external-test evaluation',
        'sha256': source_hash, 'rows': rows, 'chunks': chunks, 'chunk_size': chunk_size,
        'source_row_range': [0, rows - 1], 'labels': dict(sorted(labels.items())),
        'missing': dict(sorted(missing.items())),
        'numeric': {name: state.summary() for name, state in moments.items()},
        'numeric_feature_order': list(NUMERIC), 'numeric_dtype': 'float64',
        'max_matrix_rows': max_rows, 'max_matrix_payload_bytes': max_payload,
        'retained_inspection_rows': len(joined), 'workclass_lookup_keys': len(lookup),
        'versions': {'python': platform.python_version(), 'numpy': np.__version__, 'pandas': pd.__version__}}

# %% CLI: no work on import, explicit output and atomic replacement
def main(argv: list[str] | None = None) -> dict:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--chunk-size', type=int, default=1024)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args(argv)
    report = audit_file(DATA / 'adult.data', args.chunk_size)
    rendered = json.dumps(report, indent=2, sort_keys=True, allow_nan=False)
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_name(args.output.name + '.tmp')
        temporary.write_text(rendered + '\n', encoding='utf-8')
        temporary.replace(args.output)
    print(rendered)
    return report

if __name__ == '__main__':
    main()
