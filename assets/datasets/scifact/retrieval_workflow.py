"""Offline SciFact retrieval: fixed lexical/LSA recipe, no neural/pretrained claim.

Ordinary runs never rewrite bundled assets. Explicit --write-labs exports a new
versioned index. Query metadata (including evidence labels) is never a feature.
"""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import math
import re
import numpy as np
import scipy
import sklearn
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.decomposition import TruncatedSVD
from threadpoolctl import threadpool_limits

HERE = Path(__file__).resolve().parent
RECIPE = {'vocabulary_cap': 4096, 'min_df': 2, 'dimensions': 32, 'seed': 23,
          'svd_iterations': 7, 'rrf_constant': 60, 'candidate_depth': 100,
          'tokenizer': '[A-Za-z0-9]+ then ASCII lowercase',
          'tf': '1+ln(count)', 'idf': '1+ln((N+1)/(df+1))',
          'normalization': 'L2 TF-IDF; L2 projected LSA; zero stays zero',
          'corpus_fit': 'All5183 unlabeled title+space+abstract documents; no query/qrel fitting',
          'tie_break': 'numeric document ID ascending',
          'lexical_candidates': 'strictly positive dot scores',
          'dense_candidates': 'all nonzero document vectors if nonzero query vector'}


def tokens(text):
    if not isinstance(text, str):
        raise ValueError('Text must be a string')
    return [x.lower() for x in re.findall(r'[A-Za-z0-9]+', text)]


def unit(vector):
    x = np.asarray(vector, dtype=np.float64)
    if x.ndim != 1 or not len(x) or not np.isfinite(x).all():
        raise ValueError('Finite nonempty vector')
    n = np.linalg.norm(x)
    return x / n if n > 0 else x.copy()


def cosine(a, b):
    a, b = unit(a), unit(b)
    if a.shape != b.shape:
        raise ValueError('Same dimension')
    return float(a @ b)


def read_data(root=HERE):
    root = Path(root)
    manifest = json.loads((root / 'source_manifest.json').read_text())
    for name, meta in manifest['files'].items():
        raw = (root / name).read_bytes()
        if len(raw) != meta['bytes'] or hashlib.sha256(raw).hexdigest() != meta['sha256']:
            raise ValueError('Original source bytes changed: ' + name)
    def rows(name):
        return [json.loads(s) for s in (root / name).read_text(encoding='utf-8').splitlines()]
    docs = sorted(rows('corpus.jsonl'), key=lambda d: int(d['_id']))
    queries = {q['_id']: q['text'] for q in rows('queries.jsonl')}
    roles = {}
    for role in ['train', 'test']:
        labels = {}
        with (root / (role + '.tsv')).open(encoding='utf-8', newline='') as f:
            for row in csv.DictReader(f, delimiter='\t'):
                if int(row['score']) > 0:
                    labels.setdefault(row['query-id'], {})[row['corpus-id']] = int(row['score'])
        roles[role] = labels
    assert len(docs) == 5183 and len(queries) == 1109
    assert len({d['_id'] for d in docs}) == len(docs)
    assert not (roles['train'].keys() & roles['test'].keys())
    assert all(q in queries for labels in roles.values() for q in labels)
    ids = {d['_id'] for d in docs}
    assert all(d in ids for labels in roles.values() for rel in labels.values() for d in rel)
    return docs, queries, roles


def rank(ids, scores, k, eligible=None):
    values = np.asarray(scores, dtype=np.float64)
    if values.shape != (len(ids),) or not np.isfinite(values).all():
        raise ValueError('Aligned finite scores')
    if isinstance(k, bool) or not isinstance(k, int) or k < 1:
        raise ValueError('Positive integer cutoff')
    indices = range(len(ids)) if eligible is None else eligible
    return [(ids[i], float(values[i])) for i in sorted(indices, key=lambda i: (-values[i], int(ids[i])))[:k]]


def fuse(lists, k=60):
    if isinstance(k, bool) or not isinstance(k, int) or k < 1:
        raise ValueError('Positive integer RRF constant')
    scores = {}
    for items in lists:
        if len({d for d, _ in items}) != len(items):
            raise ValueError('Duplicate candidate ID')
        for position, (doc, _) in enumerate(items, 1):
            scores[doc] = scores.get(doc, 0.) + 1. / (k + position)
    return sorted(scores.items(), key=lambda p: (-p[1], int(p[0])))


def metrics(ranking, relevant, k):
    if isinstance(k, bool) or not isinstance(k, int) or k < 1:
        raise ValueError('Positive integer cutoff')
    ids = [x[0] if isinstance(x, tuple) else x for x in ranking]
    if not relevant or len(set(ids)) != len(ids):
        raise ValueError('Nonempty binary judgments and unique ranked IDs')
    hits = [i for i, doc in enumerate(ids[:k], 1) if doc in relevant]
    dcg = sum(1. / math.log2(i + 1) for i in hits)
    ideal = sum(1. / math.log2(i + 1) for i in range(1, min(k, len(relevant)) + 1))
    return {'recall': len(hits) / len(relevant),
            'mrr': 1. / hits[0] if hits else 0., 'ndcg': dcg / ideal}


class RetrievalIndex:
    def __init__(self, docs, vectorizer, svd, sparse, dense):
        self.docs, self.vectorizer, self.svd = docs, vectorizer, svd
        self.ids = [d['_id'] for d in docs]
        self.sparse, self.dense = sparse.tocsr(), dense
        self.nonzero = np.flatnonzero(np.linalg.norm(dense, axis=1) > 0)

    def encode(self, text):
        sparse = self.vectorizer.transform([text]).tocsr()
        raw = self.svd.transform(sparse)[0]
        return sparse, raw, unit(raw)

    def search(self, text, method='hybrid', k=10, depth=100, allowed=None):
        if method not in ['tfidf', 'lsa', 'hybrid']:
            raise ValueError('Known retrieval method')
        if isinstance(depth, bool) or not isinstance(depth, int) or not 1 <= depth <= 5183:
            raise ValueError('Candidate depth1..5183')
        if isinstance(k, bool) or not isinstance(k, int) or not 1 <= k <= 5183:
            raise ValueError('Cutoff1..5183')
        x, raw, q = self.encode(text)
        sparse_scores = (self.sparse @ x.T).toarray().ravel()
        dense_scores = self.dense @ q
        eligible = set(self.ids) if allowed is None else set(allowed)
        if not eligible <= set(self.ids):
            raise ValueError('Known filter document IDs')
        lexical = rank(self.ids, sparse_scores, max(k, depth),
                       [i for i, doc in enumerate(self.ids) if doc in eligible and sparse_scores[i] > 0])
        dense = rank(self.ids, dense_scores, max(k, depth),
                     [i for i in self.nonzero if self.ids[i] in eligible]) if np.linalg.norm(q) else []
        return {'tfidf': lexical[:k], 'lsa': dense[:k],
                'hybrid': fuse([lexical[:depth], dense[:depth]])[:k]}[method]

    def export(self):
        features = self.vectorizer.get_feature_names_out().tolist()
        return {'schema_version': 1, 'recipe': RECIPE, 'vocabulary': features,
                'idf': self.vectorizer.idf_.tolist(), 'components': self.svd.components_.tolist(),
                'documents': [{'id': doc, 'indices': self.sparse[i].indices.tolist(),
                               'values': self.sparse[i].data.tolist(), 'dense': self.dense[i].tolist()}
                              for i, doc in enumerate(self.ids)]}


def fit_index(docs):
    vectorizer = TfidfVectorizer(tokenizer=tokens, token_pattern=None, lowercase=False,
                                 max_features=4096, min_df=2, sublinear_tf=True,
                                 smooth_idf=True, norm='l2', dtype=np.float64)
    sparse = vectorizer.fit_transform([d['title'] + ' ' + d['text'] for d in docs])
    svd = TruncatedSVD(n_components=32, algorithm='randomized', n_iter=7, random_state=23)
    # Thread limit context restores the caller's configuration. No global RNG seed mutation.
    with threadpool_limits(limits=1):
        svd.fit(sparse)
    raw = svd.transform(sparse)
    norms = np.linalg.norm(raw, axis=1, keepdims=True)
    dense = np.divide(raw, norms, out=np.zeros_like(raw), where=norms > 0)
    return RetrievalIndex(docs, vectorizer, svd, sparse, dense)


def evaluate(index, queries, roles):
    report = {}
    # Query labels only enter metrics, never vectorizer/SVD/ranking.
    with threadpool_limits(limits=1):
        for role, labels in roles.items():
            report[role] = {'queries': len(labels), 'qrel_pairs': sum(map(len, labels.values())), 'methods': {}}
            for method in ['tfidf', 'lsa', 'hybrid']:
                accum = {str(k): [] for k in [5, 10]}
                for qid in sorted(labels, key=int):
                    result = index.search(queries[qid], method)
                    for k in [5, 10]:
                        accum[str(k)].append(metrics(result, labels[qid], k))
                report[role]['methods'][method] = {
                    k: {name: float(np.mean([r[name] for r in rows])) for name in ['recall', 'mrr', 'ndcg']}
                    for k, rows in accum.items()}
    return report


def workflow(root=HERE, output=None, artifact_dir=None, write_labs=False):
    root = Path(root)
    docs, queries, roles = read_data(root)
    index = fit_index(docs)
    report = {'source': 'SciFact in BEIR', 'documents': len(docs), 'query_texts': len(queries),
              'versions': {'numpy': np.__version__, 'scipy': scipy.__version__, 'sklearn': sklearn.__version__},
              'recipe': RECIPE, 'vocabulary': len(index.vectorizer.vocabulary_),
              'explained_variance_ratio_sum': float(index.svd.explained_variance_ratio_.sum()),
              'evaluation': evaluate(index, queries, roles),
              'limits': ['Fixed corpus-fitted lexical/LSA pipeline,not a pretrained neural semantic encoder.',
                         'BEIR train qrels are diagnostic only; no validation selection or parameter search.',
                         'BEIR test is terminal for this fixed recipe,not original hidden SciFact leaderboard test.',
                         'Qrels denote evidence-document relevance,not support/refute truth or complete relevance.',
                         'Unjudged docs treated as nonrelevant; related claims/shared evidence limit independence.',
                         'No Bangla/domain generalization,medical QA,ANN speed,latency or factuality claim.',
                         'Published test now observed; reruns are reproducibility audits.']}
    samples = []
    with threadpool_limits(limits=1):
        for role, ids in [('train', ['0', '2', '4']), ('test', ['1', '3', '5'])]:
            for qid in ids:
                sparse, raw, dense = index.encode(queries[qid])
                samples.append({'id': qid, 'role': role, 'text': queries[qid],
                                'relevant': sorted(roles[role][qid], key=int),
                                'sparse': {'indices': sparse.indices.tolist(), 'values': sparse.data.tolist()},
                                'raw': raw.tolist(), 'unit': dense.tolist(),
                                'rankings': {m: index.search(queries[qid], m) for m in ['tfidf', 'lsa', 'hybrid']},
                                'depth5_hybrid': index.search(queries[qid], 'hybrid', depth=5)})
    lab = {'report': report, 'samples': samples, 'source_manifest_sha256': hashlib.sha256((root/'source_manifest.json').read_bytes()).hexdigest()}
    exported = index.export()
    if write_labs:
        (root/'retrieval_index.json').write_text(json.dumps(exported, separators=(',', ':'))+'\n', encoding='utf-8')
        (root/'retrieval_lab.json').write_text(json.dumps(lab, indent=2)+'\n', encoding='utf-8')
    if output:
        target = Path(output);target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    if artifact_dir:
        dest = Path(artifact_dir);dest.mkdir(parents=True, exist_ok=True)
        for name, obj in [('index.json', exported), ('golden.json', lab), ('model_card.json', report)]:
            (dest/name).write_text(json.dumps(obj, separators=(',', ':'))+'\n', encoding='utf-8')
        np.savez(dest/'weights.npz', idf=index.vectorizer.idf_, components=index.svd.components_, dense=index.dense)
        checksums = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(dest.iterdir()) if p.is_file() and p.name!='checksums.json'}
        (dest/'checksums.json').write_text(json.dumps(checksums, indent=2)+'\n')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-dir', type=Path, default=HERE)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--artifact-dir', type=Path)
    parser.add_argument('--write-labs', action='store_true')
    args = parser.parse_args()
    print(json.dumps(workflow(args.data_dir, args.output, args.artifact_dir, args.write_labs), indent=2))
