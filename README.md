# ML Path — FAANG ML Engineering Offline Companion

**সর্বশেষ সংস্করণ: `2.4.0+54` (Plain Natural Bangla + 43,391 Native LaTeX Equations across All 6 Books & 320 FAANG Viva Hot Questions)।**

- **৬টি স্বতন্ত্র বই (Books 1–6 · ৫০টি Chapter · ৮৮০টি Lesson):** প্রতিটি বই নিজস্ব `Chapter 1` থেকে শুরু হয় — ML Foundations, Classical ML, Deep Learning & RL, LLMs/RAG/GenAI/Interpretability, Recommender Systems & Ads Ranking, এবং ML Systems/MLOps/Interviews। সব ৬টি বইয়ের **৫,১৫৭/৫,১৫৭টি prose block** ও **৪৫৩টি chapter interview** এখন bold bullet points, **২,০১১টি concrete example**, **৬৫৬টি comparison table**, **৬৯৬টি live-verified short Python snippet** এবং native LaTeX equations সহ সহজ, প্রাকৃতিক বাংলায় লেখা। বিস্তারিত রোডম্যাপ: [ROADMAP.md](ROADMAP.md) ও অডিট: [CURRICULUM_AUDIT.md](CURRICULUM_AUDIT.md)।
- **320 High-Frequency FAANG Viva Hot Questions (`Hot Qs` + Flashcard Drill Mode):** Classical ML (60), Deep Learning (60), Transformers & Attention (40), LLMs / Post-Training / RAG / Interpretability (60), Math/Stats (20), Metrics/A-B/Causality (20), GenAI/VLMs/GNNs (20), RecSys/Ads (20), GPU Systems/MLOps/SysDesign (20) — প্রতিটি প্রশ্নে একদম সহজ ও স্বাভাবিক বাংলায় intuition-first ৩০-সেকেন্ডের উত্তর, Bold Breakdown, ধাপে ধাপে Concrete Example, **15,912+ inline/display native LaTeX equations (`0` raw ASCII math)**, Verified Python Snippet (`320/320` passed), Comparison Table এবং Follow-up Trap।
- **120 Deep-ML Style Full-Codebase Coding Problems (`Coding Arena`):** ৮টি ডোমেইন × ১৫টি সমস্যা, ৩৬০টি Think-First প্রশ্ন, আলাদা `Problem & Think` বনাম gated `Solution` Fragment, ৯৯০টি verified Python `assert` tests (মোবাইলে zero Python runtime)।
- **Native LaTeX + Scannable `RichProse` Reader + Natural Bangla:** Inline (`$...$`) ও Display (`$$...$$`) LaTeX equations (`flutter_math_fork`), bold key points, inline code pills, `> **উদাহরণ:**` callouts, inline short Python snippets ও comparison tables সহ প্রাকৃতিক, সহজবোধ্য বাংলায় লেখা এবং সমস্ত Technical Terms ইংরেজিতে রাখা।
- **100% Offline-First Android/Desktop Flutter App:** Authentication, backend বা network লাগে না; Release APK-তে `INTERNET` permission নেই। All-Books Notebook, Mistake/Interview Revision Deck এবং One-Click JSON Backup/Restore সমর্থিত।

**Content ও presentation-এর verdict: public production release-এর জন্য এখনও প্রস্তুত নয়।** নিজের পড়াশোনা ও সীমিত beta ব্যবহারের জন্য ব্যবহারযোগ্য। সব chapter-এর opening ও নির্বাচিত ব্যাখ্যা সম্পাদনা করা হয়েছে; পুরো বইয়ের natural Bangla copy edit, lesson/assessment-এর পূর্ণ review, সাধারণ learner-এর coding setup এবং native iOS review এখনও বাকি। নির্দিষ্ট findings ও প্রকাশের শর্ত [CURRICULUM_AUDIT.md](CURRICULUM_AUDIT.md)-এ আছে।

পুরো curriculum review-এ আগের 40টি chapter-এ 46টি targeted lesson এবং নতুন **Reinforcement Learning & Bandits** chapter-এ 16টি lesson যোগ হয়েছে। Detailed findings ও chapter-specific changes [CURRICULUM_AUDIT.md](CURRICULUM_AUDIT.md)-এ আছে।

14 November 2026-এর Chapter 1–5 revision-এ 74টি explanation/math/code/self-check block, 6টি quiz, 3টি coding exercise ও 2টি interview case যোগ হয়েছে। Grading-এর তিনটি rounded-answer contract ঠিক হয়েছে। নতুন অংশে Lasso soft-thresholding, exposure-সহ Poisson, fitted spline basis, BCE gradient, ROC/AP ও multiclass metrics, preprocessing/OOF trace, nested CV, paired bootstrap এবং bias–variance/uniform-bound derivation আছে। Chapter 1-এর gradient interview থেকে prerequisite lesson সরাসরি খোলা যায়।

Chapter 2-তে bundled Diabetes data দিয়ে development CV comparison, validation diagnostics ও residual plot আছে। Python walkthrough চালাতে `python -m pip install -r tool/requirements-python-qa.txt` ব্যবহার করুন। এতে matplotlib-সহ local Python dependencies আছে। QA command `python tool/check_foundation_revision.py` নতুন examples ও প্রথম পাঁচ chapter-এর exercise solutions যাচাই করে। পড়া ও practice মিলিয়ে expanded lesson-গুলোর সময় আনুমানিক দেওয়া হয়েছে।

## কীভাবে বইটি পড়বেন

Learn page-এর **সম্পূর্ণ বই ও prerequisites** খুলে Reading step অনুসরণ করুন। Chapter number স্থায়ী পরিচয়; reading order আলাদা। শুরু করুন **1 → 6 → 7 → 8 → 4 → 2 → 3 → 5** দিয়ে। এতে advanced regression/classification-এর আগে Python, Linear Algebra/Calculus, Probability/Statistics ও data preparation পড়া হয়।

Chapter41-এর স্থায়ী number নতুন হলেও বইয়ে এটি Deep Learning Capstone-এর পরে, LLM-এর আগে। পরে Chapter25-এর preference alignment ও Chapter33-এর bandit feedback evaluation-এ এর ধারণা ব্যবহার হয়। শেষ reading step Chapter40-এর final synthesis।

প্রতি chapter-এ intuition → mathematics → worked example → commented code → practice → interview defense অনুসরণ করুন। নতুন self-check-এর **Solution প্রথমে বন্ধ থাকে**; নিজের উত্তর লিখে তারপর খুলুন। Book page-এর full-text search দিয়ে সব chapter-এর prose/code খুঁজে সরাসরি matching lesson খুলতে পারবেন। Notation guide-ও সেখানেই আছে।

App-এর coding scratchpad **Python execute করে না**। Draft, numeric result ও reference solution সংরক্ষণ/দেখায়। Numeric acceptance এখন `absoluteTolerance + relativeTolerance × |expected|`; defaults `1e-9` ও `1e-6`। Exercise JSON-এ দুটো override করা যায়, exact count-এর জন্য দুটোই0 দেওয়া যায়। যথেষ্ট precision-সহ output দিন। পুরোনো Solved records reset করা হয়নি; আগের numeric check program correctness প্রমাণ করে না। Python walkthrough স্থানীয় Python environment-এ চালাতে হবে। Bundled source data থাকলে chapter workflows runtime-এ network ছাড়াই চলে; development dependencies আগে install করতে হবে। Mathematical fixtures ও simulated MDP real-data benchmark হিসেবে দেখানো হয়নি।

## Run ও verify

### প্রথম Python practice চালানো

Walkthrough চালানোর জন্য `README.md`, `tool/` ও `assets/`-সহ project folder নিন। `assets/datasets/`-এ companion files, datasets ও source notices আছে। Python command চালানোর সময় terminal-এর working directory হবে এই project folder। App-এর lesson থেকে Python code copy করে নিজের `.py` file-এ রাখুন।

Windows PowerShell-এ Python 3.12 environment তৈরি করে dependencies install করুন। নিচের commands সরাসরি environment-এর Python ব্যবহার করে। [Python venv documentation](https://docs.python.org/3.12/library/venv.html)

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r tool/requirements-python-qa.txt
```

macOS/Linux-এ একই কাজের commands নিচে দেওয়া হলো।

```sh
python3.12 -m venv .venv
.venv/bin/python -m pip install -r tool/requirements-python-qa.txt
```

প্রথমে `my_return.py` নামে একটি file তৈরি করে এই ছোট exercise লিখুন।

```python
def discounted_return(rewards, gamma):
    value = 0.0
    for reward in reversed(rewards):
        value = reward + gamma * value
    return value


print(discounted_return([1, 2, 3], 0.5))
```

Windows-এ `.\.venv\Scripts\python.exe my_return.py`, macOS/Linux-এ `.venv/bin/python my_return.py` চালালে `2.75` পাবেন। এবার rewards বা gamma বদলে আগে নিজের expected result লিখুন, তারপর code চালিয়ে মেলান। App-এর scratchpad-এ code draft ও numeric result রাখুন। নিজের script ও test cases project-এর source data থেকে আলাদা file-এ সংরক্ষণ করুন।

PyTorch-নির্ভর walkthrough-এর জন্য নিজের OS অনুযায়ী official selector থেকে CPU installation command নিন এবং ওই environment-এর `python -m pip` দিয়ে চালান। এই বইয়ের ছোট autograd examples CPU-তে চলে। Setup-এর package downloads-এর পরে bundled datasets দিয়ে practice offline-এ করা যায়। [PyTorch local installation](https://pytorch.org/get-started/locally/)

`ModuleNotFoundError` এলে script চালানো Python-এর environment-এ dependency install হয়েছে কি না দেখুন। `FileNotFoundError` এলে terminal-এ project root এবং সম্পূর্ণ `assets/datasets/` folder আছে কি না যাচাই করুন। প্রথম পাঁচ chapter-এর worked examples ও solutions মেলাতে environment-এর Python দিয়ে `tool/check_foundation_revision.py` চালান।

Chapter 6–40-এর content checks পাঁচ chapter-এর batch ধরে চালানো যায়। Chapter 41-এর জন্য start ও end দুটোই 41 দিন। Python numerical checks-এর dependencies `tool/requirements-python-qa.txt`-এ আছে। Chapter 15–35 ও 41-এর batch checks এবং Chapter 39-এর autograd walkthrough-এর জন্য local PyTorch প্রয়োজন। এখানে PyTorch 2.15.0+cpu ব্যবহৃত। Chapter 36–40-এর numerical examples ও exercise checks NumPy/SciPy-সহ স্থানীয় CPU environment-এ চলে।

```sh
python tool/check_chapter_content_revision.py --start-chapter 6
python tool/check_chapter_content_revision.py --start-chapter 11
python tool/check_chapter_content_revision.py --start-chapter 16
python tool/check_chapter_content_revision.py --start-chapter 21
python tool/check_chapter_content_revision.py --start-chapter 26
python tool/check_chapter_content_revision.py --start-chapter 31
python tool/check_chapter_content_revision.py --start-chapter 36
python tool/check_chapter_content_revision.py --start-chapter 41 --end-chapter 41
python tool/check_book_revision.py --fonts
flutter test test/content_math_presentation_test.dart
```

Flutter3.47.9 / Dart3.13.7 ব্যবহৃত। Android SDK লাগবে; iOS build/validation-এর জন্য macOS/Xcode প্রয়োজন।

```sh
flutter pub get
flutter run
flutter analyze
flutter test --concurrency=2
python tool/check_book_revision.py
flutter build apk --release
python tool/check_book_revision.py --fonts --package
```

শেষ command-এর `--fonts` option-এর জন্য fontTools এবং `--package`-এর জন্য Android build-tools প্রয়োজন। Python numerical examples-এর নতুন audit standard library দিয়েই চলে। রিপোর্ট: `build/book-code-verification.json`; Flutter ও device logs: `build/book-*.log`।

Android device workflow test:

```sh
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/book_revision_test.dart -d YOUR_DEVICE_ID
python tool/check_offline_android.py emulator-5556 --settle-seconds 30
```

শুধু নিজস্ব QA device ব্যবহার করুন। Offline checker-এর জন্য চলমান QA emulator-এর serial দিন; এটি physical device গ্রহণ করে না। Integration test একটি আলাদা SQLite database ব্যবহার করে; app-এর মূল `ml_path.db` মুছে না। Offline check শেষ হলে connectivity ফিরিয়ে দেয়।

## 15 November release-এর validation

15 November-এর full Flutter run-এ 795টি test pass করেছে। শেষ book/math-focused run-এ 21টি test pass, যা full run-এর সঙ্গে overlap করে। সব 381টি exercise solution-এর Python checks pass। আটটি numerical revision group-এ 148টি নতুন example ও 103টি feedback precision check pass করেছে। পুরো বইয়ের 795টি equation parse হয়েছে। 42টি width/text-scale widget case এবং font coverage checks pass করেছে।

Logs `build/remaining-final-full-flutter.log`, `build/remaining-final-book-checks.log`, `build/all-content-revisions-validation.json` ও `build/remaining-compatibility-final.log`।

`1.41.0+44`-এর 183টি bundled file তখনকার source-এর সঙ্গে byte-matched; missing font glyph 0। Android emulator-এ book navigation/search, Bellman lab, quiz feedback, learner-record persistence এবং font scale 1.6-এ equations, prerequisite navigation ও চারটি numeric-answer case pass করেছে। Native workflows debug-mode test harness-এ চালানো হয়েছিল; এরপর release APK দিয়ে airplane-mode cold launch ও loaded Home যাচাই হয়েছিল। এই build-এর evidence `build/final-release-verification.json`-এ আছে।

## Chapter 1–5 build-এর validation

Full Flutter suite795 pass। Chapter1–5, grading ও persistence-এর focused run120 pass। শেষ feedback-সম্পাদনার পরে rendering/assessment/layout run21 pass। Counts overlap। Analyzer clean।763টি equation parse হয়েছে এবং42টি width/text-scale layout case pass করেছে। Android font scale1.6-এ নতুন explanations, prerequisite navigation, তিনটি rounded result ও database reopen যাচাই হয়েছে। Python checker12টি example/plot ও25টি exercise solution চালিয়েছে।

প্রথম full run-এ পুরোনো quiz count ধরে রাখা তিনটি assertion পাওয়া যায়। নতুন content counts অনুযায়ী সেগুলো সংশোধনের পরে সম্পূর্ণ suite আবার pass করেছে। Final feedback-এর21টি test পরের copy changes যাচাই করে। Logs `build/foundation-*.log`; consolidated evidence `build/foundation-release-verification.json`।

তৎকালীন APK `1.40.2+43`-এর183টি bundled file সেই revision-এর source-এর সঙ্গে byte-matched ছিল। Airplane-mode cold launch-এ loaded Chapter1 Home দেখা হয়েছিল। এই অংশের counts ও logs আগের build-এর historical evidence; বর্তমান APK উপরে দেওয়া আছে।

## আগের editorial build-এর validation

Full regression792 pass; শেষ rendering/layout/assessment run8 pass (overlapping checks)।756টি equation parse হয়েছে; সাতটি page-এর42টি width/text-scale case pass করেছে। এগুলো পুরো বইয়ের ভাষা, সব mathematical claim বা সব screen-এর accessibility approval নয়। Current-build evidence ও বাকি কাজ [audit](CURRICULUM_AUDIT.md)-এ আছে। APK: `build/app/outputs/flutter-apk/app-release.apk`।

Final analyzer clean; Android native large-text workflow pass।183টি bundled file byte-matched, missing font glyph0। Full suite-এর পরে শেষ typography/scrollbar পরিবর্তনে affected tests আবার চালানো হয়েছে। Consolidated evidence: `build/editorial-review.json`; পুরোনো `build/book-validation.json` আগের build-এর historical record।

Final beta APK-এর airplane-mode cold launch ও loaded Home screenshot যাচাই হয়েছে; QA device-এর connectivity আগের অবস্থায় ফিরিয়ে দেওয়া হয়েছে।

## Offline storage ও updates

SQLite-এ chapters, completed lessons, bookmarks, notes, quiz answers, coding drafts ও settings থাকে। App startup-এ bundled content refresh হয়; learner tables replace হয় না। Chapter/lesson/question/exercise IDs স্থায়ী। Reading order পরিবর্তনে IDs renumber করা হয়নি। নতুন lessons যোগ হওয়ায় completion percentage কমতে পারে; পুরোনো completed flags হারায় না।

Light/dark theme, responsive layout, chapter navigation, LaTeX ও Python syntax highlighting আছে। Interactive labs কেবল documented inputs পরিবর্তন করে; frozen experiment result-কে নতুন training run বলা হয় না। RL lab-এর synchronous Bellman sweep, terminal state ও convergence bound একটি specified finite MDP-এর জন্য।

## Project structure

- `assets/content/`: modular chapter JSON; `catalog.json` chapter registration; প্রতিটি chapter-এর `book` metadata prerequisites, order, outcomes ও recall prompts রাখে।
- `assets/datasets/`: original sources, licenses, frozen evidence ও runnable Python helpers।
- `lib/models/`: content models; `lib/data/`: SQLite repository; `lib/state/`: learning controller।
- `lib/features/`: topic labs, lesson renderer, practice ও book navigation।
- `test/`: numerical/model, persistence ও responsive widget tests; `integration_test/`: Android device workflows।
- `tool/check_book_revision.py`: catalog/IDs/prerequisites, new examples, original-code AST compatibility, unchanged source bytes ও optional package/font verification।
- `tool/book_revision_spec.json`: explicit reading path ও new-example expected outputs; `tool/book_revision_compatibility.json`: pre-revision IDs/answers/AST/data hashes।

নতুন সাধারণ block types: `text`, `math`, `code`, `checkpoint`। `checkpoint`-এ `body`, `solution`, `reference` থাকে। Topic labs dedicated types দিয়ে render হয়; RL-এর type `bellman_lab`। Future chapter যোগ করলে stable ID, reading order, acyclic prerequisites, outcomes, examples, assessments ও tests একসঙ্গে দিন।

## Sources, scope ও limitations

UCI Adult/Wine/Bike/Spambase, original MovieLens, SciFact/BEIR, public text ও other bundled sources-এর provenance/license files অক্ষত রাখা হয়েছে। MovieLens-এর original research-use terms এবং NSW-এর CC BY-NC2.0 restrictions সহ source-specific conditions মানতে হবে। Source/license text না পড়ে dataset redistributing করবেন না।

আগের frozen results historical evidence; এই revision নতুন reserved outcomes score বা GPU training করেনি। Mathematical example, saved experiment result, planning assumption ও measured production result আলাদা রাখা হয়েছে। iOS native validation Windows-এ করা যায় না। Android APK prototype signing ব্যবহার করে; store distribution-এর signing আলাদা কাজ।

এটি broad ML engineering core ও interview preparation-এর coherent বই। সব research specialization বা চাকরির নিশ্চয়তা নয়। Advanced graph learning, Bayesian computation, distributed training ও domain-specific depth পরের study extensions হতে পারে।

আগের chapter-wise detailed experiment protocols ও numerical reports [CHAPTER_HISTORY.md](CHAPTER_HISTORY.md)-এ সংরক্ষিত। সেখানকার lesson counts ও package versions historical; current reading order/counts এখানে ও app-এ দেখুন।

## Reading path

[ROADMAP.md](ROADMAP.md#পূর্ণ-reading-path)-এ ৯টি Part, তাদের serial, prerequisites ও শেষে করার কাজ দেওয়া আছে। App-এর **Reading Path** ও **Topic Index** দিয়ে একই কাঠামোতে পড়ুন।
