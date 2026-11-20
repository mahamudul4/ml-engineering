// Run: flutter test tool/capture_preview_test.dart
// Captures packaged fonts (including KaTeX) and the host monospace fallback.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/classification/classification_labs.dart';
import 'package:ml_path/features/regression/polynomial_lab.dart';
import 'package:ml_path/features/preparation/preparation_labs.dart';
import 'package:ml_path/features/evaluation/evaluation_labs.dart';
import 'package:ml_path/features/python/python_labs.dart';
import 'package:ml_path/features/mathematics/math_labs.dart';
import 'package:ml_path/features/statistics/statistics_labs.dart';
import 'package:ml_path/features/trees/tree_labs.dart';
import 'package:ml_path/features/trees/tree_model.dart';
import 'package:ml_path/features/ensembles/ensemble_labs.dart';
import 'package:ml_path/features/ensembles/ensemble_model.dart';
import 'package:ml_path/features/classical/classical_labs.dart';
import 'package:ml_path/features/classical/classical_model.dart';
import 'package:ml_path/features/unsupervised/unsupervised_labs.dart';
import 'package:ml_path/features/unsupervised/unsupervised_model.dart';
import 'package:ml_path/features/temporal/temporal_labs.dart';
import 'package:ml_path/features/temporal/temporal_model.dart';
import 'package:ml_path/features/capstone/capstone_labs.dart';
import 'package:ml_path/features/capstone/capstone_model.dart';
import 'package:ml_path/features/tensors/tensor_labs.dart';
import 'package:ml_path/features/tensors/tensor_model.dart';
import 'package:ml_path/features/neural/neural_labs.dart';
import 'package:ml_path/features/neural/neural_model.dart';
import 'package:ml_path/features/reliable/reliable_labs.dart';
import 'package:ml_path/features/reliable/reliable_model.dart';
import 'package:ml_path/features/vision/vision_labs.dart';
import 'package:ml_path/features/vision/vision_model.dart';
import 'package:ml_path/features/sequence/sequence_labs.dart';
import 'package:ml_path/features/sequence/sequence_model.dart';
import 'package:ml_path/features/attention/attention_labs.dart';
import 'package:ml_path/features/attention/attention_model.dart';
import 'package:ml_path/features/deep_capstone/deep_capstone_labs.dart';
import 'package:ml_path/features/deep_capstone/deep_capstone_model.dart';
import 'package:ml_path/features/llm/llm_labs.dart';
import 'package:ml_path/features/llm/llm_model.dart';
import 'package:ml_path/features/retrieval/retrieval_labs.dart';
import 'package:ml_path/features/retrieval/retrieval_model.dart';
import 'package:ml_path/features/rag/rag_labs.dart';
import 'package:ml_path/features/rag/rag_model.dart';
import 'package:ml_path/features/adaptation/adaptation_labs.dart';
import 'package:ml_path/features/adaptation/adaptation_model.dart';
import 'package:ml_path/features/reliability/reliability_labs.dart';
import 'package:ml_path/features/reliability/reliability_model.dart';
import 'package:ml_path/features/generative/generative_labs.dart';
import 'package:ml_path/features/generative/generative_model.dart';
import 'package:ml_path/features/diffusion/diffusion_labs.dart';
import 'package:ml_path/features/diffusion/diffusion_model.dart';
import 'package:ml_path/features/gen_capstone/gen_capstone_labs.dart';
import 'package:ml_path/features/gen_capstone/gen_capstone_model.dart';
import 'package:ml_path/features/recommendation/recommendation_labs.dart';
import 'package:ml_path/features/recommendation/recommendation_model.dart';
import 'package:ml_path/features/factorization/factor_labs.dart';
import 'package:ml_path/features/factorization/factor_model.dart';
import 'package:ml_path/features/deep_recommendation/deep_recommendation_labs.dart';
import 'package:ml_path/features/deep_recommendation/deep_recommendation_model.dart';
import 'package:ml_path/features/recommendation_evaluation/evaluation_labs.dart';
import 'package:ml_path/features/recommendation_evaluation/evaluation_model.dart';
import 'package:ml_path/features/recommender_capstone/capstone_labs.dart';
import 'package:ml_path/features/recommender_capstone/capstone_model.dart';
import 'package:ml_path/features/feature_systems/feature_labs.dart';
import 'package:ml_path/features/feature_systems/feature_model.dart';
import 'package:ml_path/features/mlops/mlops_labs.dart';
import 'package:ml_path/features/mlops/mlops_model.dart';
import 'package:ml_path/features/experimentation/experiment_labs.dart';
import 'package:ml_path/features/experimentation/experiment_model.dart';
import 'package:ml_path/features/system_design/design_labs.dart';
import 'package:ml_path/features/system_design/design_model.dart';
import 'package:ml_path/features/interview_practice/practice_labs.dart';
import 'package:ml_path/features/interview_practice/practice_model.dart';
import 'package:ml_path/features/final_capstone/portfolio_labs.dart';
import 'package:ml_path/features/final_capstone/portfolio_model.dart';
import 'package:ml_path/features/lessons/lesson_page.dart';
import 'package:ml_path/ui/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late LearningRepository repo;
  late LearningController c;
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in manifest) {
      final loader = FontLoader(family['family'] as String);
      for (final font in family['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    // Widget tests otherwise substitute Ahem for the system 'monospace' family.
    // Use the installed host font for this preview only; no font is redistributed.
    for (final path in [
      'C:/Windows/Fonts/consola.ttf',
      '/System/Library/Fonts/Menlo.ttc',
      '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
    ]) {
      final font = File(path);
      if (await font.exists()) {
        final bytes = await font.readAsBytes();
        await (FontLoader(
          'monospace',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        break;
      }
    }
    repo = await LearningRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    c = LearningController(repo);
    await c.load();
    await c.selectChapter('chapter_40');
    await TreeAssets.load();
    await EnsembleAssets.load();
    await ClassicalAssets.load();
    await UnsupervisedAssets.load();
    await TemporalAssets.load();
    await CapstoneAssets.load();
    await TensorAssets.load();
    await NeuralAssets.load();
    await ReliableAssets.load();
    await VisionAssets.load();
    await SequenceAssets.load();
    await AttentionAssets.load();
    await DeepCapstoneAssets.load();
    await LLMAssets.load();
    await RetrievalAssets.load();
    await RAGAssets.load();
    await AdaptationAssets.load();
    await ReliabilityAssets.load();
    await GenerativeAssets.load();
    await DiffusionAssets.load();
    await GenCapstoneAssets.load();
    await RecommendationAssets.load();
    await FactorAssets.load();
    await DeepRecommendationAssets.load();
    await RecommendationEvaluationAssets.load();
    await RecommenderCapstoneAssets.load();
    await FeatureSystemAssets.load();
    await MLOpsAssets.load();
    await ExperimentAssets.load();
    await DesignAssets.load();
    await PracticeAssets.load();
    await PortfolioAssets.load();
  });
  tearDownAll(() async {
    c.dispose();
    await repo.close();
  });
  testWidgets('capture responsive learning space', (tester) async {
    for (final variant in <(String, Size, Widget)>[
      (
        'chapter-40-desktop',
        const Size(1440, 1100),
        LearningApp(controller: c),
      ),
      ('chapter-40-mobile', const Size(390, 844), LearningApp(controller: c)),
      (
        'chapter-40-derivation',
        const Size(900, 1500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: LessonPage(
            controller: c,
            lesson: c.chapter.lessons.firstWhere(
              (l) => l.id == 'ch40_classical',
            ),
          ),
        ),
      ),
      (
        'portfolio-evidence',
        const Size(800, 2100),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(child: const PortfolioEvidenceLab()),
          ),
        ),
      ),
      (
        'portfolio-audit',
        const Size(800, 2500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(child: const PortfolioAuditLab()),
          ),
        ),
      ),
      (
        'portfolio-mock',
        const Size(800, 3000),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(child: MockDefenseLab(controller: c)),
          ),
        ),
      ),
      (
        'portfolio-mock-dark',
        const Size(390, 4200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(child: MockDefenseLab(controller: c)),
          ),
        ),
      ),
      (
        'interview-topk',
        const Size(800, 2500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: TopKPracticeLab()),
          ),
        ),
      ),
      (
        'interview-sql',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: SqlInterviewLab()),
          ),
        ),
      ),
      (
        'interview-debug',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: MetricDebugLab()),
          ),
        ),
      ),
      (
        'interview-debug-dark',
        const Size(390, 2800),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: MetricDebugLab()),
          ),
        ),
      ),
      (
        'system-architecture',
        const Size(800, 3200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ArchitectureCapacityLab()),
          ),
        ),
      ),
      (
        'system-review',
        const Size(800, 2700),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: SelectiveReviewLab()),
          ),
        ),
      ),
      (
        'system-failure',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: CaseFailureLab()),
          ),
        ),
      ),
      (
        'system-failure-dark',
        const Size(390, 3000),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: CaseFailureLab()),
          ),
        ),
      ),
      (
        'experiment-trial',
        const Size(800, 2100),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: TrialInferenceLab()),
          ),
        ),
      ),
      (
        'experiment-design',
        const Size(800, 3000),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ExperimentDesignLab()),
          ),
        ),
      ),
      (
        'experiment-observational',
        const Size(800, 2500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ObservationalAuditLab()),
          ),
        ),
      ),
      (
        'experiment-observational-dark',
        const Size(390, 4000),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: ObservationalAuditLab()),
          ),
        ),
      ),
      (
        'mlops-release',
        const Size(800, 3300),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ReleaseRoutingLab()),
          ),
        ),
      ),
      (
        'mlops-monitoring',
        const Size(800, 3500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: MonitoringDriftLab()),
          ),
        ),
      ),
      (
        'mlops-incident',
        const Size(800, 3000),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: SLOIncidentLab()),
          ),
        ),
      ),
      (
        'mlops-incident-dark',
        const Size(390, 4200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: SLOIncidentLab()),
          ),
        ),
      ),
      (
        'feature-point-in-time',
        const Size(800, 3000),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: PointInTimeFeatureLab()),
          ),
        ),
      ),
      (
        'feature-replay',
        const Size(800, 2500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: PipelineReplayLab()),
          ),
        ),
      ),
      (
        'feature-consistency',
        const Size(800, 2500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: FeatureConsistencyLab()),
          ),
        ),
      ),
      (
        'feature-consistency-dark',
        const Size(390, 3500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: FeatureConsistencyLab()),
          ),
        ),
      ),
      (
        'capstone-retrieval',
        const Size(800, 3500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: CapstoneRetrievalLab()),
          ),
        ),
      ),
      (
        'capstone-evaluation',
        const Size(800, 3300),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: CapstoneEvaluationLab()),
          ),
        ),
      ),
      (
        'capstone-serving',
        const Size(800, 2700),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: CapstoneServingLab()),
          ),
        ),
      ),
      (
        'capstone-serving-dark',
        const Size(390, 3700),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: CapstoneServingLab()),
          ),
        ),
      ),
      (
        'evaluation-paired',
        const Size(800, 3400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: PairedEvaluationLab()),
          ),
        ),
      ),
      (
        'evaluation-diversity',
        const Size(800, 4200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: DiversityRerankingLab()),
          ),
        ),
      ),
      (
        'evaluation-exposure',
        const Size(800, 3200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ExposureExperimentLab()),
          ),
        ),
      ),
      (
        'evaluation-exposure-dark',
        const Size(390, 4400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: ExposureExperimentLab()),
          ),
        ),
      ),
      (
        'deep-retrieval',
        const Size(800, 4100),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: DeepRetrievalLab()),
          ),
        ),
      ),
      (
        'deep-batch',
        const Size(800, 2800),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ContrastiveBatchLab()),
          ),
        ),
      ),
      (
        'deep-audit',
        const Size(800, 3600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: DeepRankingAuditLab()),
          ),
        ),
      ),
      (
        'deep-audit-dark',
        const Size(390, 4400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: DeepRankingAuditLab()),
          ),
        ),
      ),
      (
        'factor-fm',
        const Size(800, 3400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: FactorWorkbench()),
          ),
        ),
      ),
      (
        'factor-workbench',
        const Size(800, 3400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: FactorWorkbench()),
          ),
        ),
      ),
      (
        'factor-als',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ALSUpdateLab()),
          ),
        ),
      ),
      (
        'factor-ranking',
        const Size(800, 3400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: RankingLossLab()),
          ),
        ),
      ),
      (
        'factor-ranking-dark',
        const Size(390, 4200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: RankingLossLab()),
          ),
        ),
      ),
      (
        'recommendation-feedback',
        const Size(800, 2300),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: FeedbackBaselineLab()),
          ),
        ),
      ),
      (
        'recommendation-workbench',
        const Size(800, 4200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: RecommendationWorkbench()),
          ),
        ),
      ),
      (
        'recommendation-evaluation',
        const Size(800, 3200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: RecommendationEvaluationLab()),
          ),
        ),
      ),
      (
        'recommendation-evaluation-dark',
        const Size(390, 3800),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: RecommendationEvaluationLab()),
          ),
        ),
      ),
      (
        'capstone-workbench',
        const Size(800, 3200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: EvidenceWorkbench()),
          ),
        ),
      ),
      (
        'capstone-score',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: CapstoneScorecard()),
          ),
        ),
      ),
      (
        'capstone-audit',
        const Size(800, 2300),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: CapstoneReleaseAudit()),
          ),
        ),
      ),
      (
        'capstone-score-dark',
        const Size(390, 2800),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: CapstoneScorecard()),
          ),
        ),
      ),
      (
        'diffusion-noise',
        const Size(800, 1900),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ForwardNoiseLab()),
          ),
        ),
      ),
      (
        'diffusion-sampling',
        const Size(800, 1900),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ReverseSamplingLab()),
          ),
        ),
      ),
      (
        'diffusion-alignment',
        const Size(800, 2300),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: MultimodalAlignmentLab()),
          ),
        ),
      ),
      (
        'diffusion-sampling-dark',
        const Size(390, 3200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: ReverseSamplingLab()),
          ),
        ),
      ),
      (
        'generative-vae',
        const Size(800, 2600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: VaeObjectiveLab()),
          ),
        ),
      ),
      (
        'generative-latent',
        const Size(800, 2400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: LatentSpaceLab()),
          ),
        ),
      ),
      (
        'generative-gan',
        const Size(800, 2800),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: GanGameLab()),
          ),
        ),
      ),
      (
        'generative-gan-dark',
        const Size(390, 3600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: GanGameLab()),
          ),
        ),
      ),
      (
        'reliability-score',
        const Size(800, 2600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: EvaluationScoreLab()),
          ),
        ),
      ),
      (
        'reliability-risk',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: SelectiveRiskLab()),
          ),
        ),
      ),
      (
        'reliability-serving',
        const Size(800, 2800),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ServingReplayLab()),
          ),
        ),
      ),
      (
        'reliability-serving-dark',
        const Size(390, 3600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: ServingReplayLab()),
          ),
        ),
      ),
      (
        'adaptation-mask',
        const Size(800, 2600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ResponseMaskLab()),
          ),
        ),
      ),
      (
        'adaptation-lora',
        const Size(800, 2600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: LoRAUpdateLab()),
          ),
        ),
      ),
      (
        'adaptation-audit',
        const Size(800, 3000),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: AdaptationAuditLab()),
          ),
        ),
      ),
      (
        'adaptation-audit-dark',
        const Size(390, 3600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: AdaptationAuditLab()),
          ),
        ),
      ),
      (
        'chapter-24-derivation',
        const Size(900, 1500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: LessonPage(
            controller: c,
            lesson: c.chapters[23].lessons.firstWhere(
              (l) => l.id == 'ch24_budget',
            ),
          ),
        ),
      ),
      (
        'rag-chunks',
        const Size(800, 3600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: RAGChunkLab()),
          ),
        ),
      ),
      (
        'rag-pipeline',
        const Size(800, 3600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: RAGPipelineLab()),
          ),
        ),
      ),
      (
        'rag-audit',
        const Size(800, 3600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: RAGEvidenceAuditLab()),
          ),
        ),
      ),
      (
        'rag-pipeline-dark',
        const Size(390, 4200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: RAGPipelineLab()),
          ),
        ),
      ),
      (
        'retrieval-geometry',
        const Size(800, 2300),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: EmbeddingGeometryLab()),
          ),
        ),
      ),
      (
        'retrieval-search',
        const Size(800, 2800),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: SemanticSearchLab()),
          ),
        ),
      ),
      (
        'retrieval-audit',
        const Size(800, 3000),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: RetrievalEvaluationLab()),
          ),
        ),
      ),
      (
        'retrieval-search-dark',
        const Size(390, 3800),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: SemanticSearchLab()),
          ),
        ),
      ),
      (
        'llm-tokenizer',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: TokenizerLab()),
          ),
        ),
      ),
      (
        'llm-objective',
        const Size(800, 2400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: LanguageObjectiveLab()),
          ),
        ),
      ),
      (
        'llm-decoding',
        const Size(800, 2600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: LLMDecodingLab()),
          ),
        ),
      ),
      (
        'llm-decoding-dark',
        const Size(390, 3600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: LLMDecodingLab()),
          ),
        ),
      ),
      (
        'deep-experiment',
        const Size(800, 2300),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: DeepExperimentLab()),
          ),
        ),
      ),
      (
        'deep-policy',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: DeepPolicyLab()),
          ),
        ),
      ),
      (
        'deep-artifact',
        const Size(800, 2600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: DeepArtifactLab()),
          ),
        ),
      ),
      (
        'deep-artifact-dark',
        const Size(390, 3500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: DeepArtifactLab()),
          ),
        ),
      ),
      (
        'attention-weights',
        const Size(800, 2000),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: AttentionLab()),
          ),
        ),
      ),
      (
        'attention-masks',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: AttentionMaskLab()),
          ),
        ),
      ),
      (
        'attention-block',
        const Size(800, 2400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: TransformerBlockLab()),
          ),
        ),
      ),
      (
        'attention-weights-dark',
        const Size(390, 3000),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: AttentionLab()),
          ),
        ),
      ),
      (
        'sequence-recurrent',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: RecurrentLab()),
          ),
        ),
      ),
      (
        'sequence-padding',
        const Size(800, 2400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: PaddingLab()),
          ),
        ),
      ),
      (
        'sequence-forecast',
        const Size(800, 3000),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: SequenceForecastLab()),
          ),
        ),
      ),
      (
        'sequence-forecast-dark',
        const Size(390, 3600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: SequenceForecastLab()),
          ),
        ),
      ),
      (
        'vision-convolution',
        const Size(800, 2500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ConvolutionLab()),
          ),
        ),
      ),
      (
        'vision-pooling',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: PoolingLab()),
          ),
        ),
      ),
      (
        'vision-transfer',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: TransferLab()),
          ),
        ),
      ),
      (
        'vision-transfer-dark',
        const Size(390, 2600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: TransferLab()),
          ),
        ),
      ),
      (
        'reliable-optimizer',
        const Size(800, 1800),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: OptimizerLab()),
          ),
        ),
      ),
      (
        'reliable-normalization',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: NormalizationLab()),
          ),
        ),
      ),
      (
        'reliable-resume',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(body: SingleChildScrollView(child: ResumeLab())),
        ),
      ),
      (
        'reliable-resume-dark',
        const Size(390, 2600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(body: SingleChildScrollView(child: ResumeLab())),
        ),
      ),
      (
        'neural-forward',
        const Size(800, 2500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ForwardLab()),
          ),
        ),
      ),
      (
        'neural-backprop',
        const Size(800, 2500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: BackpropLab()),
          ),
        ),
      ),
      (
        'neural-training',
        const Size(800, 1900),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: TrainingLab()),
          ),
        ),
      ),
      (
        'neural-training-dark',
        const Size(390, 2400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: TrainingLab()),
          ),
        ),
      ),
      (
        'tensor-layout',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: TensorLayoutLab()),
          ),
        ),
      ),
      (
        'tensor-broadcast',
        const Size(800, 1800),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: BroadcastLab()),
          ),
        ),
      ),
      (
        'tensor-autograd',
        const Size(800, 2000),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: AutogradLab()),
          ),
        ),
      ),
      (
        'tensor-autograd-dark',
        const Size(390, 2600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: AutogradLab()),
          ),
        ),
      ),
      (
        'capstone-evidence',
        const Size(800, 1500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ExperimentLab()),
          ),
        ),
      ),
      (
        'capstone-policy',
        const Size(800, 1750),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: DecisionLab()),
          ),
        ),
      ),
      (
        'capstone-pipeline',
        const Size(800, 2200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: PipelineLab()),
          ),
        ),
      ),
      (
        'capstone-policy-dark',
        const Size(390, 2100),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: DecisionLab()),
          ),
        ),
      ),
      (
        'temporal-alerts',
        const Size(800, 1500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: AnomalyLab()),
          ),
        ),
      ),
      (
        'temporal-forecast',
        const Size(800, 1650),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ForecastLab()),
          ),
        ),
      ),
      (
        'temporal-backtest',
        const Size(800, 1800),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: BacktestLab()),
          ),
        ),
      ),
      (
        'temporal-forecast-dark',
        const Size(390, 2000),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(child: ForecastLab()),
          ),
        ),
      ),
      (
        'unsupervised-kmeans',
        const Size(800, 1400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(body: SingleChildScrollView(child: KMeansLab())),
        ),
      ),
      (
        'unsupervised-density',
        const Size(800, 1550),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: DensityLab()),
          ),
        ),
      ),
      (
        'unsupervised-pca',
        const Size(800, 1750),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(body: SingleChildScrollView(child: PcaLab())),
        ),
      ),
      (
        'unsupervised-pca-dark',
        const Size(390, 1850),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: const Scaffold(body: SingleChildScrollView(child: PcaLab())),
        ),
      ),
      (
        'classical-svm',
        const Size(800, 1250),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(body: SingleChildScrollView(child: SvmLab())),
        ),
      ),
      (
        'classical-knn',
        const Size(800, 1450),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(body: SingleChildScrollView(child: KnnLab())),
        ),
      ),
      (
        'classical-bayes',
        const Size(800, 1300),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: NaiveBayesLab()),
          ),
        ),
      ),
      (
        'ensemble-bagging',
        const Size(800, 1350),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: BaggingLab()),
          ),
        ),
      ),
      (
        'ensemble-boosting',
        const Size(800, 1500),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: BoostingLab()),
          ),
        ),
      ),
      (
        'tree-split',
        const Size(800, 1450),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(body: SingleChildScrollView(child: SplitLab())),
        ),
      ),
      (
        'tree-pruning',
        const Size(800, 1300),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: PruningLab()),
          ),
        ),
      ),
      (
        'stats-bayes',
        const Size(800, 1300),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(body: SingleChildScrollView(child: BayesLab())),
        ),
      ),
      (
        'stats-coverage',
        const Size(800, 1600),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: CoverageLab()),
          ),
        ),
      ),
      (
        'math-projection',
        const Size(800, 1250),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ProjectionLab()),
          ),
        ),
      ),
      (
        'math-curvature',
        const Size(800, 1400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: CurvatureLab()),
          ),
        ),
      ),
      (
        'python-broadcasting',
        const Size(800, 1200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: BroadcastingLab()),
          ),
        ),
      ),
      (
        'python-iterator',
        const Size(800, 1100),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: IteratorLab()),
          ),
        ),
      ),
      (
        'evaluation-folds',
        const Size(800, 1150),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(body: SingleChildScrollView(child: FoldLab())),
        ),
      ),
      (
        'evaluation-bootstrap',
        const Size(800, 1400),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: BootstrapLab()),
          ),
        ),
      ),
      (
        'preprocessing',
        const Size(800, 1200),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: PreprocessingLab()),
          ),
        ),
      ),
      (
        'encoding',
        const Size(800, 1100),
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: EncodingLab()),
          ),
        ),
      ),
      (
        'classification-boundary',
        const Size(800, 1200),
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ClassificationLab()),
          ),
        ),
      ),
      (
        'classification-threshold',
        const Size(800, 1100),
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ThresholdLab()),
          ),
        ),
      ),
      (
        'regression-polynomial',
        const Size(800, 1000),
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: PolynomialLab()),
          ),
        ),
      ),
    ]) {
      if (variant.$1.startsWith('chapter-24-')) {
        await tester.runAsync(() => c.selectChapter('chapter_24'));
      } else {
        await tester.runAsync(() => c.selectChapter('chapter_40'));
      }
      tester.view.physicalSize = variant.$2;
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: variant.$3));
      await tester.pumpAndSettle();
      if (variant.$1 == 'factor-fm') {
        await tester.ensureVisible(
          find.byType(DropdownButtonFormField<String>),
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('fm').last);
        await tester.pumpAndSettle();
      }
      if (variant.$1 == 'interview-sql') {
        for (
          var i = 0;
          i < 300 && find.textContaining('SQLite returned').evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();
        expect(find.textContaining('Ratings counted: 80668'), findsOneWidget);
      }
      if (variant.$1.startsWith('portfolio-mock')) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byKey(const Key('mock-draft'))).enabled,
          isTrue,
        );
      }
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/screenshots').create(recursive: true);
        await File('build/screenshots/preview-${variant.$1}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
