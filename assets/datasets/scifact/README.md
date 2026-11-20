# SciFact retrieval teaching corpus

Source: SciFact, David Wadden, Shanchuan Lin, Kyle Lo, Lucy Lu Wang, Madeleine van Zuylen, Arman Cohan and Hannaneh Hajishirzi, “Fact or Fiction: Verifying Scientific Claims,” EMNLP2020. Retrieval distribution: BEIR, Nandan Thakur et al.,NeurIPS2021.

Upstream:https://github.com/allenai/scifact;distribution:https://github.com/beir-cellar/beir;download:https://public.ukp.informatik.tu-darmstadt.de/thakur/BEIR/datasets/scifact.zip.

Original archive members corpus.jsonl,queries.jsonl,qrels/train.tsv andqrels/test.tsv are retained byte-for-byte (TSVs flattened to train.tsv/test.tsv). Manifest records hashes,byte counts,archive checksum and retrieval date2026-11-09. SOURCE_LICENSE.md is the original upstream notice: claims/annotations CC BY4.0,abstract database ODC-By1.0. Retain attribution and these notices when redistributing source or derived database/index. This records upstream database terms;it does not assert additional rights over individual scholarly publications. Original text is not overwritten by derived tokenization.

5183 original scientific documents;1109 query texts;809 BEIR train judged queries/919 positive pairs;300 BEIR test judged queries/339 positive pairs. Corpus title+space+abstract only enters model fitting. Query metadata,including support/refute evidence labels,is never a feature. Test is BEIR retrieval test,not original hidden SciFact leaderboard test. Claim text may be false;retrieval relevance is not truth,medical advice or automatic scientific verification. English empirical corpus does not validate Bangla retrieval.

Fixed local CPU float64 recipe: ASCII[A-Za-z0-9]+ then lowercase,min_df2,max_features4096,sublinear TF1+ln(count),smooth IDF1+ln((N+1)/(df+1)),L2 normalization;TruncatedSVD32/randomized/n_iter7/seed23 fitted on the available unlabeled indexed corpus;fit then transform,then unit normalize. This LSA representation is not a pretrained neural semantic model. Vocabulary/IDF/SVD never fit query texts or qrels. Unlabeled corpus visibility is a declared deployment assumption. No parameter search,method selection or test retuning.

Exact TF-IDF cosine uses positive-score candidates;exact LSA cosine uses nonzero vectors. OOV/zero query yields no candidates. Ties numeric document ID ascending. Hybrid RRF uses top100 per branch,one-based ranks,constant60,absent0;metadata eligibility precedes ranking. Final k10 is separate. Chunk/int8/neural snippets are labeled demonstrations,not changed benchmark indexes,ANN speed results or neural training.

Terminal BEIR test@10: TF-IDF Recall.625277778,MRR.437910053,nDCG.476622528;LSA Recall.237222222,MRR.105263228,nDCG.130019048;hybrid Recall.462777778,MRR.237318783,nDCG.286545791. The stronger lexical baseline is retained honestly. Macro averages give equal weight to judged queries;unjudged docs count as nonrelevant by evaluation convention. Related claims/shared evidence and incomplete qrels limit independence. Published test now observed;reruns audit reproducibility. No factuality/neural superiority/multilingual/ANN latency/production claim.

Run from any directory with Python dependencies pinned in tool/requirements-pytorch-qa.txt:

```sh
python /absolute/path/retrieval_workflow.py --output /path/report.json --artifact-dir /path/artifacts
```

Ordinary imports/runs preserve assets;explicit --write-labs regenerates retrieval_index.json and retrieval_lab.json. The index contains vocabulary/IDF/components/doc-ID sparse andunit32D vectors;the lab includes six original query traces,18 full top10 rankings,shallow-fusion cases and complete role metrics. Source abstracts are read from original corpus.jsonl for display. Artifacts index.json,golden.json,model_card.json,weights.npz,checksums.json are portable without executable pickle loading. App performs Dart query projection/search offline;full Python fitting andscratchpad execution remain local. User notes/bookmarks/progress use SQLite. No runtime network,API,auth or downloaded model dependency.
