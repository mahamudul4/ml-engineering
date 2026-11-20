# Bike Sharing: source and attribution

Hadi Fanaee-T (2013), Bike Sharing [Dataset], UCI Machine Learning Repository.
DOI: https://doi.org/10.24432/C5W894
Source: https://archive.ics.uci.edu/dataset/275/bike+sharing+dataset
Archive: https://archive.ics.uci.edu/static/public/275/bike+sharing+dataset.zip
License: CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
Retrieved: November 8, 2026. Original daily observations cover 2011–2012 Capital Bikeshare counts; no invented observations or anomaly labels are added.

`day.csv` and `Readme.txt` are unchanged original archive members. Hourly data is not included or needed.

- day.csv SHA-256: a6bcf826782d3c0fbfdcbeead17cd0884185a0dafe8ff10cd48a874ee7ba18be
- Readme.txt SHA-256: b92c8628622948bf0828c43a1b315d1517c3d7fd63654730d0dea379b8e88175

`temporal_workflow.py` is an import-safe local Chapter 13 audit. It validates the complete 731-day calendar/hash, uses 2011 (365 days) for training and January–June 2012 (182 days) for development. The final 184 outcomes are not used for experiments or derived assets; this is a reserved source segment, not a blind external dataset. The ordinary CLI prints/optionally saves its report. `--write-labs` explicitly regenerates `temporal_lab.json` from actual development observations; the derived asset carries this same attribution and license.

Anomaly models fit only 358 training weekly differences. No verified anomaly labels are available: alerts are model flags, not confirmed incidents or fraud, and no detection accuracy is claimed. Robust MAD, IsolationForest, LOF novelty and OneClassSVM have distinct score/threshold semantics. Ridge lag preprocessing and alpha selection use training-only chronological folds. Forecast features exclude same-day casual/registered components and realized future weather. One-step development evaluation allows earlier observed development outcomes, assuming counts available after day close. Fixed-origin multi-step baselines use only each historical prefix. Separate metrics must not be compared as one protocol. No current-demand, causal or production utility claim is made.


## Chapter19 · causal recurrent sequences

Source attribution remains UCI Bike Sharing, Fanaee-T (2013), CC BY4.0. The original `day.csv` and `Readme.txt` bytes are unchanged. `sequence_workflow.py` reuses the original calendar/hash validator, then confines modeling and reference exports to the first547 daily outcomes:2011 fit365 /351 causal windows; Jan–Jun2012 diagnostic development182. Final184 outcomes afterJune30 are not scored or exported; full archive reads are only source-integrity/schema checks. Previously explored development is not fresh confirmation.

Past14 counts predict the next day under a day-close availability assumption. Mean3405.7616438356163/std1376.8636667749531 use2011 only. CPU float64 GRU1→3 plus Linear3→1 has58 parameters; seed19,Adam.01,80 full-batch updates,gradient norm cap1,zero hidden each window. No model/seed search or future realized weather/count components. Initial RNN(seed20),GRU(seed19 before fitting),LSTM(seed21) are mechanics references, not fitted-model comparisons. GRU rolling development MAE1245.910875 is worse than last-day naive900.604396 and seasonal7 1090.791209; no universal superiority/production claim.

Derived `sequence_lab.json` retains source attribution and hash, actual14-day windows at target indices365/400/540, dates/counts, numeric cell/head parameters, hidden/cell/gate references, training history and diagnostic metrics. Right-padded lengths5/14/9 are explicitly truncated prefixes of actual windows, not missing source observations. Packed valid states match independent sequence execution; dense last-padded states illustrate a bug. Seven-day recursive examples consume predictions after the origin, with historical future truth used only for retrospective inspection; every displayed outcome is no later thanJune30. Rolling one-step metrics refresh earlier observed development outcomes and represent a different protocol.

Ordinary CLI/import leaves source/reference assets unchanged; explicit `--write-labs` regenerates JSON. Optional `--artifact-dir` writes own trusted gru.pt,schema.json,checksums.json. Only load compatible trusted checkpoints. Caller RNG/threads are restored. App computes Dart recurrence from JSON fully offline; Python training runs locally. No API/authentication, downloaded model weights, GPU/iOS/mobile-Torch runtime or causal/current-demand claim.


## Chapter20 · explicit attention and Transformer block

UCI Bike Sharing, Fanaee-T (2013), CC BY4.0 attribution applies to all derived observations. Original source bytes remain unchanged. `attention_workflow.py` reuses source/calendar verification then models/exports only first547 days:2011 fit365/351 windows,Jan–Jun2012 diagnostic182 targets. Final184 outcomes are not scored/exported; integrity checks may read the whole CSV. Development was previously explored in Chapters13/19 and is not fresh confirmation.

Past14 counts known after day close predict the next day, with2011-only count mean3405.7616438356163/std1376.8636667749531. One explicit pre-norm block has input1→4,fixed window-relative sinusoidal positions0..13,two attention heads width2,LayerNorm eps1e-5,FF4→8→4/ReLU,two residuals,scalar head,no final norm/dropout.185 trainable parameters plus56 fixed position-buffer values. CPU float64,seed20,Adam.01,clipping1,80 full351-window updates; no model/rate/seed/epoch search or LLM/token pretraining.

`attention_lab.json` stores numeric weights, actual historical windows at targets365/400/540, retrospective outcomes,15 complete forward references (causal/full×valid14/10 and causal14/no-position),training history and rolling one-step metrics. PyTorch module and independent NumPy forward/SDPA are cross-checked. Valid10 is a declared prefix truncation, not source missing data. Suffix reordering and position/mask toggles are explicit same-weight inference interventions, not separately trained models or observed new daily records. Attention weights are mixing coefficients, not established causal importance. Outcomes displayed in labs never enter their input.

Diagnostic raw-count MAE/RMSE: naive900.604396/1273.461291,seasonal7 1090.791209/1469.171726,Transformer967.508168/1191.254609. MAE is worse than naive and RMSE lower; no universal winner/architecture effect, independent final confirmation, causal/current-demand or production claim. Chapter19 is a different fixed recipe. Main evaluation uses full14 valid steps,positions on,causal attention.

Ordinary import/CLI leaves bundled assets unchanged; explicit `--write-labs` regenerates JSON. `--artifact-dir` writes own trusted transformer.pt,schema.json,checksums.json. External-directory CLI and caller RNG/thread restoration are verified. App computes complete Dart block forward without APIs/authentication/network/model downloads or mobile Python/Torch runtime; local Python training requires development packages. No GPU/iOS/throughput validation.


## Chapter35 · pipeline_workflow.py / pipeline_lab.json

UCI Bike Sharing,Fanaee-T(2013),CC BY4.0 attribution applies. Originalday.csv/Readme.txt bytes/hashes unchanged. Onlyfirst547rows2011-01-01..2012-06-30 parsed forfeatures/exports;reservedlast184outcomes unused. Fullsourcebytes hash isintegrityonly. Oneglobaldailyentity bike-global;no station/user-levelobservations invented. No modeltraining/accuracy/onlinebenefit benchmark.

IMPORTANT:sourcehas NO ingestiontimestamps. on_time/late_fixture availability areexplicitly authored SOFTWARE FIXTURES,not realarrivallogs. Nominaldayindexd,on_time=d+1;late adds3days every17thsourceevent. Counts/dates unchanged. Datearithmeticdoesnot infertrueUTC/timezone/DST/actual networklatency. Historicalprefixalreadyexplored,not freshblindconfirmation.

Features lag1/lag7 exacteventdates,mean7/observed7 fromknownwindow[target-7,target),age_days=target-1-maxknownevent. Bothpasteventandavailable<=asof predicatesrequired. Unknownlag/emptymean/unknownage null;observed0 doesnotmean demand0. Targetcount/casual/registered/realizedtargetweather excluded;casual+registered onlysourcevalidation. Day375 latefixture event374pastbutavailable378,lag1null/observed6/age1.

Two schedules×546targets=1092directbatch/incrementalarrivalprefix/SQLiteconditionalaggregate snapshotsmatch. Availability-ignoringnegativecontrol98late historicalmismatches/33missinglag1;ontime0/0. Not productionlateness/corruptionrate. All8sourcecases (4targets×2scenarios) includerealwindowrows,declaredavailability,correct/latestvectors andretrospectiveoutcome,separatefrominputs.

ActualSQLiteledger keyscenario/event_key,structural/domain/calendar/availability/keychecksfirst. Samepayloadduplicate no-op,conflictingpayload reject.547source rows×2delivery→1094attempts/547stored/547duplicates;plusnegative-countsoftwarecopy→one rejection,still547stored. Per-batchcommit/rollback tested:secondbatchfailureleavesfirst32,fullretry32new/32duplicates. UIreplayDartmap/logicalbatching;PythonactualSQLite. No universaldistributedexactly-once/checkpoint/streaming-throughputclaim.

Snapshots scenario,target,asof,featureversion;backfillretainsoriginalknowledgeboundary. Definition/source/version/availability/entitymetadata guardslookupBEFOREcompute. Samecodecanagreeonbug;independentSQL/scalar/incremental,boundary/null/sourcechecksrequired. Currentimmutableledgerisnot fullmutable/bitemporalcorrectionengine. Offline/onlinefeature-store/TTL/watermark/retention conceptsare designreasoning,not deployedFeast/Kafka/Flink/service.

--artifact-dir exportsfeature_store.sqlite,feature_definition.json,pipeline_lab.json,SOURCE_README.txt(originalbytecopy),ATTRIBUTION.txt,checksums.json. DB1094events/1092snapshots. VerifierfivepayloadSHA256s,definitionmanifestlink,snapshotversion,noticehash,SQLiteintegrity/counts. LogicalparitynotcrossversionSQLitebyteidentity;hashnotauthenticity/qualitycertificate. StandardlibraryPython3.12,arbitrarycwd,no network/GPU. Defaultimport/CLIassetpreserving;--write-lab explicitderivedJSONregeneration. Sourcefullnotice/CCBYcitationpersistinportablebundle.

Primaryreferences: UCI https://archive.ics.uci.edu/dataset/275/bike+sharing+dataset ; Feastconcepts https://github.com/feast-dev/feast/blob/master/docs/getting-started/concepts/point-in-time-joins.md (event-time/knowledgeassumptions,NOTdeployment); SQLite https://www.sqlite.org/lang_transaction.html and https://www.sqlite.org/lang_upsert.html ; Python https://docs.python.org/3/library/sqlite3.html . Originalexplanations,no copiedpaperprose. RootREADMErecordsactualvalidation.


## Chapter36 · serving_workflow.py / serving_lab.json

UCI Bike Sharing, Hadi Fanaee-T(2013), CC BY4.0; original day.csv and Readme.txt hashes unchanged. Only first547 daily counts/dates2011-01-01..2012-06-30 parsed; final184 outcomes excluded from fit/features/diagnostics/export. Full source-file hash is integrity-only. Historical prefix already inspected, not fresh blind confirmation. One global daily entity; no invented users/stations.

Real CPU float64 Ridge fit on358 targets7..364 (2011), features lag1/lag7/mean7 from Chapter35 point-in-time semantics. Training-only mean/std(ddof0), zero-scale guard1, unpenalized intercept3446.0614525139663; fixed alpha10 sum-SSE penalty, no tuning/refit. Serving clips final count>=0, not the fitted objective. Frozen model on182 Jan–Jun2012 rolling one-step targets365..546 under day-close on_time assumption; not fixed-origin182-step forecasting. Target count/casual/registered/weather excluded from inputs. Candidate historical MAE811.4206425/RMSE1083.1730406/bias−199.8012348; naive1 MAE900.6043956, declared seasonal7 baseline1090.7912088. Baseline not strongest assumed model, historical gain not production/causal lift.

IMPORTANT SOFTWARE FIXTURES: original source has no ingestion or label-arrival clocks. Reuses Chapter35 on_time=d+1 and late_fixture=d+1+3when d%17==0; dates/counts unchanged. Maturity labelavailable=target+1+delay0/2/7; clock=periodend+1. Routing key entity+date UTF8 FNV1a32 mod10000, thresholds0/1000/5000/10000; date routing is not user-randomized A/B. On_time10% selects22/182,50%87/182. Late all-candidate171 candidate/11 fallback; rollback182 baseline. Missing Ridge input or candidate contract failure uses independently validated seasonal7. Bad baseline contract blocks before feature computation. All response reasons and model/feature versions traceable; outcomes never returned as inference inputs/results.

Actual input PSI: fit-only unique sorted quintile edges, ties right, .5 perbin smoothing then renormalize. Full lag1 .8822160718, early .3508886238, late2.7904387293; late mean7 3.7807513328. Not calibrated p-value, concept-drift proof, causal attribution or retraining mandate. Early365..455/late456..546,91rows each;full182. Quality same mature subset across candidate/baseline/naive1;delay7 full175labels,early/late84; drift uses all request inputs.

SLO telemetry is AUTHORED20 duration/status rows, NOT measured local HTTP or production logs. Default100ms/99% good16/20, availability.9/composite.8, allowedbad.2/observedbad4/remaining−3.8/burn20x. Exact linear p95all152.5ms/success-only133ms; cumulative≤25/50/100/200 =6/10/16/20,+Inf20. Do not average perinstance p95 or equate histogram interpolation with exact sample quantile. Local rollback replay proves controller routing only, not real recovery or recovery-time SLO.

Optional stdlib ThreadingHTTPServer binds127.0.0.1 only: /healthz,/readyz,/metrics,POST/predict. Strict keys/types/range,4096byte bound, actual request/error/fallback counters; no production serving/performance claim. App never needs this API, authentication or network; Dart/bundled JSON/sqflite remain offline. --bundle verifies release then loads without refit. Default CLI/import preserve assets; --write-lab explicitly regenerates derived JSON. NumPy numeric operations, tested with NumPy2.5.4/Python3.12; no GPU required.

--artifact-dir exports baseline_model.json,ridge_model.json,feature_definition.json,serving_lab.json,SOURCE_README.txt(original bytecopy),ATTRIBUTION.txt plus checksums.json. Six actual payload SHA256s, all model-version/hash/feature-definition/source/schema metadata dependencies, numeric model shape/finite positive scales and exact model/definition crosslinks verified. Tampering rejected; independently trusted expected manifest needed for authenticity. Source/license notice retained. Immutable complete-directory/active-pointer production strategy taught, not distributed registry implemented.

Primary sources: https://archive.ics.uci.edu/dataset/275/bike+sharing+dataset ; https://sre.google/workbook/implementing-slos/ ; https://sre.google/workbook/alerting-on-slos/ ; https://prometheus.io/docs/practices/histograms/ ; https://go.googlesource.com/go/+/refs/heads/release-branch.go1.24/src/hash/fnv/fnv.go ; https://docs.python.org/3/library/http.server.html . Original prose; no copied textbook passages.

Chapter36 maturity clarification: label delay is a conservative scoring/stabilization gate, independent of raw feature arrival. An earlier raw count may be available for subsequent features while the audit waits to accept it as a mature label. It is not a claim that the same count is simultaneously unknown to all consumers; no real arrival/stabilization timestamps are measured.
