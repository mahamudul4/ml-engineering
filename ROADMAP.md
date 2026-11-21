# ML Path — ৬টি বই, Deep-ML Coding Arena ও 320 FAANG Viva Hot Questions Roadmap

সর্বশেষ সংস্করণ: **`2.6.0+56` (Natural Bangladeshi CS Instructor Bangla + Math-Safe Tables + 53,041 Verified Native LaTeX Equations Edition)**। পুরো পাঠ্যক্রমটি **৬টি স্বতন্ত্র বইয়ে (Books 1–6)** সাজানো, যেখানে প্রতিটি বই নিজস্ব **`Chapter 1`** থেকে শুরু হয়। সম্পূর্ণ অফলাইন লাইব্রেরিতে এখন **৫০টি Chapter, ৮৮০টি Lesson, ১,০৯২টি Quiz, ৪৩৫টি অধ্যায়ভিত্তিক Coding Exercise, ৪৫৩টি Chapter Interview Case, ১২০টি Full-Codebase Deep-ML Style Coding Problem (৩৬০টি Think-First প্রশ্ন, সহজ বাংলা + native LaTeX এবং ৯৯০টি Python `assert` টেস্টসহ) এবং ৩২০টি High-Frequency FAANG Viva Hot Questions (স্বাভাবিক CS-instructor বাংলা + স্ট্যান্ডার্ড ইংরেজি Technical Terms + native LaTeX + Viva Flashcard Drill Mode সহ)** রয়েছে। `RichProse` ইঞ্জিনের মাধ্যমে এখন অ্যাপের প্রতিটি অংশে **Native LaTeX Equations (`$...$` inline ও `$$...$$` display — ৫৩,০৪১টি যাচাইকৃত সমীকরণ, `0` literal calques, `0` raw ASCII math, `0` awkward transliteration)**, **Math-Safe Comparison Tables**, **Bold Key Points**, `` `inline code` ``, `> **উদাহরণ:**` Callout এবং Short Runnable Python Snippets সুন্দরভাবে রেন্ডার হয়।

বিস্তারিত যাচাইকরণ ও অডিট রিপোর্ট পাবেন [CURRICULUM_AUDIT.md](CURRICULUM_AUDIT.md)-এ।

## পড়ার ও অনুশীলনের নিয়ম

1. **শূন্য থেকে শুরু করলে:** `Book 1 · ML Foundations` (`Chapter 1 → 5`) থেকে শুরু করুন এবং ক্রমানুসারে `Book 2` থেকে `Book 6` পর্যন্ত এগোন।
2. **ডোমেইন অনুযায়ী পড়তে চাইলে:** অ্যাপের উপরের `Book Selector` বা `All books (Library)` থেকে সরাসরি `Classical ML`, `Deep Learning & RL`, `LLMs & GenAI`, `Recommender Systems` অথবা `ML Systems & Interviews` বেছে নিন—প্রতিটি বইয়ের শুরুতেই প্রয়োজনীয় `Prerequisites` উল্লেখ করা আছে।
3. **প্রতিটি ধারণা আত্মস্থ করার রুটিন:** `Intuition` → বাস্তব সংখ্যার উদাহরণ → গাণিতিক সমীকরণ (`math`) → রানযোগ্য `Python` কোড → `Interactive Lab` → শেষের `Checkpoint`।
4. **Deep-ML Style Coding Arena (১২০টি প্রবলেম):** অ্যাপের `Coding Arena` থেকে `Linear Algebra`, `Stats & Metrics`, `Classical ML`, `Deep Learning`, `CV & Sequence`, `LLMs & Transformers`, `RAG/RecSys/GNN` এবং `Systems/RL/FAANG` ডোমেইনের পূর্ণাঙ্গ কোডবেস (`DecisionTreeClassifier`, `MultiHeadAttention`, `LoRALinear`, `KVBlockManager` ইত্যাদি) পড়ুন, `# TODO` ফাংশনটি নিয়ে `Think-First` প্রশ্নের উত্তর দিন এবং তারপর সম্পূর্ণ আলাদা **`Solution` Fragment**-এ গিয়ে যাচাইকৃত সমাধান ও লাইন-বাই-লাইন ব্যাখ্যা মিলিয়ে নিন।
5. **320 High-Frequency FAANG Viva Hot Questions Bank (`Hot Qs`):** Classical ML (60), Deep Learning (60), Transformers & Attention (40), LLMs / Post-Training / RAG / Interpretability (60), Math & Stats (20), Metrics / A/B / Causality (20), GenAI / VLMs / GNNs (20), RecSys / Ads (20) এবং GPU Systems / MLOps / System Design / Behavioral (20) — প্রতিটি প্রশ্নে ৩০-সেকেন্ডের সারাংশ, Bold Bullet Breakdown, Concrete Example, LaTeX Equation, Verified Python Snippet, Comparison Table ও Follow-up Trap আছে। **`Start Viva Flashcard Drill`** দিয়ে উত্তর লুকিয়ে মুখে মুখে অনুশীলন করে `Confident` / `Review Again` / `Star` ট্র্যাক করুন।
6. **FAANG Revision Loop:** প্রতিটি অধ্যায়ের শেষে `Practice Studio`-তে `Knowledge check`, `Coding exercises` এবং `Interview practice` সম্পন্ন করুন। কোনো `Quiz` ভুল হলে কিংবা কোনো `Interview` প্রশ্নে `Star` দিলে তা স্বয়ংক্রিয়ভাবে **`Revision deck`** ট্যাবে জমা হবে।
7. **নোট ও ব্যাকআপ:** `My notebook` থেকে ৬টি বইয়ের সব নোট ও বুকমার্ক এক জায়গায় সার্চ করতে পারবেন এবং `Backup JSON` / `Restore JSON` দিয়ে নিজের সব অগ্রগতি (`Coding Arena` ও `FAANG Hot Qs` Confident/Review/Star সহ) নিরাপদে সংরক্ষণ করতে পারবেন।

---

## ৬টি বইয়ের ধারাবাহিক পাঠ্যক্রম (Steps 1–50)

### Book 1 · ML Foundations (Steps 1–5 · 5 Chapters)

সাধারণ `Arithmetic` জানলেই এখান থেকে শুরু করা যাবে। `Python Engineering`, `Linear Algebra`, `Calculus`, `Probability/Statistics` এবং `Leakage`-মুক্ত `Data Preparation` এখানে তৈরি হবে।

- **Book 1 · Chapter 1** (`chapter_01`): **Machine Learning Fundamentals** — Step 1 · 8 lessons।
- **Book 1 · Chapter 2** (`chapter_06`): **Python Engineering for ML** — Step 2 · 15 lessons।
- **Book 1 · Chapter 3** (`chapter_07`): **Linear Algebra, Calculus & Optimization** — Step 3 · 18 lessons।
- **Book 1 · Chapter 4** (`chapter_08`): **Probability, Statistics & Inference** — Step 4 · 17 lessons।
- **Book 1 · Chapter 5** (`chapter_04`): **Data Preparation & Feature Engineering** — Step 5 · 13 lessons।

### Book 2 · Classical Machine Learning (Steps 6–14 · 9 Chapters)

`Linear Regression` ও `Classification` থেকে শুরু করে `Model Evaluation`, `Decision Trees`, `Gradient Boosting`, `SVM/kNN/Naive Bayes`, `Clustering`, `Time Series` এবং পূর্ণাঙ্গ `Classical ML Capstone`।

- **Book 2 · Chapter 1** (`chapter_02`): **Linear Regression in Depth** — Step 6 · 14 lessons।
- **Book 2 · Chapter 2** (`chapter_03`): **Classification Fundamentals** — Step 7 · 9 lessons।
- **Book 2 · Chapter 3** (`chapter_05`): **Model Evaluation & Experiment Design** — Step 8 · 15 lessons।
- **Book 2 · Chapter 4** (`chapter_09`): **Decision Trees** — Step 9 · 17 lessons।
- **Book 2 · Chapter 5** (`chapter_10`): **Ensembles & Boosting** — Step 10 · 19 lessons।
- **Book 2 · Chapter 6** (`chapter_11`): **SVM, kNN & Naive Bayes** — Step 11 · 21 lessons।
- **Book 2 · Chapter 7** (`chapter_12`): **Clustering & Dimensionality Reduction** — Step 12 · 20 lessons।
- **Book 2 · Chapter 8** (`chapter_13`): **Anomaly Detection & Time Series Foundations** — Step 13 · 22 lessons।
- **Book 2 · Chapter 9** (`chapter_14`): **Classical ML Capstone** — Step 14 · 21 lessons।

### Book 3 · Deep Learning & RL (Steps 15–23 · 9 Chapters)

`PyTorch Tensors` ও `Autograd` থেকে `Backpropagation`, `CNN`, `Sequence Models`, `Attention & Transformers`, `Reinforcement Learning` এবং হাজার `GPU`-এর `3D Parallelism`, `FlashAttention` ও `LLM Serving`।

- **Book 3 · Chapter 1** (`chapter_15`): **PyTorch Tensors & Autograd** — Step 15 · 21 lessons।
- **Book 3 · Chapter 2** (`chapter_16`): **Neural Networks & Backpropagation** — Step 16 · 21 lessons।
- **Book 3 · Chapter 3** (`chapter_17`): **Reliable Deep Learning Training** — Step 17 · 22 lessons।
- **Book 3 · Chapter 4** (`chapter_18`): **CNNs, Computer Vision & Transfer Learning** — Step 18 · 21 lessons।
- **Book 3 · Chapter 5** (`chapter_19`): **Sequence Models** — Step 19 · 21 lessons।
- **Book 3 · Chapter 6** (`chapter_20`): **Attention & Transformers** — Step 20 · 21 lessons।
- **Book 3 · Chapter 7** (`chapter_21`): **Deep Learning Capstone** — Step 21 · 21 lessons।
- **Book 3 · Chapter 8** (`chapter_41`): **Reinforcement Learning & Bandits** — Step 22 · 17 lessons।
- **Book 3 · Chapter 9** (`chapter_44`): **GPU Systems, 3D Parallelism & LLM Serving** — Step 23 · 9 lessons *(Roofline Model, FlashAttention-2, GQA KV Cache, ZeRO/FSDP, TP/PP, PagedAttention, Speculative Decoding ও 70B Capacity Planning)*।

### Book 4 · LLMs, RAG & Generative AI (Steps 24–35 · 12 Chapters)

`Tokenization` ও `Embeddings` থেকে `RAG`, `LoRA/QLoRA`, `LLM Benchmarks`, `Mechanistic Interpretability`, `VAE/GAN`, `Diffusion`, এবং ফ্রন্টিয়ার `Reasoning RLVR/GRPO`, `Agentic Systems`, `Multimodal VLMs` ও `Graph Neural Networks`।

- **Book 4 · Chapter 1** (`chapter_22`): **LLM Foundations** — Step 24 · 22 lessons।
- **Book 4 · Chapter 2** (`chapter_23`): **Embeddings & Semantic Retrieval** — Step 25 · 21 lessons।
- **Book 4 · Chapter 3** (`chapter_24`): **RAG Systems** — Step 26 · 21 lessons।
- **Book 4 · Chapter 4** (`chapter_25`): **Fine-tuning & Efficient Adaptation** — Step 27 · 16 lessons।
- **Book 4 · Chapter 5** (`chapter_26`): **LLM Evaluation, Reliability & Serving** — Step 28 · 18 lessons।
- **Book 4 · Chapter 6** (`chapter_42`): **LLM Evaluation & Benchmark Design** — Step 29 · 9 lessons।
- **Book 4 · Chapter 7** (`chapter_43`): **Mechanistic Interpretability for Language Models** — Step 30 · 6 lessons।
- **Book 4 · Chapter 8** (`chapter_27`): **Generative Models: VAE & GAN** — Step 31 · 19 lessons।
- **Book 4 · Chapter 9** (`chapter_28`): **Diffusion & Multimodal Systems** — Step 32 · 22 lessons।
- **Book 4 · Chapter 10** (`chapter_29`): **LLM/Generative AI Capstone** — Step 33 · 21 lessons।
- **Book 4 · Chapter 11** (`chapter_45`): **Reasoning Post-Training, RLVR & Agentic Systems** — Step 34 · 9 lessons *(PPO বনাম DPO, GRPO, Verifiable Rewards, Test-Time Compute/PRM, Constrained JSON Decoding ও Agentic Tool Security)*।
- **Book 4 · Chapter 12** (`chapter_46`): **Multimodal VLMs & Graph Neural Networks** — Step 35 · 9 lessons *(ViT/SigLIP Patch Tokens, AnyRes Document VQA, GCN, GraphSAGE, GAT, Over-smoothing ও Link Prediction Leakage)*।

### Book 5 · Recommender Systems (Steps 36–41 · 6 Chapters)

`Collaborative Filtering`, `Matrix Factorization`, `Two-Tower Retrieval`, `Off-policy Evaluation` থেকে শুরু করে ইন্ডাস্ট্রিয়াল `DLRM`, `DCN-v2`, `DIN/BST`, `MMoE/PLE`, `Ads Auction` ও `Calibration`।

- **Book 5 · Chapter 1** (`chapter_30`): **Recommendation Foundations** — Step 36 · 21 lessons।
- **Book 5 · Chapter 2** (`chapter_31`): **Matrix Factorization & Feature Interactions** — Step 37 · 21 lessons।
- **Book 5 · Chapter 3** (`chapter_32`): **Deep Recommendation & Ranking** — Step 38 · 23 lessons।
- **Book 5 · Chapter 4** (`chapter_33`): **Recommendation Evaluation & Feedback Loops** — Step 39 · 21 lessons।
- **Book 5 · Chapter 5** (`chapter_34`): **Recommender Capstone** — Step 40 · 21 lessons।
- **Book 5 · Chapter 6** (`chapter_47`): **Industrial Ads & Feed Ranking: DLRM, DCN-v2 & MMoE** — Step 41 · 9 lessons *(4-Stage Funnel SLA, DLRM, DCN-v2, DIN/BST, MMoE/PLE, eCPM VCG/First-Price Auction ও NE Calibration)*।

### Book 6 · ML Systems, MLOps & Interviews (Steps 42–50 · 9 Chapters)

`Point-in-time Feature Pipelines`, `Serving & MLOps`, `A/B Experimentation & Causal Inference`, ৪৫-মিনিটের পূর্ণাঙ্গ `FAANG ML System Design`, অ্যাডভান্সড `DSA + From-Scratch ML Coding` এবং `Senior (L5+) Behavioral & Leadership Principles`।

- **Book 6 · Chapter 1** (`chapter_35`): **ML Data Pipelines & Feature Systems** — Step 42 · 21 lessons।
- **Book 6 · Chapter 2** (`chapter_36`): **Serving, Monitoring & MLOps** — Step 43 · 21 lessons।
- **Book 6 · Chapter 3** (`chapter_37`): **Experimentation & Causal Reasoning** — Step 44 · 21 lessons।
- **Book 6 · Chapter 4** (`chapter_38`): **ML System Design Cases** — Step 45 · 22 lessons।
- **Book 6 · Chapter 5** (`chapter_39`): **Technical Interview Practice** — Step 46 · 31 lessons।
- **Book 6 · Chapter 6** (`chapter_40`): **Final Capstone, Portfolio & Mock Interviews** — Step 47 · 28 lessons।
- **Book 6 · Chapter 7** (`chapter_48`): **End-to-End 45-Minute FAANG ML System Design** — Step 48 · 8 lessons *(Reels/Shorts Feed, 500k QPS Ads Prediction, Visual/Autocomplete Search, Marketplace ETA, Fraud Integrity ও Enterprise Multimodal Copilot)*।
- **Book 6 · Chapter 8** (`chapter_49`): **Advanced FAANG DSA & From-Scratch ML Coding** — Step 49 · 8 lessons *(Sliding Window, Monotonic Deque, Trie, Dijkstra এবং স্ক্র্যাচ থেকে K-Means++, Causal MHA + KV Cache, LoRA Backward ও BPE/Cross-Entropy)*।
- **Book 6 · Chapter 9** (`chapter_50`): **FAANG Behavioral, Leadership Principles & L5+ Leveling** — Step 50 · 8 lessons *(L4 বনাম L5/L6 Signals, STAR + Counterfactual Impact, Amazon LPs, SEV-1 ML Postmortem ও 30-Day Loop Gameplan)*।

---

## FAANG Role-ভিত্তিক দ্রুত প্রস্তুতির পথ

- **Core ML Engineer (Ads / Feed / Ranking):** `Book 1` → `Book 2 (Ch 1–5)` → `Book 3 (Ch 3, 6, 9)` → `Book 5 (Ch 1–6)` → `Book 6 (Ch 1–4, 7–9)`।
- **GenAI / LLM / Frontier Engineer:** `Book 1` → `Book 3 (Ch 1–3, 6, 8, 9)` → `Book 4 (Ch 1–12)` → `Book 6 (Ch 2, 7–9)`।
- **Applied / Research Scientist:** `Book 1 (Ch 3–4)` → `Book 2 (Ch 3, 5, 8)` → `Book 3 (Ch 2, 6, 8)` → `Book 4 (Ch 6, 7, 11, 12)` → `Book 6 (Ch 3, 8, 9)`।
