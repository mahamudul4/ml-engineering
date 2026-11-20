# Curriculum ও app audit

## 320 FAANG Viva Questions: Plain Natural Bangla & Full Native LaTeX Rewrite (`2.4.0+54`)

ব্যবহারকারীর সরাসরি ফিডব্যাকের ভিত্তিতে ১৬টি প্যাকের **সব ৩২০টি FAANG Viva Hot Questions (`1,920`টি prose field)** সম্পূর্ণ নতুন করে সহজ, স্বাভাবিক, intuition-first বাংলায় এবং ১০০% native LaTeX সমীকরণে পুনর্লিখন করা হয়েছে:

- **সহজ ও স্বাভাবিক বাংলা ব্যাখ্যা (Zero Banglish Jargon Overload):** প্রতিটি প্রশ্নে সাধারণ ইংরেজি শব্দ বাদ দিয়ে সহজ দৈনন্দিন বাংলায় মূল ধারণাটা আগে পরিষ্কার করা হয়েছে, শুধুমাত্র আসল ML/CS technical terms ইংরেজিতে রেখে (কঠিন term-এর সহজ বাংলা অর্থ পাশে দিয়ে)। ৩২০টি প্রশ্নের প্রতিটিতে Bangla-to-English readability ratio `2.7–5.0` থেকে বেড়ে **`16.5–45.9`** (সর্বনিম্ন `11.72`) হয়েছে — যা Books 1–6-এর সমমানের বা আরও সহজবোধ্য।
- **১০০% Native LaTeX Equations (`0` Raw ASCII Math):** আগের `596`টি ASCII math (`sqrt(d_k)`, `sigma^2`, `||w||_1`, `sum_{...}`) পুরোপুরি সরিয়ে ৩২০টি Viva প্রশ্নের গদ্য, উদাহরণ ও টেবিলে **১৫,৯১২+ inline ও display LaTeX equation** যোগ করা হয়েছে।
- **পূর্ণাঙ্গ স্বয়ংক্রিয় যাচাই:** পুরো অ্যাপ জুড়ে **`43,391 / 43,391` LaTeX equation** `flutter_math_fork`-এ `0` parse error-এ পাস করেছে, এবং নতুন widget regression test দিয়ে সব ৩২০টি Viva প্রশ্নই mobile width (`390x844`, light ও dark mode)-এ `0` render exception সহ যাচাই করা হয়েছে।

## All 6 Books Full Scannable + Native LaTeX Equations Upgrade (`2.3.0+53`)

Milestone B-তে পুরো লাইব্রেরির সব ৬টি বই (Books 1–6 · ৫০টি Chapter) এবং `RichProse` ইঞ্জিনে দুটি বড় আপগ্রেড সম্পন্ন ও যাচাই করা হয়েছে:

1. **Native Inline & Display LaTeX in `RichProse` (`lib/ui/rich_prose.dart`):**
   - `RichProse`-এ `flutter_math_fork` যুক্ত করে গদ্য, বুলেট, কলআউট ও টেবিলের ভেতরে সরাসরি inline (`$...$`) এবং display (`$$...$$`) LaTeX equation রেন্ডারিং যোগ করা হয়েছে — narrow width (`320px`) ও `2.0x` text scale-এ `LayoutBuilder` + `FittedBox(BoxFit.scaleDown)` + `HorizontalReadingView` দিয়ে zero-overflow সুরক্ষাসহ।
   - `test/content_math_presentation_test.dart` এখন dedicated `math` block-এর পাশাপাশি প্রতিটি prose block, callout, checkpoint, interview, coding problem এবং viva question-এর সব `$...$` ও `$$...$$` LaTeX সমীকরণ পার্স করে যাচাই করে।
2. **All 6 Books (50/50 Chapters) Scannable + LaTeX + Natural Bangla Editorial Upgrade:**
   - **Book 1 (5 chapters)**-এর সব basic/ASCII equation LaTeX-এ রূপান্তর এবং **Books 2–6 (45 chapters)**-এর পূর্ণ Scannable + LaTeX + সহজবোধ্য, প্রাকৃতিক বাংলা (English technical terms সহ) সংস্কার সম্পন্ন হয়েছে:
     - **৫,১৫৭ / ৫,১৫৭ (১০০%)** prose/callout block structured (`5,150` bold, **`0` unbroken walls of text**)
     - **২,০১১টি** concrete `> **উদাহরণ:**` example block, **৬৫৬টি** comparison table, **৬৯৬টি** live-executed inline short Python snippet এবং **৪৫৩টি** upgraded chapter interview answer
     - **২৭,১৪২ / ২৭,১৪২ (১০০%)** LaTeX equation (`flutter_math_fork`) `0` parse error-এ পাস, `check_book_revision.py --fonts` পাস (`0` missing glyphs, `760` legacy walkthrough ASTs ও `368` exercise solution ASTs অপরিবর্তিত)।

## Scannable Reader Engine, Book 1 Upgrade ও 320 FAANG Viva Hot Questions (`2.2.0+52`)

মোবাইলে বই পড়ার অভিজ্ঞতাকে আরও ঝরঝরে (`Scannable`) এবং FAANG ভাইভা প্রস্তুতিকে রিপিটেবল করতে এই রিলিজে চারটি বড় আপগ্রেড যুক্ত হয়েছে:

1. **Native Rich Scannable Reader (`lib/ui/rich_prose.dart`):**
   - `LessonPage`, `PracticePage` এবং `CodingProblemPage`-এ `**bold**` key points, `` `inline code` `` pills, indented bullet/numbered lists, `> **উদাহরণ:**` callout cards, inline syntax-highlighted ` ```python ... ``` ` short code snippets এবং scrollable markdown comparison tables যুক্ত হয়েছে — কোনো legacy `block_index` বা AST hash না বদলেই।
2. **320 High-Frequency FAANG Viva & Hot Questions Bank (`assets/viva/01..16_*.json`):**
   - সবচেয়ে বেশি আসা ৪টি হট ডোমেইনেই ২২০টি প্রশ্ন: **Classical ML (60)**, **Deep Learning (60)**, **Transformers & Attention (40)** এবং **LLMs, Post-Training, RAG & Mechanistic Interpretability (60)**; পাশাপাশি **Math, Prob & Stats (20)**, **Metrics, A/B & Causality (20)**, **GenAI, VLMs & GNNs (20)**, **RecSys, Search & Ads (20)** এবং **GPU Systems, MLOps & FAANG Loop (20)**।
   - ৩২০/৩২০টি প্রশ্নেই (`100%`) রয়েছে ৩০-সেকেন্ডের `Elevator Answer`, Bold Bullet `Core Breakdown`, `Concrete Example`, `LaTeX` সমীকরণ, লাইভ-এক্সিকিউটেড **Runnable Python Snippet (320/320 passed)**, `Comparison Table` এবং `FAANG Follow-up Trap`।
   - ডেডিকেটেড `Hot Qs` স্ক্রিনে Topic/Priority/Status filter, instant search, **Viva Flashcard Drill Mode** (আগে উত্তর লুকিয়ে মুখে অনুশীলন -> Reveal -> `Confident` / `Review Again` / `Star`) এবং `ml_path_backup_v1` JSON Backup/Restore সমর্থন যুক্ত হয়েছে।
3. **Book 1 Full Scannable Editorial Upgrade (Milestone A):**
   - `Book 1 · ML Foundations`-এর সব ৫টি অধ্যায়ের (`chapter_01`, `chapter_06`, `chapter_07`, `chapter_08`, `chapter_04`) **৪৪২/৪৪২টি prose block** এবং **৩৭টি interview answer** bold lead-in points, `> **উদাহরণ:**` callout card, comparison table ও live-executed short Python snippet-এ রূপান্তরিত হয়েছে।
4. **Natural Bangla + English Technical Terms Normalization:**
   - Books 2–6 (৪৫টি অধ্যায়)-এর ৩,১৪২টি field, Book 1-এর ৩৮টি metadata/quiz field এবং Coding Arena (১২০ প্রবলেম)-এর ৭০১টি field থেকে অপ্রয়োজনীয় বাংলা transliteration সরিয়ে সব Technical Terms ইংরেজিতে এবং মূল লেখা স্বাভাবিক বাংলায় রাখা হয়েছে।

## Deep-ML Style ML Coding Arena (`2.1.0+51`)

অফলাইন মোবাইল পাঠকদের জন্য Python রানটাইম ব্লোট ছাড়াই কোডবেস-ভিত্তিক গভীর অনুশীলনের জন্য **ML Coding Arena** (`assets/coding/01..08_*.json`) যুক্ত হয়েছে:

- **১২০টি Full-Codebase প্রবলেম (৮টি ডোমেইন × ১৫টি করে):** `Linear Algebra & Math` (15), `Stats & ML Metrics` (15), `Classical ML` (15), `Deep Learning & Optim` (15), `CV & Sequence Models` (15), `LLMs & Transformers` (15), `RAG, RecSys & GNN` (15) এবং `Systems, RL & FAANG` (15) — মোট `Easy: 36`, `Medium: 59`, `Hard: 25`।
- **আলাদা Two-Fragment অভিজ্ঞতা (`Problem & Think` বনাম `Solution`):** প্রতিটি সমস্যার পূর্ণাঙ্গ কোডবেসে (যেমন `DecisionTreeClassifier`, `LassoRegressor`, `TwoLayerMLP`, `MultiHeadAttention`, `LoRALinear`, `KVBlockManager`) মূল টার্গেট ফাংশনটি `# TODO` হিসেবে রাখা হয়েছে; `Problem & Think` ট্যাবে সমীকরণ, উদাহরণ, ওই ফাংশনটি নিয়ে ৩টি ইন্টারঅ্যাক্টিভ **Think-First প্রশ্ন** (মোট ৩৬০টি প্রশ্ন), ধাপে ধাপে `Hints` এবং অফলাইন `Pseudocode Notes` রয়েছে। সম্পূর্ণ আলাদা **`Solution` Fragment**-এ `Think-First Reveal Gate` পেরিয়ে যাচাইকৃত পূর্ণ সমাধান, লাইন-বাই-লাইন বাংলা `Walkthrough`, `Time/Space Complexity` এবং `Edge Cases` দেখা যায়।
- **লাইভ Python, Math ও Font যাচাই:** ১২০টি প্রবলেমের প্রতিটি `solutionCode` ডেভ মেশিনে আসল Python দিয়ে রান করে মোট **৯৯০টি `assert` টেস্ট** পাস করানো হয়েছে; সব ১২০টি `mathFormula` `flutter_math_fork`-এ পার্স হয়েছে, মিসিং ফন্ট গ্লিফ `0`, এবং Coding Arena-র `Solved`, `Starred` ও `Notes` বিদ্যমান SQLite `settings` ও `ml_path_backup_v1` JSON ব্যাকআপে সম্পূর্ণ সমর্থিত।

## Multi-Book Library, ১০০% সাবলীল বাংলা সংস্কার ও FAANG ৫০-অধ্যায় সম্প্রসারণ (`2.0.0+50`)

এই মেজর রিলিজে পুরো অ্যাপ ও পাঠ্যক্রমে চারটি বড় প্রকৌশল ও সম্পাদকীয় আপগ্রেড সম্পন্ন হয়েছে:

1. **৬-বইয়ের স্বতন্ত্র লাইব্রেরি আর্কিটেকচার (`Book 1` থেকে `Book 6`):**
   - আগের একক দীর্ঘ তালিকার বদলে পাঠ্যক্রমকে ৬টি স্বতন্ত্র ডোমেইন বইয়ে ভাগ করা হয়েছে: `ML Foundations` (৫টি অধ্যায়), `Classical Machine Learning` (৯টি অধ্যায়), `Deep Learning & RL` (৯টি অধ্যায়), `LLMs, RAG & Generative AI` (১২টি অধ্যায়), `Recommender Systems` (৬টি অধ্যায়) এবং `ML Systems, MLOps & Interviews` (৯টি অধ্যায়)।
   - প্রতিটি বই নিজস্ব `Chapter 1` থেকে শুরু হয় এবং প্রতিটি বইয়ের আলাদা অগ্রগতি ও সর্বশেষ পঠিত অধ্যায় সংরক্ষিত থাকে। পুরোনো সব স্থায়ী ID (`chapter_01`..`chapter_43`, `lesson.id`, `quiz.id`, `exercise.id`) শতভাগ অক্ষুণ্ণ রাখা হয়েছে যাতে কোনো শিক্ষার্থীর সংরক্ষিত ডেটা না হারায়।
2. **প্রাথমিক ৪৩টি অধ্যায়ের পূর্ণাঙ্গ সাবলীল বাংলা সংস্কার:**
   - আগের আক্ষরিক অনুবাদের বদলে ৪৩টি অধ্যায়ের সব ৫,২৯২টি গদ্য ব্লক, ১,০১০টি `Quiz`, ৩৯৪টি `Coding Exercise` এবং ৪০৫টি `Interview` প্রশ্নোত্তরকে প্রাকৃতিক, ধারাবাহিক বাংলায় পুনর্লিখন করা হয়েছে, যেখানে সমস্ত কারিগরি পরিভাষা (`Tree`, `Leaf`, `Node`, `Impurity`, `Split`, `Gradient`, `Attention` ইত্যাদি) ইংরেজিতেই রাখা হয়েছে।
3. **৭টি নতুন FAANG অধ্যায় (`chapter_44`–`chapter_50`):**
   - **`chapter_44` (`Book 3 · Chapter 9`):** `GPU Systems, 3D Parallelism & LLM Serving` — Roofline Model, FlashAttention-2 Online Softmax, MHA/MQA/GQA KV Cache, DDP বনাম ZeRO/FSDP, Tensor ও Pipeline Parallelism, PagedAttention, Speculative Decoding এবং 70B Capacity Planning।
   - **`chapter_45` (`Book 4 · Chapter 11`):** `Reasoning Post-Training, RLVR & Agentic Systems` — SFT/Preference/RL ধাপসমূহ, PPO বনাম DPO, GRPO, Verifiable Rewards ও Reward Hacking প্রতিরোধ, Test-Time Compute (`Best-of-N`, PRM), Constrained JSON Decoding এবং Agentic Tool Security।
   - **`chapter_46` (`Book 4 · Chapter 12`):** `Multimodal VLMs & Graph Neural Networks` — ViT/SigLIP Patch Tokenization, Cross-modal Connectors, Dynamic AnyRes Document VQA, Multimodal Hallucination Audit এবং GCN, GraphSAGE, GAT, Over-smoothing ও Link Prediction Temporal Leakage।
   - **`chapter_47` (`Book 5 · Chapter 6`):** `Industrial Ads & Feed Ranking: DLRM, DCN-v2 & MMoE` — 4-Stage Retrieval-to-Rerank Funnel SLA, Meta DLRM, Google DCN-v2, DIN/BST Sequence Attention, MMoE/PLE Multi-Task Gating, VCG/First-Price Ads Auction এবং Normalized Cross-Entropy ও Prior Recalibration।
   - **`chapter_48` (`Book 6 · Chapter 7`):** `End-to-End 45-Minute FAANG ML System Design` — ৪৫-মিনিটের হোয়াইটবোর্ড ফ্রেমওয়ার্ক এবং ৬টি পূর্ণাঙ্গ এন্ড-টু-এন্ড কেস (Reels/Shorts Feed, 500k QPS Ads Prediction, Visual/Autocomplete Search, Marketplace ETA, Payment Fraud Integrity ও Permission-Aware Enterprise Multimodal Copilot)।
   - **`chapter_49` (`Book 6 · Chapter 8`):** `Advanced FAANG DSA & From-Scratch ML Coding` — Sliding Window (`exact_k`), Monotonic Deque, Autocomplete Trie, Dijkstra এবং শুধুমাত্র Python/NumPy দিয়ে স্ক্র্যাচ থেকে `K-Means++`, `Batched Causal MHA + Incremental KV Cache`, `Analytical LoRA Backward` ও `Deterministic BPE + Stable Cross-Entropy`।
   - **`chapter_50` (`Book 6 · Chapter 9`):** `FAANG Behavioral, Leadership Principles & L5+ Leveling` — L4 বনাম L5/L6 সিগন্যাল, `STAR + Counterfactual Impact`, Amazon Leadership Principles, SEV-1 Production ML Incident Postmortem, Cross-Team Tradeoff Alignment এবং ৩০-দিনের চূড়ান্ত প্রস্তুতি পরিকল্পনা।
4. **নতুন অফলাইন লার্নিং ও রিভিশন ফিচারসমূহ:**
   - **All-Books Global Notebook & Bookmarks:** ৬টি বই জুড়ে সব নোট ও বুকমার্ক এক জায়গায় দেখা, বই/অধ্যায় অনুযায়ী ফিল্টার এবং তাৎক্ষণিক টেক্সট সার্চ।
   - **FAANG Mistake & Interview Revision Deck:** ভুল হওয়া `Quiz` প্রশ্নগুলোর স্বয়ংক্রিয় কিউ (যেখানে সঠিক উত্তর না দেওয়া পর্যন্ত প্রশ্নটি কিউতে থাকে) এবং যেকোনো অধ্যায়ের `Interview` প্রশ্নে `Star` দিয়ে এক জায়গায় রিভিশন করার সুবিধা।
   - **One-Click JSON Backup & Restore:** SQLite স্কিমা অক্ষুণ্ণ রেখে সম্পূর্ণ অফলাইনে সব `progress`, `quiz_answers`, `exercises` ও `settings` (`ml_path_backup_v1` ফরম্যাটে) Export এবং Restore করার সুবিধা।

**নতুন সামগ্রিক পরিসংখ্যান ও যাচাইকরণ (`2.0.0+50`):**
- **মোট বিষয়বস্তু:** ৬টি বই · ৫০টি Chapter · ৮৮০টি Lesson · ১,০৯২টি Quiz · ৪৩৫টি Coding Exercise · ৪৫৩টি FAANG Interview Case · ১,০৬৮টি পার্স ও যাচাইকৃত Python Code Block।
- **স্বয়ংক্রিয় যাচাই:** `tool/check_book_revision.py --fonts` পাস (`missing font glyphs: 0`), নতুন ৭টি অধ্যায়ের সব ৬০টি কোড ব্লক এবং ৪১টি অনুশীলনীর সমাধান লাইভ Python এক্সিকিউশনে প্রত্যাশিত ফলাফলের সাথে `1e-9` সূক্ষ্মতায় যাচাইকৃত, `flutter analyze` সম্পূর্ণ ত্রুটিমুক্ত এবং পূর্ণ Flutter টেস্ট স্যুট পাস।

## Interview ও advanced LLM expansion — 18 November 2026

পুরোনো ৪১টি chapter-এর IDs ও Part serial রাখা হয়েছে। Part 5-এ **5.6 · Chapter 42, LLM Evaluation & Benchmark Design** এবং **5.7 · Chapter 43, Mechanistic Interpretability for Language Models** যোগ হয়েছে। নতুন দুটি chapter ও পুরোনো আটটি chapter মিলিয়ে ২৮টি lesson, ২০টি feedback quiz, ১৩টি numeric coding exercise এবং ১২টি interview case যোগ হয়েছে। নতুন totals: ৪৩ chapters, ৮২০ lessons, ১,০১০ quizzes, ৩৯৪ exercises ও ৪০৫ interview cases।

- **Chapters 39–40:** Binary tree BFS, Union-Find, backtracking, interval sweep, SQL as-of join, timed MLE/Applied Scientist/LLM engineer mock ও behavioral rehearsal। নিজের অবদান, decision owner, measured result এবং ভুল থেকে কী বদলেছে—এই evidence দিয়ে উত্তর দেওয়ার rubric আছে।
- **অন্যান্য Parts:** Chapter 5-এ threshold/capacity change, Chapter 17-এ DDP/FSDP state ও communication budget, Chapter 41-এ IPS/SNIPS/ESS-সহ support, Chapter 28-এ OCR বনাম reasoning diagnosis, Chapter 32-এ delayed conversion ও multi-objective ranking, Chapter 38-এ peak-load ও stale-feature fallback। GPU budget ও ছোট সংখ্যার examples অনুমান হিসেবে চিহ্নিত; নতুন GPU latency বা scaling measurement করা হয়নি।
- **Chapter 42:** MMLU-Pro/MATH-500, HumanEval+/LiveCodeBench ও pass@k, BFCL/τ-bench, IFEval/RULER, SimpleQA, MMMU/MGSM ও Arena থেকে representative protocols। SWE-bench Verified-এ test scope audit এবং HarmBench-এর refusal measurement আলোচনা আছে। Frozen SciFact rows দিয়ে paired release audit ও app-এ pass@k calculator আছে। কোনো public benchmark suite নতুন করে চালানো হয়নি; Bangla grading-এর example digit normalization দেখায়, multilingual capability score নয়।
- **Chapter 43:** Probe/readout বনাম intervention, activation patching, Jacobian transport, J-space sparse nonnegative geometry ও valence study design। App-এর patch control ও Python contrastive gradient lab bundled Alice decoder-এ চলে। Gradient finite difference-এর সঙ্গে মেলে; এটি full J-lens fit, SAE training বা published valence experiment-এর replication নয়। [J-lens paper](https://arxiv.org/abs/2607.15495), [activation patching methodology](https://arxiv.org/abs/2404.15255), [valence study](https://www.anthropic.com/research/emotion-concepts-function)।

চাকরির নিশ্চয়তা হিসেবে quiz count ব্যবহার করবেন না। [Role-based reading path](ROADMAP.md#interview-practice-এর-পথ) ধরে unseen problem, coding, system design ও behavioral round দিন। Bangla/English free-form human benchmark, multi-GPU measured lab এবং বৃহৎ model-এ interpretability replication ভবিষ্যৎ গভীরতা।

Verification: ২২টি নতুন Python walkthrough ও ১৩টি exercise solution চালিয়ে expected results মিলেছে। ৮১০টি equation parse হয়েছে। Full Flutter run-এ ৭৯০টি pass; content counts বদলানোর পর বাকি আটটি picker assertion সংশোধন করে একই tests পুনরায় pass করেছে। Analyzer clean। APK `1.43.0+46`-এর ১৮৫টি bundled file source-এর সঙ্গে byte-matched; APK signature pass ও INTERNET permission অনুপস্থিত। Logs: `build/interview-expansion-package.log`, `build/interview-expansion-full-tests.log`, `build/interview-expansion-picker-retest.log`, `build/interview-expansion-analyze-final.log`।

Android release QA: airplane mode-এ [নতুন দুই chapter](build/interview-expansion-android/new-llm-chapters.png) দেখা গেছে। [Pass@k lab](build/interview-expansion-android/pass-at-k.png)-এ ০.৭০০ এবং [activation patch lab](build/interview-expansion-android/activation-patch.png)-এ gap −২.৮০৩৩৪৫ থেকে −২.৫৪৮৮৩৬ যাচাই হয়েছে। Dedicated QA emulator ব্যবহার করা হয়েছে; reading emulator-এর app বা learner data বদলানো হয়নি।

## পড়া শুরুর আগে: বইয়ের কাঠামো ও coverage — 18 November 2026

৪১টি chapter এখন ৯টি Part-এ। *LLMs & Retrieval* থেকে *Generative Models & Multimodal AI* আলাদা। 5.1-এর মতো Part serial-এর পাশে পুরোনো Chapter number ও global Step আছে। Topic Index থেকে কোনো Part খুললেও prerequisite links দেখা যায়। Chapter 29 মূল reading path-এ একবারই আছে; LLM Topic Index-এ সেটি related Capstone। Chapter/lesson ID ও পুরোনো chapter-এর আপেক্ষিক order অপরিবর্তিত। নতুন দুই lesson-সহ মোট ৭৯২টি lesson।

**LLM-এর ভিত্তি ও applied কাজ শুরু করার মতো coverage আছে।** Tokenization, Transformer/attention, RoPE, next-token loss, sampling, embeddings, RAG, LoRA/QLoRA, preference alignment, evaluation ও serving আছে। Chapter 26-এ contamination, calibration, abstention, human rubric, judge bias ও serving আগে থেকেই ছিল। নতুন lesson-এ সংরক্ষিত SciFact outputs-এ format, label ও annotated evidence একসঙ্গে এবং আলাদা করে মাপা হয়; ১৮৮টির সব valid হলেও মাত্র ৩৩টিতে label ও সম্পূর্ণ rationale দুটো মেলে। Tiny decoder-এর এই diagnostic থেকে open-ended LLM-এর factuality দাবি করা যাবে না। [LLM judge paper](https://papers.nips.cc/paper_files/paper/2023/hash/91f18a1287b398d378ef22505bf41832-Abstract-Datasets_and_Benchmarks.html)

**Mechanistic Interpretability এখন পরিচিতি ও হাতে করার lab পর্যন্ত আছে।** Chapter 22-এর Alice byte decoder-এর frozen activation, LayerNorm ও output head থেকে logit gap পুনর্গঠন করে FFN output ablation ও patching করা হয়। Logit lens ও SAE-এর সঙ্গে causal intervention-এর পার্থক্য বোঝানো হয়েছে। বৃহৎ pretrained model-এর circuit replication, SAE training ও dataset-scale intervention এখনও নেই। [Activation patching methodology](https://arxiv.org/abs/2404.15255)

পড়া শুরুর আগে নতুন chapter দরকার নেই। পরের content pass-এ এই বিষয়গুলোর গভীরতা সবচেয়ে কাজে লাগবে:

1. **Applied LLM ও evaluation:** human-graded Bangla/English free-form eval set, tool calling ও multi-step task success, এবং version বদলালে end-to-end regression suite। বর্তমান বই rubric শেখায়; পূর্ণ human-labeled মুক্ত উত্তরের benchmark নেই।
2. **LLM serving ও training:** GQA/MQA দিয়ে KV memory হিসাব, speculative decoding, distributed training ও profiling-এর measured lab। Attention, KV cache, queueing ও serving-এর ভিত্তি আছে।
3. **সার্বিক curriculum:** Graph ML/GNN-এর আলাদা পাঠ, advanced Bayesian computation, এবং evaluation-এ subgroup fairness-এর পূর্ণ project। এগুলো specialist extension। SQL-এর প্রাথমিক practice দরকার হলে Chapter 39-এর SQL lessons আগে দেখা যায়।
4. **পড়ার অভিজ্ঞতা:** Foundation থেকে learner walkthrough নিয়ে কোথায় ব্যাখ্যা বা setup আটকে যায় তা দেখা; তারপর sentence-level Bangla edit এগোনো। Targeted content review দিয়ে ৭৯২টি lesson-এর পূর্ণ সম্পাদকীয় যাচাই হয়েছে বলা যায় না।

Source verification: সব ৪১টি chapter-এর Part ও Step, পুরোনো IDs/answers, ৭৯৭টি equation এবং দুই নতুন Python walkthrough যাচাই হয়েছে। Focused Flutter run-এ ৭১টি check pass করে; Topic Index test-এর scroll target ঠিক করার পর ওই নতুন test-টিও আলাদা করে pass করেছে। Analyzer clean। Logs: `build/structured-book-content.log`, `build/structured-book-tests.log`, `build/structured-book-topic.log` ও `build/structured-book-analyze.log`।

[Android beta `1.42.0+45`](build/releases/ml-path-1.42.0-45.apk)-এর ১৮৩টি bundled file source-এর সঙ্গে byte-matched; signature verification pass, INTERNET permission নেই। Airplane mode-এ cold launch ও LLM Topic Index বাস্তবে খুলেছে; [screenshot](build/structured-book-android/topic-index-offline.png)-এ 5.1–5.5 serial ও related Capstone দেখা যায়। Logs: `build/structured-book-package.log`, `build/structured-book-offline.log` ও `build/structured-book-native-topic-retry.log`।

## Android beta 1.41.0+44 — 15 November 2026

Chapter 1–41-এর targeted content revisions ও cross-chapter follow-up একত্রে APK-তে এসেছে। বর্তমান packaged counts: 41 chapters, 790 lessons, 990 quizzes, 381 exercises ও 393 interview cases। নিচের dated entries সংশ্লিষ্ট pass-এর historical record; সেখানে pending APK/device কাজ এই Android build-এ যাচাই হয়েছে।

[APK](build/releases/ml-path-1.41.0-44.apk): **99,071,857 bytes**, SHA256 `f83c0507bbdda78e563f4ed82d94037b32d1266b8d3d859228bfa1de2e29cefb`। 183টি bundled file বর্তমান source-এর সঙ্গে byte-matched; missing font glyph 0; INTERNET permission নেই। APK Signature Scheme v2 verification pass করেছে। Release-mode APK বিদ্যমান Android debug key দিয়ে signed personal beta।

Dedicated Android emulator-এ দুটি integration workflow pass করেছে। প্রথমটিতে 41-chapter counts, full-text search, checkpoint/completion, Bellman sweeps, dark theme, quiz ও learner records reopen পরীক্ষা হয়েছে। দ্বিতীয়টিতে font scale 1.6-এ equations, hidden self-check answer, prerequisite navigation এবং চারটি wrong/correct numeric-answer case ও persistence যাচাই হয়েছে। Native workflows Flutter-এর debug test harness ব্যবহার করেছে। এরপর release APK install করে airplane mode-এ cold launch করা হয়েছে; screenshot খুলে loaded Chapter 1 Home ও বাংলা rendering দেখা হয়েছে। Font scale 1.0 ও আগের disabled airplane-mode state ফিরিয়ে দেওয়া হয়েছে।

Source QA-তে full suite 795 pass, overlapping final book/math checks 21 pass এবং সব 381টি exercise solution-এর Python checks pass। Logs `build/final-release-retry.log`, `build/final-release-package.log`, `build/final-release-signature.log`, `build/final-native-book.log`, `build/final-native-learning.log` ও `build/final-release-offline.log`। Consolidated evidence `build/final-release-verification.json`।

Verdict এখনও **personal use ও সীমিত beta**। পুরো বইয়ের independent sentence-level language edit, বাস্তব learner comprehension review এবং native iOS QA সম্পূর্ণ হয়নি। এগুলো APK build বা automated tests দিয়ে নিশ্চিত করা যায় না।

## Remaining content tasks follow-up — 15 November 2026

Chapter 41-এর focused deep review শেষ হয়েছে। Chapter 1–41-এর targeted group revisions এখন সম্পূর্ণ। এই pass-এ RL-এর 80টি existing block সম্পাদনা হয়েছে। আরও 13টি chapter-এর 15টি prose block-এ publication directions, practice wording, stale quiz count ও নির্বাচিত shorthand explanations সংশোধন হয়েছে। প্রতিটি paragraph-এর independent sentence-level editing এবং বাস্তব learner দিয়ে comprehension review এখনও বাকি।

### Mathematical ও learning-content corrections

- **Discounted policy gradient।** Objective J=E[G0], step-relative Gt এবং ordinary episode summation ধরে formula-তে outer gamma^t যোগ হয়েছে। Two-step Bernoulli example-এর exact gradient 0.375, outer weighting বাদ দিলে 0.5। Fixed baseline, same-batch mean baseline ও leave-one-out baseline-এর expectations আলাদাভাবে দেখানো হয়েছে। [Sutton ও Barto, Policy Gradient Methods](https://web.stanford.edu/class/psych209/Readings/SuttonBartoRL.pdf)
- **MDP ও Bellman planning।** Risk-neutral expected Bellman value-এর জন্য expected immediate reward ও transition probabilities যথেষ্ট—এই বিষয়টি স্পষ্ট হয়েছে। Lab-এর fixed advance/try policy linear solve দিয়ে evaluate ও greedy consistency check করা যায়। Terminal state বাদ দিয়ে রাখা substochastic transition matrix-এর ব্যাখ্যা আছে।
- **Episode ও gradient boundaries।** Repeated-state first-visit/every-visit MC, terminal/truncation mask, detached DQN targets এবং positive/negative advantage-এর PPO gradients executable examples-এ আছে। External time limit ও intrinsic finite horizon আলাদাভাবে ব্যাখ্যা করা হয়েছে। [Farama termination/truncation](https://farama.org/Gymnasium-Terminated-Truncated-Step-API), [PPO paper](https://arxiv.org/abs/1707.06347)
- **Sequential evaluation।** Full-trajectory ও per-decision importance sampling-এর exact expectation ও variance একই teaching process-এ হিসাব করা যায়। Bandit ties, eligible actions ও reward scaling-এর self-check আছে। Source probabilities, environment assumptions ও evaluation unit স্পষ্ট করা হয়েছে।

RL chapter-এ 29টি block যোগ হয়েছে, যার মধ্যে সাতটি runnable example, নয়টি self-check ও তিনটি equation আছে। দুটি existing equation সংশোধিত। নতুন চারটি quiz, চারটি coding exercise ও দুটি interview case যোগ হয়েছে। Existing ছয় exercise-এর prompt/feedback এবং আট interview-এর answers সম্পাদিত। সব দশ interview-এ prerequisite links আছে। Original quiz IDs ও correct answer indices, existing exercise code/expected values এবং সব পুরোনো code block-এর AST যাচাই হয়েছে।

Source counts এখন 41 chapters, 790 lessons, 990 quizzes, 381 exercises ও 393 interview cases। Chapter 41-এ 16 lessons, 20 quizzes, 10 exercises ও 10 interviews আছে। Snapshot evidence `build/remaining-source-diff.json`।

### Cross-chapter flow ও beginner setup

Chapter 17, 18, 27 ও 28-এর পুরোনো future-publication directions এখন existing chapters-এ পাঠায়। Chapter 25-এর quiz count 26 হয়েছে। Chapter 20-এর FFN ও Chapter 21-এর model-selection explanation পূর্ণ বাংলায় লেখা হয়েছে। Source prose-এ পরের existing chapter এখনও তৈরি হয়নি বলে থাকা reviewed patterns-এর matches শূন্য। RL lab-এর transition description-ও স্বাভাবিক বাংলায় সম্পাদনা হয়েছে।

README-তে project folder ও companion data কোথায় থাকবে, Windows/macOS/Linux-এ local Python environment, dependency installation, প্রথম script, expected output এবং common setup errors-এর ধাপ আছে। PyTorch-এর official installation selector link দেওয়া হয়েছে। App-এর practice draft থেকে local script ও numeric result মেলানোর workflow লেখা আছে। Source/course export UI app backlog-এ আছে।

### Verification

Chapter 6–41-এর আটটি numerical revision group-এ 148টি example, 356টি exercise solution ও 103টি displayed-feedback precision check pass করেছে। প্রথম পাঁচ chapter-এর আলাদা verifier-এর 25টি solution-সহ মোট 381টি exercise solution বর্তমান source-এ pass করেছে। Existing book verifier-এর 62টি walkthrough ও compatibility checks-ও pass করেছে। Reports `build/all-content-revisions-validation.json`, `build/remaining-foundation.log` ও `build/remaining-compatibility-final.log`। Chapter 41 চালাতে `python tool/check_chapter_content_revision.py --start-chapter 41 --end-chapter 41` ব্যবহার করুন। আগের five-chapter commands সমর্থিত।

প্রথম full Flutter run-এ 795টির মধ্যে 14টি failure ছিল। সেগুলো obsolete quiz/exercise totals এবং সব snippet-এ comment marker খোঁজার assertion থেকে এসেছে। Score tests এখন current chapter-এর পূর্ণ quiz count যাচাই করে। Numeric acceptance test 381টি exercise গণনা করে। Code-block presence, Python AST, numerical outputs ও readable comments প্রয়োজন অনুযায়ী যাচাইয়ের workflow রাখা হয়েছে।

Final clean full run-এ **795টি Flutter test pass** করেছে। শেষ prerequisite edits-এর পরে book/math-focused run-এর **21টি test pass** করেছে। Counts overlap। Chapter 41-এর interview prerequisites পরে পড়ার chapters-এ যাচ্ছে কি না, তার regression assertion আছে। ওই দুই link এখন Chapter 5 ও বর্তমান Chapter 41-এর lessons ব্যবহার করে। Whole-book **795টি equation parse**, **42টি width/text-scale layout case pass** ও missing font glyph **0**। Dark large-text RL/quiz screenshots দেখা হয়েছে। Evidence `build/remaining-final-full-flutter.log`, `build/remaining-final-book-checks.log`, `build/editorial-math-check.json`, `build/editorial-layout-check.json` ও `build/remaining-compatibility-final.log`। Final analyzer clean, `build/remaining-final-analyze.log`। Consolidated record `build/remaining-tasks-verification.json`।

এই content pass-এর সময়ে packaged beta `1.40.2+43` প্রথম পাঁচ chapter revision-এর artifact ছিল। নতুন APK/device verification উপরের `1.41.0+44` entry-তে আছে। Native iOS review, বাস্তব learner study এবং পূর্ণ sentence-level language edit এখনও release backlog-এ আছে।

## Chapter 36–40 content revision — 15 November 2026

এই pass-এ পাঁচ chapter-এর 115টি lesson-এর নির্বাচিত দুর্বল ব্যাখ্যা ও practice বিস্তৃত হয়েছে। নতুন 72টি block-এর মধ্যে 21টি runnable example, 23টি self-check ও পাঁচটি mathematical formulation আছে। নতুন 10টি feedback quiz ও Chapter 39-এ দুটি algorithm interview case যোগ হয়েছে। 54টি exercise-এর prompt ও feedback এবং 24টি opening paragraph স্বাভাবিক বাংলায় সম্পাদনা হয়েছে। 21টি existing interview-এ prerequisite links যোগ হয়েছে। নতুন দুটিসহ linked interview মোট 23টি। পাঁচটিতে numerical follow-up আছে।

- **Chapter 36 · Serving, Monitoring & MLOps।** Replica p95-এর average ও fleet quantile-এর numerical counterexample, disjoint windows-এর request-weighted burn, unchanged marginals-এর মধ্যে joint shift এবং selective label maturity-তে model comparison উল্টে যাওয়ার example আছে। Scope, counts ও aggregation rules স্পষ্ট করা হয়েছে। Histogram ও burn-rate discussion-এর references official documentation-এ দেওয়া হয়েছে। [Prometheus histograms](https://prometheus.io/docs/practices/histograms/), [Google SRE alerting](https://sre.google/workbook/alerting-on-slos/)
- **Chapter 37 · Experimentation & Causal Reasoning।** Ratio of totals ও mean user ratios-এর পৃথক estimands, first-order influence calculation, CUPED-এর population variance identity, post-treatment activity filter-এর collider effect এবং exact AIPW expectation দেখানো হয়েছে। Correct propensity বা outcome model থাকলে কী হয় এবং দুটোই ভুল হলে কী হয়, তা দেওয়া probability model দিয়ে enumerate করা যায়। [CUPED paper](https://ai.stanford.edu/~ronnyk/2013-02CUPEDImprovingSensitivityOfControlledExperiments.pdf), [Double/Debiased ML paper](https://arxiv.org/abs/1608.00060)
- **Chapter 38 · ML System Design Cases।** Explicit assumptions-সহ M/M/1 queue, correlated fanout tails, capped retry amplification এবং assumed reviewer sensitivity/specificity দিয়ে action risks হিসাব করা হয়েছে। Default selective policy-এর unresolved decisions থাকলে full-cohort accuracy সম্পর্কে কতটা জানা যায় তার bounds আছে। Fluid slot model ও queueing model-এর assumptions ব্যাখ্যা করা হয়েছে। [Queueing chapter](https://web.mit.edu/dimitrib/www/Queueing_Data_Nets.pdf), [Google SRE overload](https://sre.google/sre-book/handling-overload/)
- **Chapter 39 · Technical Interview Practice।** Deterministic bounded heap, Kahn traversal ও cycle detection, signed exact-sum range-এর earliest-prefix map, coin DP reconstruction এবং Welford state merge-এর examples আছে। Graph ও DP নিয়ে দুটি interview case যোগ হয়েছে। Code-এর input contracts, tie rules, complexity এবং small-input oracle দেওয়া আছে। একটি PyTorch interview-এর typo-ও সংশোধন হয়েছে। [MIT algorithms notes](https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/pages/lecture-notes/), [Variance algorithms paper](https://doi.org/10.1080/00031305.1983.10483115)
- **Chapter 40 · Final Capstone, Portfolio & Mock Interviews।** Actual frozen confusion counts থেকে FP/FN cost decomposition আছে। Teaching examples দিয়ে different slice mixtures, component interactions ও incomplete judgments-এর bounds দেখানো হয়েছে। Independent project শেষ করার ধাপ ও prerequisite revision plan বিস্তৃত হয়েছে।

Chapter 36→37→38→39→40 transitions এবং chapter outcomes সম্পাদনা হয়েছে। Chapter 40-এ Chapter 41 নেই বলে থাকা পুরোনো বক্তব্য ভুল ছিল। Closing prose, একটি existing quiz ও continuing-plan interview সংশোধন হয়েছে। Chapter 41-এর Reinforcement Learning & Bandits আগের Sequential Decisions reading step-এ থাকে। ওই quiz-এর ID ও correct answer index বজায় আছে।

ছোট examples-এর durations, workloads, rewards, probabilities, labels ও algorithm inputs teaching assumptions হিসেবে লেখা আছে। White-wine cost decomposition পূর্বের frozen decision evidence ব্যবহার করে। Numerical checks CPU-তে হয়েছে। Dataset bytes, stored benchmark provenance ও original code compatibility যাচাই হয়েছে। Historical outcomes সংশ্লিষ্ট পুরোনো protocol ও selection history-সহ পড়তে হবে। Expanded lessons-এর reading/practice estimate বেড়েছে, দুটি নতুন code example থাকা DP lesson-এ 25 মিনিট ও অন্য expanded lessons-এ 15 মিনিট করে যোগ হয়েছে।

Source counts এখন 41 chapters, 790 lessons, 986 quizzes, 377 exercises ও 391 interview cases। এই পাঁচ chapter-এ 146 quizzes, 54 exercises ও 56 interview cases আছে। Existing learner IDs, exercise starter/solution/expected values এবং 115টি original code block-এর AST snapshot-এর সঙ্গে মিলেছে। Original interview cases-এর order বজায় আছে, নতুন দুটি শেষে যোগ হয়েছে। Snapshot evidence `build/chapter-36-40-diff.json`।

`python tool/check_chapter_content_revision.py --start-chapter 36` দিয়ে 21টি নতুন example, 54টি exercise solution, 23টি displayed-feedback precision contract ও 23টি interview-এর prerequisite links pass করেছে। NumPy 2.5.4, pandas 3.1.1, SciPy 1.18.1 ও scikit-learn 1.9.1 ব্যবহৃত। এই batch-এর নতুন examples ও exercise checks-এ PyTorch প্রয়োজন হয়নি। Numerical evidence `build/chapter-36-40-validation.json`। `tool/check_book_revision.py --fonts` code/data compatibility ও font checks pass করেছে।

Repository, book assessment ও math presentation-এর focused Flutter run-এ 46টি test pass করেছে। পুরো বইয়ের 792টি equation parse হয়েছে এবং missing font glyph শূন্য। Evidence `build/chapter-36-40-flutter.log`, `build/chapter-36-40-compatibility.log` ও `build/editorial-math-check.json`।

এই pass source content পর্যন্ত। নতুন APK, device layout ও native iOS review পরবর্তী app verification-এর scope-এ আছে। Packaged beta `1.40.2+43` Chapter 1–5 revision-এর artifact। Chapter 1–40-এর group revisions-এর পরে Chapter 41-এর focused deep review বাকি। বাকি prose-এর line-by-line editing ও cross-chapter consistency review চলমান।

## Chapter 31–35 content revision — 14 November 2026

এই pass-এ পাঁচ chapter-এর 106টি lesson-এর নির্বাচিত দুর্বল ব্যাখ্যা ও practice বিস্তৃত হয়েছে। 67টি block যোগ হয়েছে, যার মধ্যে 20টি runnable example, 22টি self-check ও তিনটি mathematical formulation আছে। নতুন 10টি feedback quiz যোগ হয়েছে। বিদ্যমান 50টি exercise-এর prompt ও feedback এবং 17টি opening paragraph স্বাভাবিক বাংলায় সম্পাদনা হয়েছে। 20টি interview-এ prerequisite links ও পাঁচটিতে numerical/debugging follow-up আছে।

- **Chapter 31 · Matrix Factorization & Feature Interactions।** Bias-সহ explicit ALS normal equations, dense implicit solve ও Gram correction, একটি BPR triplet-এর সব factor gradients এবং FM pair sum/fast identity/gradient ধাপে দেখানো হয়েছে। Prediction-preserving inverse scaling-এ L2 penalty কেন বদলায় এবং orthogonal ambiguity কেন থাকে, তা স্পষ্ট করা হয়েছে।
- **Chapter 32 · Deep Recommendation & Ranking।** Normalized embedding-এর Jacobian, uniform-positive ও set-mass objectives-এর gradient, importance partition estimate-এর log bias এবং full-gold denominator দিয়ে candidate nDCG ceiling যোগ হয়েছে। Retrieval/ranker roles, feature sources ও hybrid union size-এর ব্যাখ্যা বিস্তৃত হয়েছে।
- **Chapter 33 · Recommendation Evaluation & Feedback Loops।** Exact logging expectation দিয়ে IPS, clipping ও one-draw SNIPS-এর পার্থক্য হিসাব করা হয়েছে। Paired bootstrap covariance, greedy MMR trace এবং equal-size cluster design effect-এর example আছে। Logging support না থাকলে একই logs থেকে target value নির্ধারণের সমস্যা দুই possible world দিয়ে দেখানো হয়েছে।
- **Chapter 34 · Recommender Capstone।** নির্দিষ্ট serializer দিয়ে canonical bytes, একই dimensions-এ stale item index-এর ranking change, history-aware cache signature এবং ordered IDs/per-ID scores-সহ golden replay যোগ হয়েছে। Fit/validation/audit roles, candidate selection ও feature statistics-এর data boundaries আরও পরিষ্কার হয়েছে।
- **Chapter 35 · ML Data Pipelines & Feature Systems।** Historical as-of view ও corrected retrospective backfill, একই SQLite transaction-এ rows/checkpoint rollback ও retry, watermark trace এবং প্রতি prediction-এর latest eligible feature version নেওয়ার executable SQL আছে। NULL, join cardinality ও upstream feature leakage নিয়ে self-check আছে।

ছোট examples-এর vectors, rewards, propensities, timelines ও rows হিসাব শেখানোর জন্য দেওয়া inputs হিসেবে চিহ্নিত। Numerical ও state checks CPU-তে হয়েছে। Source datasets ও stored benchmark evidence-এর provenance যাচাই হয়েছে। Historical benchmark outcomes-এর সঙ্গে সংশ্লিষ্ট experiment protocol পড়তে হবে। Chapter-end directions এখন 31→32→33→34→35→36 flow অনুসরণ করে। Expanded code lessons-এর reading/practice estimate 15 মিনিট করে বেড়েছে।

Source counts এখন 41 chapters, 790 lessons, 976 quizzes, 377 exercises ও 389 interview cases। এই পাঁচ chapter-এ 130 quizzes, 50 exercises ও 50 interview cases আছে। Existing learner IDs, original quizzes, exercise starter/solution/expected values এবং 106টি original code block-এর AST snapshot-এর সঙ্গে মিলেছে। Interview-এর একটি display title-এর বানান ঠিক হয়েছে, “Non-identifiability defense”। Numerical output-এর floating-point comparisons-এ প্রয়োজনমতো absolute tolerance 1e-12 আছে।

`python tool/check_chapter_content_revision.py --start-chapter 31` দিয়ে 20টি নতুন example, 50টি exercise solution, 27টি feedback precision contract ও 20টি interview-এর prerequisite links pass করেছে। PyTorch 2.15.0+cpu, NumPy 2.5.4, pandas 3.1.1, SciPy 1.18.1 ও scikit-learn 1.9.1 ব্যবহৃত। Numerical evidence `build/chapter-31-35-validation.json`, snapshot evidence `build/chapter-31-35-diff.json`। `tool/check_book_revision.py --fonts` original-code/data compatibility ও font checks pass করেছে।

Repository, book assessment ও math presentation-এর focused Flutter run-এ 46টি test pass করেছে। পুরো বইয়ের 787টি equation parse হয়েছে এবং missing font glyph শূন্য। Evidence `build/chapter-31-35-flutter.log` ও `build/editorial-math-check.json`।

এই pass source content পর্যন্ত। নতুন APK, device layout ও native iOS review পরবর্তী app verification-এর scope-এ আছে। Packaged beta `1.40.2+43` Chapter 1–5 revision-এর artifact। পরের chapter-number batch 36–40। পুরো বইয়ের line-by-line editorial review চলছে।

## Chapter 26–30 content revision — 14 November 2026

এই pass-এ পাঁচ chapter-এর 99টি lesson-এর নির্বাচিত দুর্বল ব্যাখ্যা ও practice বিস্তৃত হয়েছে। 65টি block যোগ হয়েছে, যার মধ্যে 20টি runnable example, 21টি self-check ও তিনটি mathematical formulation আছে। নতুন 10টি feedback quiz যোগ হয়েছে। বিদ্যমান 50টি exercise-এর prompt ও feedback স্বাভাবিক বাংলায় সম্পাদনা হয়েছে। Reliability ও GenAI Capstone-এর 19টি opening paragraph সম্পাদনা করা হয়েছে। 20টি interview-এ prerequisite links এবং পাঁচটিতে numerical/debugging follow-up আছে।

- **Chapter 26 · LLM Evaluation, Reliability & Serving।** ECE bin cancellation, Cohen κ ও class marginals, paired discordant test এবং request timestamps থেকে TTFT/TPOT/throughput-এর হিসাব যোগ হয়েছে।
- **Chapter 27 · Generative Models · VAE & GAN।** Exact Gaussian model-এ prior KL ও posterior ELBO gap, pathwise mean/log-variance gradients, pixel reduction-এর effective beta এবং optimal discriminator-এর JS identity দেখানো হয়েছে।
- **Chapter 28 · Diffusion & Multimodal Systems।** Precision দিয়ে Gaussian posterior, epsilon/velocity error amplification, skipped DDIM destination এবং CFG/clipping order-এর worked traces আছে।
- **Chapter 29 · LLM/Generative AI Capstone।** Local helper দিয়ে hash collision ও Bangla empty-feature path, first-token confidence বনাম sequence likelihood, policy precondition combinations এবং evidence/correctness joint rate যাচাই হয়েছে। Negative controls-এর পাশে item-level changes ব্যাখ্যা করা হয়েছে।
- **Chapter 30 · Recommendation Foundations।** Global cutoff ও seen-item eligibility, actual-set cosine shrinkage, signed explicit-rating residuals এবং full-catalog বনাম sampled-candidate metrics-এর হিসাব আছে।

ছোট examples-এ data, annotations, probabilities বা timestamps আগে থেকে নির্ধারিত teaching inputs হিসেবে লেখা আছে। Source datasets ও historical benchmark evidence-এর provenance যাচাই হয়েছে। Numerical/state checks CPU-তে হয়েছে। Historical benchmark outcomes আগের experiment protocol-এর evidence হিসেবে পড়তে হবে। Chapter-end directions এখন 26→27→28→29→30→31 reading flow অনুসরণ করে। Expanded code lessons-এর reading/practice estimate 15 মিনিট করে বেড়েছে।

Source counts এখন 41 chapters, 790 lessons, 966 quizzes, 377 exercises ও 389 interview cases। এই পাঁচ chapter-এ 130 quizzes, 50 exercises ও 50 interview cases আছে। Existing learner IDs, exercise starter/solution/expected values এবং original-code/data compatibility যাচাই হয়েছে। নতুন code snippets readable formatting-এ আছে। GAN stationarity check-এ near-zero floating-point residual-এর জন্য absolute tolerance 1e-12 রাখা হয়েছে।

`python tool/check_chapter_content_revision.py --start-chapter 26` দিয়ে 20টি নতুন example, 50টি exercise solution, 13টি feedback precision contract ও 20টি interview-এর prerequisite links pass করেছে। PyTorch 2.15.0+cpu, NumPy 2.5.4, pandas 3.1.1, SciPy 1.18.1 ও scikit-learn 1.9.1 ব্যবহার করা হয়েছে। Numerical evidence `build/chapter-26-30-validation.json`। `tool/check_book_revision.py --fonts` compatibility ও font checks pass করেছে।

Repository, book assessment ও math presentation-এর focused Flutter run-এ 46টি test pass করেছে। পুরো বইয়ের 784টি equation parse হয়েছে এবং missing font glyph শূন্য। Evidence `build/chapter-26-30-flutter.log` ও `build/editorial-math-check.json`।

এই pass source content পর্যন্ত। নতুন APK, device layout ও native iOS review পরবর্তী app verification-এর scope-এ আছে। Packaged beta `1.40.2+43` Chapter 1–5 revision-এর artifact। পরের chapter-number batch 31–35। পুরো বইয়ের line-by-line editorial review চলছে।

## Chapter 21–25 content revision — 14 November 2026

এই pass-এ পাঁচ chapter-এর 100টি lesson-এর নির্বাচিত দুর্বল ব্যাখ্যা ও practice বিস্তৃত হয়েছে। মোট 69টি block যোগ হয়েছে, যার মধ্যে 20টি runnable example, 22টি self-check ও পাঁচটি mathematical formulation আছে। নতুন 10টি feedback quiz যোগ হয়েছে। বিদ্যমান 50টি exercise-এর prompt ও feedback স্বাভাবিক বাংলায় সম্পাদনা হয়েছে। RAG ও fine-tuning-এর 31টি opening paragraph-ও পড়ার ধারাবাহিকতা রেখে লেখা হয়েছে। 20টি interview-এ prerequisite links এবং পাঁচটিতে numerical/debugging follow-up আছে।

- **Chapter 21 · Deep Learning Capstone।** Conflicting profile labels থেকে finite-table consistency bound,weighted BCE-এর conditional optimum,repeated-selection probability এবং bootstrap replicate eligibility-এর হিসাব যোগ হয়েছে।
- **Chapter 22 · LLM Foundations।** বাংলা UTF8 streaming,BPE overlapping-pair count বনাম nonoverlapping replacement,packed-document attention/label boundaries এবং top-k/top-p operation order দেখানো হয়েছে। Tokenization units বদলালে likelihood ranking কেন বদলাতে পারে তার worked explanation আছে।
- **Chapter 23 · Embeddings & Semantic Retrieval।** Multiple-positive loss ও false-negative gradients,filter ordering,ANN-neighbor recall বনাম relevance recall,RRF contributions এবং macro/micro denominators বিস্তৃত হয়েছে।
- **Chapter 24 · RAG Systems।** Greedy packing-এর budget tradeoff,document-qualified sentence identity,risk/coverage curve এবং citation-link/claim metrics-এর পৃথক denominators শেখানো হয়েছে। Support labels examples-এ আগে থেকে দেওয়া teaching annotations।
- **Chapter 25 · Fine-tuning & Efficient Adaptation।** LoRA-র প্রথম দুই backward,alpha/r-সহ merge ও double-merge error,quantization grid-এ ছোট update হারানো এবং response-token sums থেকে DPO gradients আছে।

Examples ছোট teaching fixtures হিসেবে চিহ্নিত। Original datasets ও stored benchmark outcomes-এর provenance সংরক্ষিত আছে। এই pass-এ নতুন held-out benchmark বা pretrained LLM adaptation run করা হয়নি। Numerical ও state checks CPU-তেই হয়েছে। পাঁচ chapter-এর শেষে 21→22→23→24→25→26 reading flow লেখা হয়েছে। Expanded code lessons-এর reading/practice estimate 15 মিনিট করে বেড়েছে।

Source counts এখন 41 chapters, 790 lessons, 956 quizzes, 377 exercises ও 389 interview cases। এই পাঁচ chapter-এ 130 quizzes, 50 exercises ও 50 interview cases আছে। Existing learner IDs, exercise starter/solution/expected values এবং original code AST/data compatibility যাচাই হয়েছে। নতুন code snippets readable formatting-এ লেখা হয়েছে।

`python tool/check_chapter_content_revision.py --start-chapter 21` দিয়ে 20টি নতুন example, 50টি exercise solution, 12টি feedback precision contract ও 20টি interview-এর prerequisite links pass করেছে। PyTorch 2.15.0+cpu, NumPy 2.5.4, pandas 3.1.1, SciPy 1.18.1 ও scikit-learn 1.9.1 ব্যবহার করা হয়েছে। Numerical report `build/chapter-21-25-validation.json`। `tool/check_book_revision.py --fonts` compatibility ও font checks pass করেছে।

Repository, book assessment ও math presentation-এর focused Flutter run-এ 46টি test pass করেছে। পুরো বইয়ের 781টি equation parse হয়েছে এবং font checks-এ missing glyph শূন্য। Evidence `build/chapter-21-25-flutter.log` ও `build/editorial-math-check.json`।

এই pass source content পর্যন্ত। নতুন APK, device layout ও native iOS review পরবর্তী app verification-এর scope-এ আছে। Packaged beta `1.40.2+43` Chapter 1–5 revision-এর artifact। পরের chapter-number batch 26–30। পুরো বইয়ের line-by-line editorial review চলছে।

## Chapter 16–20 content revision — 14 November 2026

এই pass-এ পাঁচ chapter-এর নির্বাচিত দুর্বল ব্যাখ্যা ও practice বিস্তৃত হয়েছে। 105টি lesson-এর মধ্যে সংশ্লিষ্ট lesson-গুলোতে 64টি block যোগ হয়েছে। এর মধ্যে 20টি worked code example, 20টি self-check ও চারটি mathematical derivation আছে। নতুন 10টি feedback quiz যোগ হয়েছে। বিদ্যমান 50টি exercise-এর prompt ও explanation স্বাভাবিক বাংলায় লেখা হয়েছে। 20টি interview-এ prerequisite lesson links এবং পাঁচটিতে নির্দিষ্ট numerical বা debugging follow-up আছে।

- **Chapter 16 · Neural Networks & Backpropagation।** একটি দুই-row MLP-এর সব parameter gradients, হাতে তৈরি XOR representation, ReLU-এর second moment ও centered variance এবং contrastive temperature-সহ score gradients অনুসরণ করা যায়।
- **Chapter 17 · Reliable Deep Learning Training।** Adam-এর দ্বিতীয়-step moments ও bias correction, দুই batch-এর BatchNorm buffers, accumulation/clipping order এবং Dropout+momentum checkpoint resume-এর runnable trace আছে। Restored parameters ও momentum buffers continuous run-এর সঙ্গে মেলে। Current PyTorch-এর positive-epsilon requirement মেনে BN example যাচাই হয়েছে।
- **Chapter 18 · CNNs, Computer Vision & Transfer Learning।** Spatial windows থেকে filter/input gradient, depthwise/pointwise channel mixing, dilated receptive support-এর ফাঁক এবং frozen parameters-এর পাশে BN buffer updates ধাপে দেখানো হয়েছে।
- **Chapter 19 · Sequence Models।** Nonzero GRU reset-placement example, shared recurrent parameter-এর full/truncated gradient, packed/dense bidirectional states এবং BOS/EOS/PAD-সহ decoder target alignment যোগ হয়েছে।
- **Chapter 20 · Attention & Transformers।** q/k/v gradients, MHA/SDPA mask polarity, দুই-token cached chunk-এর absolute-position mask এবং RoPE-এর relative-rotation identity যোগ হয়েছে।

Worked examples ছোট teaching fixtures। Original source datasets ও historical benchmark evidence আগের provenance বহন করে। CPU float64 arithmetic ও state tests-এর জন্য GPU প্রয়োজন হয়নি। পাঁচটি chapter-end নির্দেশনা 16→17→18→19→20→21 reading flow অনুযায়ী লেখা হয়েছে। Expanded code lessons-এর estimated reading/practice time 15 মিনিট করে বেড়েছে।

Source-এ এখন 41 chapters, 790 lessons, 946 quizzes, 377 exercises ও 389 interview cases। এই পাঁচ chapter-এ 130 quizzes, 50 exercises ও 50 interview cases আছে। Existing learner IDs এবং exercise starter/solution/expected values-এর compatibility যাচাই হয়েছে।

`python tool/check_chapter_content_revision.py --start-chapter 16` দিয়ে 20টি নতুন example, 50টি exercise solution, চারটি feedback precision contract এবং 20টি interview-এর prerequisite links pass করেছে। PyTorch 2.15.0+cpu, NumPy 2.5.4, pandas 3.1.1, SciPy 1.18.1 ও scikit-learn 1.9.1 ব্যবহার করা হয়েছে। Numerical evidence `build/chapter-16-20-validation.json`। `tool/check_book_revision.py --fonts` original-code/data compatibility ও font glyph checks pass করেছে।

Focused Flutter run-এ 45টি test pass এবং একটি catalog test fail করেছিল। Chapter 19–20-এর প্রতি lesson-এ ঠিক আটটি block থাকার পুরোনো assertions expanded content অনুযায়ী minimum আট করা হয়েছে। Catalog test পুনরায় pass করেছে। সব মিলিয়ে এই run-এর 46টি পৃথক check pass হয়েছে। এর মধ্যে পুরো বইয়ের 776টি equation parsing-ও আছে। Logs `build/chapter-16-20-flutter.log` ও `build/chapter-16-20-catalog-recheck.log`। নতুন 20টি code snippet readable formatting-এ লেখা হয়েছে এবং formatting-এর আগে-পরে AST মিলেছে।

এই pass source content পর্যন্ত। নতুন APK ও device layout review পরবর্তী app build-এর সঙ্গে হবে। Packaged beta `1.40.2+43` Chapter 1–5 revision-এর artifact। Full-suite ও native iOS review পরবর্তী verification scope-এ আছে। পরের chapter-number batch 21–25। পুরো বইয়ের line-by-line editorial review চলছে।

## Chapter 11–15 content revision — 14 November 2026

এই pass-এ Chapter 11–15-এর নির্বাচিত দুর্বল ব্যাখ্যা ও practice বিস্তৃত হয়েছে। পাঁচ chapter-এর 105টি lesson-এ 70টি block যোগ হয়েছে, যার মধ্যে 23টি self-check ও 20টি executable example আছে। নতুন 10টি feedback quiz যোগ হয়েছে। বিদ্যমান 50টি exercise-এর prompt ও feedback স্বাভাবিক বাংলায় সম্পাদনা করা হয়েছে। 20টি interview case-এ prerequisite links এবং পাঁচটিতে concrete numerical follow-up যোগ হয়েছে।

- **Chapter 11 · SVM, kNN & Naive Bayes।** দুই-point SVM dual থেকে multiplier, slack ও primal/dual agreement বের করা যায়। Distance-weighted kNN vote, duplicate evidence-এ NB posterior এবং দুই-observation GP-এর Cholesky posterior ধাপে দেখানো হয়েছে।
- **Chapter 12 · Clustering & Dimensionality Reduction।** পুরো GMM E/M iteration-এ responsibility, effective count, নতুন mean ও variance আছে। EM-এর likelihood argument, frozen PCA query reconstruction, DBSCAN border expansion এবং point-wise silhouette average বিস্তৃত হয়েছে।
- **Chapter 13 · Anomaly Detection & Time Series Foundations।** LOF-এর reachability ও density ratio, recursive/rolling forecast-এর information sets, delayed forward-target availability, conformal rank enumeration এবং raw event/censor table থেকে Kaplan–Meier product আছে।
- **Chapter 14 · Classical ML Capstone।** Artifact-এর fit/decision/test ownership, exhaustive threshold prediction sets, paired group-bootstrap estimand, subgroup base-rate arithmetic এবং inference JSON round-trip যোগ হয়েছে। এগুলো ছোট teaching fixtures। Wine source-এর নতুন benchmark বা protected-group study চালানো হয়নি।
- **Chapter 15 · PyTorch Tensors & Autograd।** সম্পূর্ণ matrix forward/backward trace, uneven microbatch gradient scaling, detached alias mutation-এর version check, Hessian-vector product এবং learned-weight denominator-এর quotient rule আছে।

Chapter-end নির্দেশনা বর্তমান বইয়ের 11→12→13→14→15→16 পথে মেলানো হয়েছে। Expanded code lessons-এর reading/practice estimate 15 মিনিট করে বাড়ানো হয়েছে। Original code blocks, exercise starter/solution/expected values এবং existing learner IDs বজায় আছে। মোট source counts এখন 41 chapters, 790 lessons, 936 quizzes, 377 exercises ও 389 interview cases। এই পাঁচ chapter-এ 130 quizzes, 50 exercises ও 50 interview cases আছে।

Shared numerical checker-এর command `python tool/check_chapter_content_revision.py --start-chapter 11`। 20টি নতুন example, 50টি exercise solution, নয়টি rounded-feedback value এবং 20টি interview-এর prerequisite links pass করেছে। NumPy 2.5.4, pandas 3.1.1, SciPy 1.18.1, scikit-learn 1.9.1 ও PyTorch 2.15.0+cpu ব্যবহৃত। CPU float64 tensor examples-এর জন্য GPU প্রয়োজন হয়নি। Chapter 6–10-এর আগের numerical checker-ও refactoring-এর পরে pass করেছে। রিপোর্ট `build/chapter-11-15-validation.json`।

`tool/check_book_revision.py --fonts` original-code/data compatibility ও font glyph checks pass করেছে। Repository, book assessment ও LaTeX-এর focused Flutter run-এ 46টি test pass করেছে। এর মধ্যে পুরো বইয়ের 772টি equation parsing-ও আছে। Content loading, grading ও persistence-এর ফল `build/chapter-11-15-flutter.log`-এ রাখা হয়েছে।

এটি source content-এর revision। নতুন APK build ও device layout validation পরবর্তী app build-এর জন্য রাখা হয়েছে। বিদ্যমান packaged beta `1.40.2+43` আগের Chapter 1–5 revision-এর artifact। এই pass-এ full Flutter suite এবং native iOS review চালানো হয়নি। পরবর্তী chapter-number batch 16–20। পুরো বইয়ের line-by-line editorial review এখনও চলছে।

## Chapter 6–10 content revision — 14 November 2026

এই দফায় Chapter 6–10-এর দুর্বল ব্যাখ্যা ও practice সম্পাদনা করা হয়েছে। পাঁচ chapter-এর 86টি lesson-এ মোট 83টি block যোগ হয়েছে, যার মধ্যে 22টি self-check ও 20টি executable Python example আছে। বিদ্যমান 42টি exercise-এর prompt ও feedback স্বাভাবিক বাংলায় লেখা হয়েছে। 15টি interview case-এ prerequisite lesson links এবং পাঁচটিতে আরও নির্দিষ্ট follow-up ও উত্তর যোগ হয়েছে।

- **Chapter 6 · Python Engineering for ML।** Loop/return/input state, axis ও broadcasting-এর ভুল shape, pandas label alignment ও Copy-on-Write, chunked mean/variance merge এবং বড় workflow পড়ার ধাপ বিস্তৃত হয়েছে।
- **Chapter 7 · Linear Algebra, Calculus & Optimization।** Rank/nullspace ও minimum-norm solution, OLS projection/residual, matrix ও bias gradient, finite-difference check, conditioning এবং simplex projection-এর KKT হিসাব যোগ হয়েছে।
- **Chapter 8 · Probability, Statistics & Inference।** Dependent sample ও IID uncertainty, LLN/CLT, conditional mean ও total variance, entropy/CE/KL, likelihood/MLE/Beta update, Wilson interval এবং exact one-/two-sided p-value ধাপে দেখানো হয়েছে।
- **Chapter 9 · Decision Trees।** সব valid threshold-এর gain, prefix-count scan, local/global impurity decrease, XOR-এ greedy stopping-এর সীমা এবং cost-complexity pruning-এর crossing point ব্যাখ্যা করা হয়েছে।
- **Chapter 10 · Ensembles & Boosting।** OOB coverage/denominator, covariance থেকে ensemble variance, stacking-এর OOF row mapping ও serving refit, AdaBoost weight update এবং Taylor objective থেকে leaf weight/split gain-এর হিসাব যোগ হয়েছে।

প্রতিটি worked example ছোট teaching fixture হিসেবে চিহ্নিত। নতুন numerical traces বাস্তব dataset-এর benchmark হিসেবে ব্যবহার করা হয়নি। পাঁচ chapter-এর শেষে reading-path নির্দেশনা বর্তমান ক্রমের সঙ্গে মেলানো হয়েছে। Chapter 8 থেকে Chapter 4-এ যেতে হবে। বিদ্যমান lesson/quiz/exercise IDs এবং interview order বজায় আছে। মোট chapter/lesson/assessment counts আগের মতো 41/790/926/377/389।

`tool/check_chapters_06_10_revision.py` দিয়ে 20টি নতুন example, 42টি exercise solution ও 11টি rounded-feedback answer যাচাই হয়েছে। Python 3.12.10, NumPy 2.5.4, pandas 3.1.1, SciPy 1.18.1 ও scikit-learn 1.9.1 ব্যবহার করা হয়েছে। রিপোর্ট `build/chapter-06-10-validation.json`। `tool/check_book_revision.py --fonts` pass করেছে। Original code/data compatibility এবং font glyph checks pass করেছে। LaTeX test-এ পুরো বইয়ের 770টি equation parse হয়েছে।

এটি source content-এর revision। ব্যবহারকারীর নির্দেশ অনুযায়ী APK build ও emulator validation পরবর্তী app build-এর জন্য রাখা হয়েছে। বিদ্যমান APK `1.40.2+43` আগের Chapter 1–5 revision-এর artifact। এই দফায় full Flutter suite চালানো হয়নি। Device-এ নতুন অংশের layout এবং native iOS validation এখনও বাকি। পরবর্তী chapter-number batch 11–15। পুরো বইয়ের line-by-line editorial review এখনও চলছে।

## Chapter 1–5 revision — 14 November 2026

Build `1.40.2+43`-এ review-তে পাওয়া দুর্বলতার জন্য প্রথম পাঁচ chapter-এ 74টি block যোগ হয়েছে। Chapter সংখ্যা 41 এবং lesson সংখ্যা 790। মোট quizzes 926, exercises 377 এবং interview cases 389। প্রথম পাঁচ chapter-এ এখন 58টি lesson, 72টি quiz, 25টি exercise ও 35টি interview case আছে। নতুন 18টি self-check-এর উত্তর খুলে দেখতে হয়।

- **Chapter 1।** একই ছয় point দিয়ে prediction, residual ও MSE অনুসরণ করা যায়। Split-এর আগে bundled real dataset load করা হয়। Partition sizes 309/66/67 ব্যাখ্যা করা হয়েছে। Gradient interview-এর prerequisite buttons Chapter7-এর chain rule ও Chapter2-এর gradient lesson খোলে। Resume সংশ্লিষ্ট lesson-এর chapter-এ সংরক্ষিত হয়।
- **Chapter 2।** OLS assumptions ও interval-এর অর্থ, Lasso soft-thresholding, exposure-সহ Poisson notation ও fitted hinge basis ব্যাখ্যা বাড়ানো হয়েছে। Diabetes development CV-তে OLS/Ridge/Lasso/Huber/additive spline তুলনা এবং validation residual plot যোগ হয়েছে। Quantile model-এর pinball loss ও coverage-ও আছে। GLM/spline-এর quiz, coding ও interview practice বেড়েছে।
- **Chapter 3।** BCE-এর derivative থেকে p−y হওয়ার মধ্যবর্তী algebra, finite-difference check, চার score-এর ROC/AP trace এবং পূর্ণ multiclass confusion matrix যোগ হয়েছে। Lesson softmax-এর denominator একবার হিসাব হওয়ায় time O(K)।
- **Chapter 4।** একই পাঁচ row-তে fit/transform ও output shape অনুসরণ করা যায়। OOF target encoding-এর row/fold mapping এবং final inference mapping ব্যাখ্যা করা হয়েছে। Missingness mechanism বোঝাতে collection scenario আছে।
- **Chapter 5।** Nested CV-এর explicit indices, paired bootstrap-এর একটি replicate ও cluster weighting, bias–variance-এর cross terms এবং Hoeffding থেকে union bound ও ERM inequality-এর ধাপ যোগ হয়েছে। Adult workflow পড়ার জন্য intermediate arrays ও data boundary ব্যাখ্যা আছে।

তিনটি exercise-এর rounding নির্দেশনার সঙ্গে tolerance মিলেছে। `ch02_ex_metrics` ও `ch03_ex_softmax`-এ absolute tolerance0.0005, `ch04_ex_cyclic`-এ0.00005 এবং তিনটির relative tolerance0। তাই যথাক্রমে0.667,0.333,0.2611 গ্রহণযোগ্য। অন্য exercise-এর declared tolerance নিজস্ব মান অনুসরণ করে।

Diabetes walkthrough Python3.12.10 / NumPy2.5.4 / scikit-learn1.9.1-এ চালানো হয়েছে। CV selection-এ Lasso, validation MAE42.8395 এবং training-median baseline MAE62.7416 পাওয়া গেছে। Split, settings ও measured output lesson-এ আছে। এটি development comparison। Close CV scores বিচার করতে uncertainty ও অন্য development splits নিয়ে পরের পরীক্ষা সাজাতে হবে। Original Adult/Wine source files ও আগের frozen results আগের provenance বহন করে।

Python verification `tool/check_foundation_revision.py`-তে 12টি নতুন code/plot example এবং প্রথম পাঁচ chapter-এর25টি solution চালানো হয়। Softmax-এর100-class input-এ100টি element একবার sum হওয়ার assertion আছে। পুরোনো AST baseline রেখে দুটি deliberate revision-এর before/after hash ও কারণ `tool/foundation_revision_spec.json`-এ রেকর্ড করা হয়েছে। অন্য760টি legacy walkthrough ও368টি legacy solution-এর AST এবং141টি original data/font file byte-matched।

এই কাজ review-তে নির্দিষ্ট করা Chapter1–5-এর অংশগুলো উন্নত করেছে। পুরো বইয়ের line-by-line editorial review, learner study এবং native iOS review বাকি। পরের section-এ10 November-এর broad audit ও তার evidence রাখা আছে।

এই revision-এর full Flutter suite **795 pass**, focused run **120 pass**। শেষ feedback copy edit-এর পরে **21 pass**, সব **763টি equation parse** এবং **42টি layout case pass**। Counts overlap। Analyzer clean। প্রথম full run-এর তিনটি পুরোনো quiz-count assertion সংশোধন করে full suite পুনরায় চালানো হয়েছে। প্রথম পাঁচ chapter-এর25টি exercise feedback সম্পূর্ণ বাংলা বাক্যে সম্পাদনা করা হয়েছে।

Android native test system font scale1.6-এ GLM/BCE content, collapsed self-check, prerequisite lesson খুলে interview-এ ফেরা এবং তিনটি rounded-answer contract যাচাই করেছে। Database reopen-এর পরেও তিনটি result সংরক্ষিত ছিল। Selected screenshots দেখে Bangla rendering যাচাই হয়েছে। Evidence `build/foundation-native.log`, `build/foundation-full-test.log`, `build/foundation-focused-final.log`, `build/foundation-copy-test.log`, `build/foundation-validation.json`।

Final release APK **1.40.2+43**, **98,944,637 bytes**।183টি bundled file source-এর সঙ্গে byte-matched, missing font glyph0, INTERNET permission নেই। SHA256 `5e6950a979971b94322f4338d0c07e46892af1672250375b3106dbba0ea3fe39`। Airplane-mode cold launch-এর screenshot-এ Chapter1-এর loaded Home এবং updated reading time দেখা হয়েছে। QA emulator-এর font scale ও connectivity ফিরিয়ে দিয়ে নিজস্ব QA instance বন্ধ করা হয়েছে। Consolidated evidence `build/foundation-release-verification.json`।

## 10 November 2026-এর verdict ও broad audit

**Public production release-এর জন্য এখনও প্রস্তুত নয়। নিজের পড়াশোনা ও সীমিত beta ব্যবহারের জন্য ব্যবহারযোগ্য।** নিচের পুরোনো curriculum/QA report-এ “সম্পন্ন” বলতে সেই revision-এর কাজ ও checks বোঝানো হয়েছে; পুরো বইয়ের ভাষা বা শিক্ষার মানের চূড়ান্ত অনুমোদন বোঝানো হয়নি। বর্তমান editorial build `1.40.1+42`; chapter এখনও 41টি।

বিষয়বস্তুর বিস্তার ভালো: foundation থেকে classical ML, Deep Learning, RL, LLM, retrieval, recommendations, system design ও interview preparation পর্যন্ত একটি reading path আছে। তবে topic উপস্থিত থাকা আর নতুন শিক্ষার্থীর জন্য ব্যাখ্যাটি যথেষ্ট হওয়া এক কথা নয়। এই review-তে প্রতিটি chapter থেকে দুটি করে মোট 82টি representative excerpt হাতে পড়েছি, আরও কিছু নির্দিষ্ট অংশ দেখেছি এবং rendering/code/storage checks চালিয়েছি। সব 790টি lesson, 920টি quiz, 374টি exercise ও 387টি interview case-এর প্রতিটি বাক্য নতুন করে যাচাই করা হয়নি।

### এই review-তে যা ঠিক হয়েছে

- **ভাষা:** 41টি chapter-এর শুরুর ব্যাখ্যা এবং আরও 40টি নির্বাচিত prose block নতুন করে লেখা হয়েছে। Technical terms রেখে বাংলা বাক্যের স্বাভাবিক গঠন ব্যবহার করেছি। যেমন, “14-day window … zero থেকে starts” বদলে “প্রতিটি 14 দিনের window-এর শুরুতে hidden state h₀ শূন্য করছি।” ভাঙা শব্দ, কয়েকটি অস্পষ্ট সংজ্ঞা, common headings ও নতুন lesson subtitles-ও ঠিক হয়েছে। Chapter23-এর contrastive-loss exercise-এ vector, positive pair, temperature ও চাওয়া ফল স্পষ্ট করে বলা হয়েছে। এটি পুরো বইয়ের line-by-line copy edit নয়।
- **Equation rendering:** 756টি math block parse করে পাঁচটির unsupported notation পাওয়া গেছে। সেগুলোর notation বদলে rendering ঠিক করা হয়েছে; mathematical claim বদলানো হয়নি। এখন সবগুলো parse হয়। Parse হওয়া সব derivation সঠিক হওয়ার প্রমাণ নয়।
- **ছোট screen ও বড় font:** আগের 24টি layout case-এর চারটিতে Home/Quiz overflow পাওয়া যায়। Badge ও navigation/score layout ঠিক করা হয়েছে। এখন সাতটি page, দুইটি width (320/390) ও তিনটি text scale (1/1.6/2) মিলিয়ে 42টি case pass করে। প্রতিটি interactive lab বা সব accessibility requirement এই test-এর আওতায় নেই।
- **লম্বা equation/code:** horizontal scrolling-এর hint ও scrollbar যোগ হয়েছে। Equation-এর নিচে scrollbar-এর জন্য আলাদা জায়গা রাখা হয়েছে। বড় equation পড়াতে font ছোট করে দেওয়া হয়নি।
- **বাংলা heading:** Home-এর বাংলা heading-এ English typography-এর negative letter spacing সরানো হয়েছে; lesson heading-ও অক্ষর চেপে দেখায় না।
- **Exercise feedback:** scratchpad যে Python চালায় না, তা field-এর বাইরেই স্পষ্ট লেখা আছে। Numeric result মিললে এখন “ফল মিলেছে” দেখায়; এটি code correctness বা exercise mastery-এর certificate নয়। বড় font-এ field label ও helper পড়ার জায়গাও বাড়ানো হয়েছে।
- **আগের শেখার তথ্য:** chapter/lesson IDs, quiz answer indices, numeric answers ও আগের Python logic অক্ষত রাখা হয়েছে। Content update-এর জন্য notes, bookmarks বা progress মুছে ফেলা হয়নি।

### প্রকাশের আগে যে কাজগুলো বাকি

1. **পুরো বইয়ের বাংলা সম্পাদনা।** Chapter opening ভালো হলেই body, quiz feedback ও interview answer সমান স্বাভাবিক হয় না। কিছু পুরোনো অংশ এখনও সংক্ষিপ্ত experiment note-এর মতো লেখা। যেমন `ch20_ffn`-এ “Same FFN weights … independently apply হয়” এবং `ch21_selection`-এ “Highest mean AP model নির্বাচন করে” ধরনের বাক্য আছে। এগুলোতে কী হচ্ছে, কেন হচ্ছে এবং learner কী বুঝবেন—সেটি সম্পূর্ণ বাংলায় বলতে হবে। Technical term অনুবাদ করাই লক্ষ্য নয়।
2. **ব্যাখ্যার গভীরতা ও assessment-এর মিল যাচাই।** প্রতিটি lesson-এর assumptions, notation, derivation, code ও exercise একসঙ্গে পড়ে দেখতে হবে। Quiz-এর ভুল option কেন ভুল, interview answer মুখস্থ না করে কীভাবে যুক্তি দিতে হবে, prerequisite আগে শেখানো হয়েছে কি না—এসবের পূর্ণ human review এখনও বাকি। Automated test এই কাজের বিকল্প নয়।
3. **সাধারণ learner-এর coding setup।** শুধু APK পাওয়া learner কীভাবে companion Python files/datasets পাবেন, local environment তৈরি করবেন এবং প্রথম walkthrough চালাবেন—এই flow আরও সহজ করা দরকার। Repository ব্যবহারকারীর জন্য files আছে; app-এ সম্পূর্ণ course export/setup flow নেই। On-device Python execution বাধ্যতামূলক নয়, তবে বাইরে code চালানোর নির্দেশনা সম্পূর্ণ হতে হবে।
4. **বাস্তব learner ও iOS review।** নতুন learner দিয়ে chapter পড়ে, solution না দেখে exercise করে এবং navigation ব্যবহার করে দেখতে হবে। Native iOS presentation এখনও যাচাই করা হয়নি। 42টি layout case pass-কে সব screen-এর accessibility approval বলা যাবে না।

পরবর্তী editorial pass বইয়ের reading order-এ করুন: **1 → 6 → 7 → 8 → 4 → 2 → 3 → 5**, তারপর বাকি Parts। প্রতিটি chapter-এ একটি বাস্তব প্রশ্ন দিয়ে ধারণা শুরু হবে; variable ও assumption বুঝিয়ে তারপর equation, ধাপে ধাপে হিসাব, commented code, ভুল হওয়ার জায়গা, practice ও interview reasoning আসবে। English technical term প্রথমবার ব্যাখ্যা করুন; বাংলা বাক্যে English sentence structure বসাবেন না। বিষয় সহজ করতে গিয়ে প্রয়োজনীয় শর্ত বাদ দেওয়া যাবে না।

বর্তমান automated evidence: full suite **792 pass**; শেষ rendering/layout/assessment run **8 pass**; সব **756 equation parse**, **42 layout case pass**। Counts overlap; যোগ করে unique total বলা হচ্ছে না। Android native test-এ system font scale1.6 দিয়ে equation scroll, dark quiz এবং ভুল/সঠিক numeric result যাচাই হয়েছে। Input focus/keyboard synchronization-এর test helper ঠিক করার পরে workflow pass করেছে; equation ও numeric feedback-এর screenshots দেখা হয়েছে। Native iOS review হয়নি। মূল logs: `build/editorial-full-test.log`, `build/editorial-final-focused-test.log`, `build/editorial-native.log`, `build/editorial-math-check.json`, `build/editorial-layout-check.json`।

Full suite-এর পরে শেষ scrollbar/typography সংশোধনের জন্য সংশ্লিষ্ট আটটি test আবার চালানো হয়েছে। Final `flutter analyze` clean। APK build **1.40.1+42**, **98,926,821 bytes**; **183টি bundled file byte-matched**, missing font glyph **0**, INTERNET permission **নেই**। SHA256: `7046472a06ec2f50f1db220c609c0ef34399dabbd8b015195e4a94a3556f2b29`। Current release evidence: `build/editorial-code-check.log`, `build/editorial-release.log`; consolidated record: `build/editorial-review.json`।

এই final APK-এর airplane-mode cold launch pass করেছে। `build/screenshots/05-release-offline.png` খুলে Chapter1-এর আটটি lesson-সহ loaded Home দেখা হয়েছে; splash screen বা process চালু থাকা মাত্রকে pass ধরা হয়নি। QA emulator-এর আগের connectivity ও font scale ফিরিয়ে দিয়ে শুধু এই কাজের জন্য চালু করা emulator বন্ধ করা হয়েছে। Log: `build/editorial-offline.log`।

---

## আগের curriculum revision-এর report

এই revision-এর scope: সব 40টি existing chapter-এর topic inventory, order/prerequisite ও practice structure review; app navigation/storage/rendering audit; নির্দিষ্ট curriculum gaps পূরণ। এটি নতুন data collection, সব scientific claim-এর independent replication অথবা সব research specialization-এর certification নয়। Automated checks ও focused mathematical/source review-এর evidence নিচে আলাদা করা হয়েছে।

## মূল structural findings ও implemented fixes

- **Prerequisites পরে ছিল:** নতুন reading order1→6→7→8→4→2→3→5। সব 41টি chapter-এর order/prerequisites/outcomes/recall/transition metadata যোগ; graph acyclic কি না test হয়।
- **Chapter islands:** book TOC, Part grouping, full-text cross-chapter lesson search ও final-lesson থেকে next reading chapter navigation। পুরোনো IDs renumber নয়।
- **Coverage ও depth:** আগের সব chapter-এ অন্তত একটি targeted expansion; চারটি foundation/algorithm chapter-এ অতিরিক্ত bridge, Chapter13-এ survival, Chapter39-এ general coding patterns। মোট46টি existing-chapter additions। Dedicated RL chapter16টি lesson।
- **Passive recall:** নতুন62টি self-check-এ solution collapsed; math, explicit worked fixture, commented runnable code, output interpretation ও failure cases আছে।
- **Lesson placement:**25টি expansion সংশ্লিষ্ট prerequisite concept-এর পাশে বসানো হয়েছে। Foundation1/6/7/8/4-এ reading guides আগাম application references-এর অর্থ বুঝিয়ে দেয়।
- **Numeric grading bug:** fixed absolute `.001` threshold-এর জন্য `ch19_ex_bptt`, `ch23_ex_contrastive`, `ch31_ex_bpr`, `ch31_ex_derivative`-এ nonzero expected result-এর বদলে0 accepted হতো। এখন configurable absolute+relative tolerance, finite-value validation ও UI precision hint আছে। সব374 expected values, চারটি zero-rejection case এবং actual scratchpad regression test pass। পুরোনো Solved flags reset/regrade করা হয়নি।
- **Chapter transition:** source lesson-এর chapter identity স্থির রাখা হয়েছে; next reading step-এ যাওয়ার সময় header ভুল chapter/lesson0 দেখায় না।
- **Code readability:** lesson code ও exercise text formatting-এর1521টি পরিবর্তন; operation-specific37টি comment। প্রতিটি formatting change AST equivalence দিয়ে যাচাই; old walkthrough/solution logic অক্ষত।
- **Prose defects:** broken technical words ও Python module names-এর targeted fixes; Bangla/English boundary spacing। Guess-based Bangla word segmentation ব্যবহার করা হয়নি।
- **Documentation drift:** current README/ROADMAP rewritten; পুরোনো detailed experiment notes CHAPTER_HISTORY.md-এ retained।

## Chapter-by-chapter findings ও additions

### Chapter 1 · Machine Learning Fundamentals

Prediction ও action boundary স্পষ্ট করে feature timing, majority baseline ও feedback-এর সংযোগ দরকার ছিল।

- `ch01_book_formulation` — Prediction, decision ও deployment contract।

বর্তমান coverage: 8 lessons, 10 quizzes, 2 exercises, 5 interview cases। Reading step 1।

### Chapter 2 · Linear Regression in Depth

Count targets-এর likelihood/link এবং controlled nonlinear basis-এর gap ছিল; variants-এর পাশে GLM ও Splines/GAM যোগ।

- `ch02_book_glm` — Beyond squared loss: GLM ও Poisson Regression।
- `ch02_book_splines` — Splines ও Generalized Additive Models: controlled nonlinearity।

বর্তমান coverage: 14 lessons, 14 quizzes, 5 exercises, 7 interview cases। Reading step 6।

### Chapter 3 · Classification Fundamentals

Probability quality ও policy cost-এর সম্পর্ক আরও explicit derivation দরকার ছিল।

- `ch03_book_cost_policy` — Calibrated probabilities থেকে cost-sensitive decisions।

বর্তমান coverage: 9 lessons, 10 quizzes, 3 exercises, 5 interview cases। Reading step 7।

### Chapter 4 · Data Preparation & Feature Engineering

Feature cleaning-এর পাশাপাশি label definition, annotation agreement ও adjudication গভীর করা দরকার ছিল।

- `ch04_book_label_quality` — Label quality, annotation agreement ও target leakage।

বর্তমান coverage: 13 lessons, 16 quizzes, 6 exercises, 8 interview cases। Reading step 5।

### Chapter 5 · Model Evaluation & Experiment Design

Practical CV/uncertainty-এর সঙ্গে formal bias–variance এবং finite-class selection/generalization reasoning দরকার ছিল।

- `ch05_book_generalization` — Bias–variance, irreducible noise ও selection overfitting।
- `ch05_book_learning_theory` — Learning theory: finite-class generalization ও uniform bounds।

বর্তমান coverage: 14 lessons, 16 quizzes, 6 exercises, 8 interview cases। Reading step 8।

### Chapter 6 · Python Engineering for ML

Readable function contract, silent zip truncation ও finite-value policy-এর একটি end-to-end refactoring example দরকার ছিল।

- `ch06_book_debug_contract` — Readable Python: trace, refactor ও edge-case contracts।

বর্তমান coverage: 15 lessons, 18 quizzes, 8 exercises, 8 interview cases। Reading step 2।

### Chapter 7 · Linear Algebra, Calculus & Optimization

Shape-aware differential notation ও constraints/KKT-কে পরের regression/SVM derivation-এর আগে bridge করা দরকার ছিল।

- `ch07_book_notation_bridge` — Notation bridge: scalar থেকে differential পর্যন্ত।
- `ch07_book_constraints` — Constrained optimization: Lagrangian, KKT ও projection।

বর্তমান coverage: 18 lessons, 20 quizzes, 8 exercises, 8 interview cases। Reading step 3।

### Chapter 8 · Probability, Statistics & Inference

Conditional expectation, total variance ও entropy/cross-entropy/KL-এর unified bridge দরকার ছিল।

- `ch08_book_information` — Conditional expectation, total variance ও information theory।

বর্তমান coverage: 17 lessons, 20 quizzes, 8 exercises, 8 interview cases। Reading step 4।

### Chapter 9 · Decision Trees

Predictive importance, permutation ও causal explanation-এর সীমা আরও concrete করা দরকার ছিল।

- `ch09_book_explanations` — Feature importance, permutation ও explanation limits।

বর্তমান coverage: 17 lessons, 20 quizzes, 8 exercises, 8 interview cases। Reading step 9।

### Chapter 10 · Ensembles & Boosting

Ensemble diversity কেন কাজ করে তা correlation/variance derivation দিয়ে বোঝানো দরকার ছিল।

- `ch10_book_ensemble_variance` — Ensemble diversity: correlation থেকে variance reduction।

বর্তমান coverage: 19 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 10।

### Chapter 11 · SVM, kNN & Naive Bayes

Generative বনাম discriminative classifier ও kernel-based uncertainty-এর জায়গায় GDA/LDA ও GP gap ছিল।

- `ch11_book_discriminant` — Generative বনাম discriminative: GDA ও LDA boundary।
- `ch11_book_gaussian_process` — Gaussian Processes: kernels ও predictive uncertainty।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 11।

### Chapter 12 · Clustering & Dimensionality Reduction

Hard clustering/PCA-এর পাশাপাশি soft membership ও EM updates অনুপস্থিত ছিল।

- `ch12_book_mixture_em` — Soft clustering: Gaussian Mixtures ও EM algorithm।

বর্তমান coverage: 20 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 12।

### Chapter 13 · Anomaly Detection & Time Series Foundations

Interval lesson-এর finite-sample conformal rank correction ও exchangeability limits; censored time-to-event targets-এর পৃথক introduction দরকার ছিল।

- `ch13_book_conformal` — Split conformal intervals: finite-sample rank ও assumptions।
- `ch13_book_survival` — Time-to-event targets: censoring ও Kaplan–Meier।

বর্তমান coverage: 22 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 13।

### Chapter 14 · Classical ML Capstone

Project evidence-এর পাশে subgroup harm, support, consent ও deployment restrictions-এর practice দরকার ছিল।

- `ch14_book_fairness` — Responsible ML: subgroup metrics, consent ও deployment limits।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 14।

### Chapter 15 · PyTorch Tensors & Autograd

Autograd সঠিক হলেও weighted objective ভুল হতে পারে—unequal reduction denominator-এর bridge দরকার ছিল।

- `ch15_book_differentiation_contract` — Autograd contract: VJP, scalar losses ও weighted reductions।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 15।

### Chapter 16 · Neural Networks & Backpropagation

Representation learning-এর সঙ্গে self-supervised/semi-supervised objectives-এর explicit connection দরকার ছিল।

- `ch16_book_representation` — Self-supervised learning, representation ও transfer objectives।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 16।

### Chapter 17 · Reliable Deep Learning Training

Accumulation আলোচিত হলেও unequal microbatch scaling ও batch-dependent-state equivalence-এর worked counterexample দরকার ছিল।

- `ch17_book_accumulation` — Gradient accumulation: unequal microbatches ও exact scaling।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 17।

### Chapter 18 · CNNs, Computer Vision & Transfer Learning

Augmentation label-preserving কি না এবং robustness-vs-domain-transfer claims আরও স্পষ্ট করা দরকার ছিল।

- `ch18_book_vision_shift` — Vision robustness: label-preserving transforms ও domain shift।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 18।

### Chapter 19 · Sequence Models

Teacher forcing ও free-running rollout-এর train/inference mismatch একটি numeric example দিয়ে গভীর করা দরকার ছিল।

- `ch19_book_scheduled_sampling` — Teacher forcing, exposure bias ও multi-step rollout।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 19।

### Chapter 20 · Attention & Transformers

KV cache optimization-এর semantic equivalence invariant ও mask/position failure modes explicit করা দরকার ছিল।

- `ch20_book_attention_equivalence` — Attention equivalence: masks, cache ও position invariants।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 20।

### Chapter 21 · Deep Learning Capstone

Winning result-এর পাশে failed runs, seed selection ও selection history প্রকাশের practice দরকার ছিল।

- `ch21_book_selection_ledger` — Selection ledger: failed experiments ও model choice।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 21।

### Chapter 22 · LLM Foundations

Tokenizer-dependent perplexity ও common raw-unit normalization-এর explicit comparison দরকার ছিল।

- `ch22_book_tokenization_comparison` — Perplexity, tokenization ও comparable evaluation units।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 23।

### Chapter 23 · Embeddings & Semantic Retrieval

ANN neighbor recall ও judged task relevance recall-এর denominator আলাদা করে শেখানো দরকার ছিল।

- `ch23_book_retrieval_error` — Retrieval failure decomposition: relevance, coverage ও ANN recall।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 24।

### Chapter 24 · RAG Systems

Citation/provenance validity এবং actual claim entailment/answerability-এর আলাদা measurement দরকার ছিল।

- `ch24_book_answerability` — RAG answerability: retrieval, evidence ও entailment আলাদা gates।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 25।

### Chapter 25 · Fine-tuning & Efficient Adaptation

SFT/LoRA-এর পরে preference alignment-এর objective bridge হিসেবে RLHF/DPO দরকার ছিল।

- `ch25_book_preferences` — Preference alignment: RLHF intuition ও DPO objective।

বর্তমান coverage: 16 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 26।

### Chapter 26 · LLM Evaluation, Reliability & Serving

LLM-as-judge-এর order bias, remapping, invalid outputs ও independent reference-এর practice দরকার ছিল।

- `ch26_book_judge_reliability` — LLM judges: agreement, blinded order ও uncertainty।

বর্তমান coverage: 17 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 27।

### Chapter 27 · Generative Models: VAE & GAN

ELBO gap ও posterior collapse-এর interpretation আরও explicit করা দরকার ছিল।

- `ch27_book_elbo_gap` — ELBO gap, posterior collapse ও generative evaluation।

বর্তমান coverage: 19 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 28।

### Chapter 28 · Diffusion & Multimodal Systems

Noise/data/velocity targets-এর roundtrip ও scheduler/checkpoint compatibility শেখানো দরকার ছিল।

- `ch28_book_diffusion_parameterization` — Diffusion targets: epsilon, x₀ ও v parameterization।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 29।

### Chapter 29 · LLM/Generative AI Capstone

Negative controls দিয়ে evaluation সত্যিই evidence use মাপছে কি না পরীক্ষা করার practice দরকার ছিল।

- `ch29_book_negative_controls` — Negative controls: evaluation যেন model নয় shortcut না মাপে।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 30।

### Chapter 30 · Recommendation Foundations

Exposure ও preference আলাদা করে missing feedback/cold-start fallback-এর assumptions দরকার ছিল।

- `ch30_book_cold_start` — Cold start, exposure ও missing-not-negative feedback।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 31।

### Chapter 31 · Matrix Factorization & Feature Interactions

Latent coordinates-এর identifiability ও same prediction/different penalty-এর example দরকার ছিল।

- `ch31_book_identifiability` — Latent-factor identifiability, regularization ও interpretation।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 32।

### Chapter 32 · Deep Recommendation & Ranking

Negative sampling proposal ও partition correction-এর relationship explicit করা দরকার ছিল।

- `ch32_book_sampled_softmax` — Sampled softmax, in-batch negatives ও serving scores।

বর্তমান coverage: 22 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 33।

### Chapter 33 · Recommendation Evaluation & Feedback Loops

Bandit/RL foundation ছাড়া IPS formula বিচ্ছিন্ন ছিল; support/variance/sequential limits-এর bridge যোগ।

- `ch33_book_bandit_evaluation` — Bandit feedback: support, IPS variance ও policy value।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 34।

### Chapter 34 · Recommender Capstone

Byte checks-এর পাশে ranking total order, eligibility ও semantic replay-এর পৃথক gates দরকার ছিল।

- `ch34_book_replay_contract` — Replay correctness: deterministic ranking ও artifact semantics।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 35।

### Chapter 35 · ML Data Pipelines & Feature Systems

Pipeline lineage-এর সঙ্গে minimization/deletion এবং DP adjacency/composition-এর introductory bridge দরকার ছিল।

- `ch35_book_privacy` — Privacy by design: minimization, deletion ও differential privacy।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 36।

### Chapter 36 · Serving, Monitoring & MLOps

PSI alarm থেকে model degradation conclude না করে covariate/label/concept shift diagnose করার framework দরকার ছিল।

- `ch36_book_shift_taxonomy` — Distribution shift: covariate, label ও concept drift।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 37।

### Chapter 37 · Experimentation & Causal Reasoning

Stratified adjustment-এর পরে propensity/outcome models ও doubly robust AIPW-এর assumptions দরকার ছিল।

- `ch37_book_doubly_robust` — IPW, outcome regression ও doubly robust ATE।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 38।

### Chapter 38 · ML System Design Cases

Diagram/capacity arithmetic-এর পরে feasible set, Pareto tradeoffs ও assumed-vs-measured SLO আলাদা করা দরকার ছিল।

- `ch38_book_design_tradeoffs` — System-design tradeoffs: quality, latency, cost ও failure budgets।

বর্তমান coverage: 21 lessons, 24 quizzes, 10 exercises, 10 interview cases। Reading step 39।

### Chapter 39 · Technical Interview Practice

Existing Python/SQL/ML coding-এর পাশাপাশি general interview graph/BFS এবং DP/sliding-window patterns-এর gap ছিল।

- `ch39_book_graphs` — Coding pattern: BFS, shortest paths ও graph invariants।
- `ch39_book_dynamic_programming` — Coding patterns: sliding window ও dynamic programming।

বর্তমান coverage: 26 lessons, 32 quizzes, 12 exercises, 12 interview cases। Reading step 40।

### Chapter 40 · Final Capstone, Portfolio & Mock Interviews

Reading completion, closed-book skill এবং personal evidence/contribution আলাদা করে targeted revision-এর rubric দরকার ছিল।

- `ch40_book_mastery` — Final synthesis: closed-book mastery ও evidence-based revision।

বর্তমান coverage: 26 lessons, 32 quizzes, 12 exercises, 12 interview cases। Reading step 41।

### Chapter 41 · Reinforcement Learning & Bandits

RL শুধু introductory learning type ছিল; delayed decisions, planning/control, bandits ও policy-gradient foundation-এর dedicated flow দরকার ছিল।

- `ch41_contract` — RL problem formulation: agent, environment ও reward।
- `ch41_mdp` — Markov Decision Process ও transition model।
- `ch41_returns` — Return, discount ও finite/infinite horizons।
- `ch41_bellman` — Policy value ও Bellman expectation equation।
- `ch41_optimality` — Bellman optimality ও synchronous value iteration।
- `ch41_policy_iteration` — Policy iteration: evaluate, improve, verify।
- `ch41_monte_carlo` — Monte Carlo prediction ও episode returns।
- `ch41_td` — Temporal-difference learning ও terminal bootstrapping।
- `ch41_control` — SARSA বনাম Q-learning: on-policy ও off-policy control।
- `ch41_bandits` — Multi-armed ও contextual bandits: exploration কেন?।
- `ch41_ucb` — UCB, uncertainty ও regret।
- `ch41_policy_gradient` — Policy gradients: REINFORCE ও log-derivative trick।
- `ch41_actor_critic` — Actor–critic, advantage ও PPO clipping intuition।
- `ch41_dqn` — Deep Q-learning: replay, target networks ও instability।
- `ch41_offline_evaluation` — Offline RL, coverage ও evaluation limits।
- `ch41_review` — RL workflow: formulate, solve, simulate, defend।

বর্তমান coverage: 16 lessons, 16 quizzes, 6 exercises, 8 interview cases। Reading step 22।

## Preserved contracts ও evidence boundaries

- Original728 lesson IDs ও relative order preserved; inserted sections নতুন IDs পায়। Original904 quiz choices/answer indices,368 exercise IDs/results ও prior interview cases retained। নতুন16 RL quizzes/6 exercises/8 interview cases আলাদা IDs।
- SQLite schema/learner tables replace হয়নি। All40 prior chapters-এর notes, bookmarks, completions, quiz answers, drafts ও resume values নিয়ে reopen/reseed test আছে। New lessons-এর completed flag default false; তাই percentage বদলানো data loss নয়।
- Old762 walkthrough AST এবং368 solution AST unchanged।141 original data/font file-এর SHA256 compatibility check আছে। নতুন reserved test outcomes score করা হয়নি; old frozen evidence fresh confirmation নয়।
- App Python execute করে না; numeric scratchpad full program correctness বা mastery certify করে না।
- RL value iteration fully specified MDP-এর planning। PPO/DQN lessons objective/architecture introductions; production training stack নয়। New GP/GLM/GAM/survival/DP sections mathematical worked examples, new real-data fitted benchmark নয়।

## QA evidence

`python tool/check_book_revision.py --fonts` pass: **41 chapters,790 lessons,920 quizzes,374 exercises,387 interview cases;62 executed new walkthroughs,6 executed RL solutions,824 parsed code blocks,762 unchanged prior walkthrough ASTs,368 unchanged prior solution ASTs,141 unchanged data/font files,0 missing glyphs**।

Final validation সম্পন্ন:

- Full regression suite: **780 pass**। Numeric-grading change-এর পরে affected chapters ও new assessment-এর **64 focused pass**। Final lesson-identity/navigation, grading ও all-new-lesson rendering-এর **16 pass**। Counts overlap; এগুলো যোগ করে unique test count বলা হচ্ছে না।
- `flutter analyze`: **No issues found**।
- Android integration: isolated SQLite fixture-এ all40 prior chapters-এর learner state, cross-chapter search, GLM lesson/Solution reveal, RL sweeps, dark mode, quiz ও reopen **pass**। আটটি screenshots captured; selected light/dark/content views visually reviewed।
- Final release APK: **1.40.0+41**, **98,915,197 bytes**, **183 byte-matched bundled files**, **INTERNET permission নেই**।
- Airplane-mode cold launch: loaded Chapter1-এর8 lessons-সহ real app UI দেখা গেছে; splash/PID check মাত্র নয়। Previous connectivity restored।
- APK SHA256: `dab9e061da344f37c795c3a95147dc05be4ebb1fead087300eb65441d70b3b1a`।

Evidence: `build/book-validation.json`, `build/book-code-verification.json`, `build/book-full-test.log`, `build/book-final-focused-test.log`, `build/book-final-ui-test.log`, `build/book-final-analyze.log`, `build/book-integration.log`, `build/book-offline.log`। Native iOS QA করা হয়নি।

## Primary references used for gap review

- [Dive into Deep Learning — Preliminaries](https://d2l.ai/chapter_preliminaries/index.html): foundation sequence ও mathematical vocabulary।
- [An Introduction to Statistical Learning](https://www.statlearning.com/): statistical learning coverage, GLM/nonlinearity, resampling ও survival topic map।
- [Stanford CS229 syllabus](https://cs229.stanford.edu/syllabus-autumn2018.html): mathematics/probability prerequisites ও classical learning coverage।
- [scikit-learn common pitfalls](https://scikit-learn.org/stable/common_pitfalls.html), [mixtures](https://scikit-learn.org/stable/modules/mixture.html), [GP](https://scikit-learn.org/stable/modules/gaussian_process.html): fit boundaries ও estimator assumptions।
- [Sutton & Barto, Reinforcement Learning](https://mitpress.mit.edu/9780262039246/reinforcement-learning/): MDP, Bellman, MC/TD, control, bandits ও policy gradients।
- [Conformal Prediction](https://arxiv.org/abs/2107.07511): finite-sample rank correction ও coverage scope।
- [DPO](https://arxiv.org/abs/2305.18290), [PPO](https://arxiv.org/abs/1707.06347): preference/policy objective ও limitations।
- [Dwork & Roth, Differential Privacy](https://www.cis.upenn.edu/~aaroth/Papers/privacybook.pdf): adjacency, sensitivity ও composition।

References অতিরিক্ত reading/attribution; app ব্যবহার করতে network লাগে না। সব explanations/examples repo-তে authored; external book/paper-এর পূর্ণ text app-এ copy করা হয়নি।

## Remaining scope

Windows-এ native iOS QA সম্ভব নয়। Store signing, learner-data export/import, accessibility audit ও extended glossary app backlog-এ আছে। Advanced graph learning, Bayesian computation ও large-scale distributed training পৃথক deeper extensions; বইয়ের বর্তমান broad core-কে “সব ML research শেষ” বলা হচ্ছে না।
