# UCI Spambase · Chapter38

Mark Hopkins,Erik Reeber,George Forman,Jaap Suermondt(1999),Spambase,UCI Machine Learning Repository. https://doi.org/10.24432/C53G6X . Source https://archive.ics.uci.edu/dataset/94/spambase . License CC BY4.0 https://creativecommons.org/licenses/by/4.0/ . Original source documentation retained;derived models/splits/analyses identified separately. Retrieved2026-11-09. No endorsement claimed.

- `spambase.data`: 702942 bytes, SHA256 `b1ef93de71f97714d3d7d4f58fc9f718da7bbc8ac8a150eff2778616a8097b12`
- `spambase.names`: 3566 bytes, SHA256 `df418fab7923f929237b81efa0987ddfaf2d68cf61291243625aadc684d5ab6a`
- `spambase.DOCUMENTATION`: 6429 bytes, SHA256 `462e4ffba1241a5962d528364708d188dc75931d56a25a8e9b6c8bb25e094cfd`

4601 historical emails,57 continuous numeric features followed by binaryspam label. First48 word-frequency features,next6character-frequency features,last3capital-run statistics;exact57field order parsed from original spambase.names and stored in model.fields. No raw mail text,sender identities or timestamps. Dataset contains source-specific indicators(e.g.george/650);no current mailbox/fraud/security performance claim.

Feature-only np.unique axis0 gives4207 exactprofiles. GroupShuffleSplit seeds38(train70%groups)/380(splitremaininggroups50/50) yields3183fit/738validation/680reserved rows. Actual row ratios differ fromgroup targets. Groups disjoint acrossroles;exactduplicate grouping does not solve near-duplicate/sender/time/adversarial leakage. Source row indices are local zero-based ordinals,not source participant IDs.

Train-onlyStandardScaler andfixedC1 lbfgs LogisticRegression,max_iter2000,tol1e-9,random_state38,121iterations. Validation is development,not blindconfirmation. Reserved labels not fitted/scored/exported/used for policy selection;raw publicsource includes labels andsource loader parses all rows,so no physical unaccessed-label claim. Original source files unchanged. Scores uncalibrated;threshold/review presets are teaching policies,not optimal deployment advice. No genuine human review outputs available.

Reference code ../system_design/design_workflow.py;derived model/738validation rows/role indices in ../system_design/design_lab.json. App computes score andpolicies inDart,offline. No new Chapter39 content orGPU/API requirement.
