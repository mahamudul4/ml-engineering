enum BookPart {
  foundations(
    'foundations',
    1,
    5,
    'ML Foundations',
    'ML Foundations',
    'Python, গণিত, Statistics ও Data Preparation দিয়ে শক্ত ভিত্তি।',
    'ML সমস্যাকে সাজানো, Python Engineering, Linear Algebra, Calculus, Probability ও Data Preparation।',
    'সাধারণ Arithmetic জানলেই এই বইয়ের Chapter 1 থেকে শুরু করতে পারবেন।',
    'Prediction-এর সময় কোন Feature পাওয়া যাবে তা নির্ধারণ করুন এবং Leakage ছাড়া Data প্রস্তুত করুন।',
  ),
  classical(
    'classical',
    6,
    14,
    'Classical ML',
    'Classical Machine Learning',
    'Regression ও Classification থেকে Decision Trees, Ensembles এবং Time Series।',
    'Linear Regression, Classification, Evaluation, Decision Trees, Ensembles, SVM/kNN/NB, Clustering ও Time Series।',
    'Book 1 (ML Foundations)-এর Python, Statistics ও Data Preparation ধারণা।',
    'একই Validation Protocol-এ Baseline ও Candidate Model তুলনা করে সিদ্ধান্ত ব্যাখ্যা করুন।',
  ),
  deepLearning(
    'deep_learning',
    15,
    23,
    'Deep Learning & RL',
    'Deep Learning & RL',
    'PyTorch Tensors ও Backpropagation থেকে CNN, Transformers, RL এবং GPU Systems।',
    'Tensors, Autograd, Neural Networks, Reliable Training, Vision CNNs, Sequence Models, Transformers, RL এবং GPU Systems/LLM Serving।',
    'Book 1 (Python, Gradients) এবং Book 2-এর Regression, Classification ও Evaluation (Chapters 1–3)।',
    'নিজে Training Loop লিখুন, Gradient ও Mask যাচাই করুন এবং GPU Memory ও Roofline সীমা বিশ্লেষণ করুন।',
  ),
  llm(
    'llm',
    24,
    36,
    'LLMs & GenAI',
    'LLMs, RAG & Generative AI',
    'Tokenization, RAG, Fine-tuning, Evaluation, Interpretability, RLVR Agents, VLMs/GNNs ও Recursive Self-Improvement।',
    'Language Modeling, Semantic Retrieval, RAG, LoRA/DPO, Benchmarks, Interpretability, VAE/GAN, Diffusion, RLVR/GRPO Agents, VLMs/GNNs এবং Recursive Self-Improvement (RSI) & Self-Play।',
    'Book 3 (Deep Learning & RL)-এর Attention & Transformers (Chapter 6), RL (Chapter 8) এবং GPU Systems (Chapter 9)।',
    'একটি RAG, Reasoning LLM, Multimodal/Graph বা Recursive Self-Improvement সিস্টেমের ব্যর্থতা চিহ্নিত করুন এবং নির্ভরযোগ্য Evaluation Rubric তৈরি করুন।',
  ),
  recommender(
    'recsys',
    37,
    42,
    'Recommender Systems',
    'Recommender Systems',
    'Candidate Retrieval, Matrix Factorization, Deep Ranking, Ads Auction এবং DLRM/DCN-v2/MMoE।',
    'Collaborative Filtering, Matrix Factorization, Two-Tower ও Deep Ranking, Off-policy Evaluation, RecSys Capstone এবং Industrial Ads/Feed Ranking।',
    'Book 1 (Statistics), Book 2 (Evaluation); Deep Ranking-এর জন্য Book 4 Chapter 2 (Embeddings) ও Book 3 Chapter 8 (RL/Bandits)।',
    'Temporal Split মেনে Retrieval, Multi-Task Ranking, Ads Auction ও Calibration আলাদাভাবে মাপুন এবং Exposure Bias বিশ্লেষণ করুন।',
  ),
  systems(
    'systems',
    43,
    51,
    'ML Systems & Interviews',
    'ML Systems, MLOps & Interviews',
    'Feature Systems, MLOps, Experimentation, ৪৫-মিনিট FAANG System Design, Scratch ML Coding ও L5+ Behavioral।',
    'Point-in-time Feature Systems, MLOps, A/B Experimentation, ৪৫-মিনিট FAANG System Design, Advanced DSA ও Scratch ML Coding এবং Senior (L5+) Behavioral।',
    'Book 1 (Data Preparation), Book 2 (Evaluation) এবং অন্তত একটি পূর্ণাঙ্গ ML, LLM বা RecSys বইয়ের প্রজেক্ট।',
    'Point-in-time Feature Contract, ৪৫-মিনিট System Design Tradeoff, Scratch ML কোডিং এবং STAR + Counterfactual Impact স্পষ্টভাবে তুলে ধরুন।',
  );

  const BookPart(
    this.id,
    this.firstStep,
    this.lastStep,
    this.shortTitle,
    this.title,
    this.subtitle,
    this.learn,
    this.prerequisites,
    this.checkpoint,
  );

  final String id;
  final int firstStep, lastStep;
  final String shortTitle, title, subtitle, learn, prerequisites, checkpoint;

  int get number => index + 1;
  int get chapterCount => lastStep - firstStep + 1;
  String get label => 'Book $number · $title';
  bool containsStep(int step) => step >= firstStep && step <= lastStep;
  int chapterNumberFor(int step) => step - firstStep + 1;
  String serialFor(int step) => 'Chapter ${chapterNumberFor(step)}';

  static BookPart? forStep(int step) {
    for (final part in values) {
      if (part.containsStep(step)) return part;
    }
    return null;
  }

  static BookPart? byId(String id) {
    for (final part in values) {
      if (part.id == id) return part;
    }
    return null;
  }
}
