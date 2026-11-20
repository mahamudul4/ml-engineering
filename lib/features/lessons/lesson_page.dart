import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../models/curriculum.dart';
import '../../state/learning_controller.dart';
import '../../ui/code_block.dart';
import '../../ui/rich_prose.dart';
import '../../ui/theme.dart';

export '../../ui/code_block.dart';
import '../regression/regression_lab.dart';
import '../regression/advanced_regression_labs.dart';
import '../regression/polynomial_lab.dart';
import '../classification/classification_labs.dart';
import '../preparation/preparation_labs.dart';
import '../evaluation/evaluation_labs.dart';
import '../python/python_labs.dart';
import '../mathematics/math_labs.dart';
import '../statistics/statistics_labs.dart';
import '../trees/tree_labs.dart';
import '../ensembles/ensemble_labs.dart';
import '../classical/classical_labs.dart';
import '../unsupervised/unsupervised_labs.dart';
import '../temporal/temporal_labs.dart';
import '../capstone/capstone_labs.dart';
import '../tensors/tensor_labs.dart';
import '../neural/neural_labs.dart';
import '../reliable/reliable_labs.dart';
import '../vision/vision_labs.dart';
import '../sequence/sequence_labs.dart';
import '../attention/attention_labs.dart';
import '../deep_capstone/deep_capstone_labs.dart';
import '../llm/llm_labs.dart';
import '../retrieval/retrieval_labs.dart';
import '../rag/rag_labs.dart';
import '../adaptation/adaptation_labs.dart';
import '../reliability/reliability_labs.dart';
import '../generative/generative_labs.dart';
import '../diffusion/diffusion_labs.dart';
import '../gen_capstone/gen_capstone_labs.dart';
import '../recommendation/recommendation_labs.dart';
import '../factorization/factor_labs.dart';
import '../deep_recommendation/deep_recommendation_labs.dart';
import '../recommendation_evaluation/evaluation_labs.dart';
import '../recommender_capstone/capstone_labs.dart';
import '../feature_systems/feature_labs.dart';
import '../mlops/mlops_labs.dart';
import '../experimentation/experiment_labs.dart';
import '../system_design/design_labs.dart';
import '../interview_practice/practice_labs.dart';
import '../final_capstone/portfolio_labs.dart';
import '../reinforcement/bellman_lab.dart';
import 'horizontal_reading_view.dart';

class LessonPage extends StatefulWidget {
  final LearningController controller;
  final Lesson lesson;
  const LessonPage({super.key, required this.controller, required this.lesson});
  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  bool saving = false;
  LearningController get c => widget.controller;
  Lesson get l => widget.lesson;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      // Keep the source chapter stable while a chapter switch closes this route.
      final chapter = c.chapters.firstWhere(
        (chapter) => chapter.lessons.any((lesson) => lesson.id == l.id),
        orElse: () => c.chapter,
      );
      final index = chapter.lessons.indexWhere((lesson) => lesson.id == l.id);
      final path = c.readingPath;
      final position = path.indexWhere((item) => item.id == chapter.id);
      final nextChapter = position >= 0 && position + 1 < path.length
          ? path[position + 1]
          : null;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '${chapter.fullLabel} · Lesson ${index + 1} of ${chapter.lessons.length}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              tooltip: c.bookmarked(l.id)
                  ? 'Remove bookmark'
                  : 'Bookmark lesson',
              onPressed: () => c.toggleBookmark(l.id).catchError((Object e) {
                if (context.mounted) showFailure(context, e);
              }),
              icon: Icon(
                c.bookmarked(l.id) ? Icons.bookmark : Icons.bookmark_border,
              ),
            ),
            IconButton(
              tooltip: 'Write a note',
              onPressed: _note,
              icon: const Icon(Icons.edit_note_rounded),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 50),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 790),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Tag(chapter.title.toUpperCase()),
                      Text(l.duration, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l.title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 15),
                  RichProse(
                    l.subtitle,
                    selectable: false,
                    style: TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontFamilyFallback: const [
                        'Manrope',
                        'NotoSansMath',
                        'NotoSans',
                      ],
                      fontSize: 16,
                      height: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  for (final block in l.blocks)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _block(block),
                    ),
                  const SizedBox(height: 18),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_note_rounded, color: forest),
                            const SizedBox(width: 9),
                            const Expanded(
                              child: Text(
                                'Your takeaway',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            TextButton(
                              onPressed: _note,
                              child: Text(
                                c.note(l.id).isEmpty
                                    ? 'Add a note'
                                    : 'Edit note',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          c.note(l.id).isEmpty
                              ? 'একটি নতুন ধারণা নিজের ভাষায় লিখুন। It helps it stick.'
                              : c.note(l.id),
                          style: const TextStyle(
                            fontFamilyFallback: ['NotoSansBengali'],
                            height: 2,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 15,
                    runSpacing: 14,
                    children: [
                      FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                setState(() => saving = true);
                                try {
                                  await c.toggleComplete(l.id);
                                } catch (e) {
                                  if (context.mounted) showFailure(context, e);
                                }
                                if (mounted) setState(() => saving = false);
                              },
                        icon: Icon(
                          c.completed(l.id) ? Icons.check_circle : Icons.check,
                        ),
                        label: Text(
                          c.completed(l.id)
                              ? 'Completed · mark unread'
                              : 'Mark lesson complete',
                        ),
                      ),
                      if (index < chapter.lessons.length - 1)
                        OutlinedButton.icon(
                          onPressed: () {
                            final next = chapter.lessons[index + 1];
                            c.visit(next.id).catchError((Object e) {
                              if (context.mounted) showFailure(context, e);
                            });
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    LessonPage(controller: c, lesson: next),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward, size: 17),
                          label: const Text('Next lesson'),
                          iconAlignment: IconAlignment.end,
                        )
                      else
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back to learning space'),
                        ),
                      if (index == chapter.lessons.length - 1 &&
                          nextChapter != null)
                        OutlinedButton.icon(
                          key: const ValueKey('next-reading-chapter'),
                          onPressed: saving
                              ? null
                              : () async {
                                  setState(() => saving = true);
                                  try {
                                    await c.selectChapter(nextChapter.id);
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (error) {
                                    if (context.mounted) {
                                      showFailure(context, error);
                                    }
                                  }
                                  if (mounted) setState(() => saving = false);
                                },
                          icon: const Icon(Icons.route_outlined),
                          label: Text(
                            nextChapter.bookVolume == chapter.bookVolume
                                ? 'পরের অধ্যায় · ${nextChapter.label} (${nextChapter.shortTitle})'
                                : 'পরের বই · ${nextChapter.fullLabel}',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Your progress, notes, and bookmarks are saved on this device.',
                    style: TextStyle(fontSize: 10, height: 1.8),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget _block(LessonBlock b) {
    if (b.type == 'bellman_lab') return const BellmanLab();
    if (b.type == 'checkpoint') {
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichProse(
              b.title,
              selectable: false,
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
                fontWeight: FontWeight.w800,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 12),
            RichProse(b.body, style: const TextStyle(height: 1.9)),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('চেষ্টা শেষে উত্তর দেখুন'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: RichProse(
                    b.solution ?? '',
                    style: const TextStyle(height: 1.9),
                  ),
                ),
                const SizedBox(height: 12),
                if (b.reference != null)
                  SelectableText(
                    'Primary reference (optional): ${b.reference}',
                    style: const TextStyle(fontSize: 11, height: 1.8),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    if ([
      'polynomial_lab',
      'classification_lab',
      'threshold_lab',
      'preprocessing_lab',
      'encoding_lab',
      'fold_lab',
      'bootstrap_lab',
      'broadcasting_lab',
      'iterator_lab',
      'projection_lab',
      'curvature_lab',
      'bayes_lab',
      'coverage_lab',
      'tree_split_lab',
      'tree_pruning_lab',
      'bagging_lab',
      'boosting_lab',
      'svm_lab',
      'knn_lab',
      'naive_bayes_lab',
      'kmeans_lab',
      'density_lab',
      'pca_lab',
      'anomaly_lab',
      'forecast_lab',
      'backtest_lab',
      'experiment_lab',
      'decision_lab',
      'pipeline_lab',
      'tensor_layout_lab',
      'tensor_broadcast_lab',
      'autograd_lab',
      'neural_forward_lab',
      'neural_backprop_lab',
      'neural_training_lab',
      'optimizer_state_lab',
      'normalization_state_lab',
      'resume_state_lab',
      'vision_convolution_lab',
      'vision_pooling_lab',
      'vision_transfer_lab',
      'sequence_recurrent_lab',
      'sequence_padding_lab',
      'sequence_forecast_lab',
      'attention_weights_lab',
      'attention_mask_lab',
      'transformer_block_lab',
      'deep_experiment_lab',
      'deep_policy_lab',
      'deep_artifact_lab',
      'llm_tokenizer_lab',
      'llm_objective_lab',
      'llm_decoding_lab',
      'embedding_geometry_lab',
      'semantic_search_lab',
      'retrieval_evaluation_lab',
      'rag_chunk_lab',
      'rag_pipeline_lab',
      'rag_evidence_audit_lab',
      'adaptation_mask_lab',
      'adaptation_lora_lab',
      'adaptation_audit_lab',
      'portfolio_evidence',
      'portfolio_audit',
      'portfolio_mock',
      'interview_topk',
      'interview_sql',
      'interview_metrics',
      'design_architecture',
      'design_review_policy',
      'design_failure',
      'causal_trial',
      'causal_design',
      'causal_observational',
      'mlops_release',
      'mlops_monitor',
      'mlops_incident',
      'feature_point_in_time',
      'feature_replay',
      'feature_consistency',
      'capstone_retrieval',
      'capstone_evaluation',
      'capstone_serving',
      'recommendation_paired',
      'recommendation_diversity',
      'recommendation_exposure',
      'deep_retrieval',
      'deep_batch',
      'deep_audit',
      'factor_workbench',
      'factor_als',
      'factor_ranking',
      'recommendation_feedback',
      'recommendation_workbench',
      'recommendation_evaluation',
      'gen_capstone_workbench',
      'gen_capstone_score',
      'gen_capstone_release',
      'diffusion_noise_lab',
      'diffusion_sampling_lab',
      'diffusion_alignment_lab',
      'generative_vae_lab',
      'generative_latent_lab',
      'generative_gan_lab',
      'reliability_score_lab',
      'reliability_risk_lab',
      'reliability_serving_lab',
    ].contains(b.type)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichProse(
            b.body,
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
              height: 2,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          switch (b.type) {
            'polynomial_lab' => const PolynomialLab(),
            'classification_lab' => const ClassificationLab(),
            'preprocessing_lab' => const PreprocessingLab(),
            'encoding_lab' => const EncodingLab(),
            'fold_lab' => const FoldLab(),
            'bootstrap_lab' => const BootstrapLab(),
            'broadcasting_lab' => const BroadcastingLab(),
            'iterator_lab' => const IteratorLab(),
            'projection_lab' => const ProjectionLab(),
            'curvature_lab' => const CurvatureLab(),
            'bayes_lab' => const BayesLab(),
            'coverage_lab' => const CoverageLab(),
            'tree_split_lab' => const SplitLab(),
            'tree_pruning_lab' => const PruningLab(),
            'bagging_lab' => const BaggingLab(),
            'boosting_lab' => const BoostingLab(),
            'svm_lab' => const SvmLab(),
            'knn_lab' => const KnnLab(),
            'naive_bayes_lab' => const NaiveBayesLab(),
            'kmeans_lab' => const KMeansLab(),
            'density_lab' => const DensityLab(),
            'pca_lab' => const PcaLab(),
            'anomaly_lab' => const AnomalyLab(),
            'forecast_lab' => const ForecastLab(),
            'backtest_lab' => const BacktestLab(),
            'experiment_lab' => const ExperimentLab(),
            'decision_lab' => const DecisionLab(),
            'pipeline_lab' => const PipelineLab(),
            'tensor_layout_lab' => const TensorLayoutLab(),
            'tensor_broadcast_lab' => const BroadcastLab(),
            'autograd_lab' => const AutogradLab(),
            'neural_forward_lab' => const ForwardLab(),
            'neural_backprop_lab' => const BackpropLab(),
            'neural_training_lab' => const TrainingLab(),
            'optimizer_state_lab' => const OptimizerLab(),
            'normalization_state_lab' => const NormalizationLab(),
            'resume_state_lab' => const ResumeLab(),
            'vision_convolution_lab' => const ConvolutionLab(),
            'vision_pooling_lab' => const PoolingLab(),
            'vision_transfer_lab' => const TransferLab(),
            'sequence_recurrent_lab' => const RecurrentLab(),
            'sequence_padding_lab' => const PaddingLab(),
            'sequence_forecast_lab' => const SequenceForecastLab(),
            'attention_weights_lab' => const AttentionLab(),
            'attention_mask_lab' => const AttentionMaskLab(),
            'transformer_block_lab' => const TransformerBlockLab(),
            'deep_experiment_lab' => const DeepExperimentLab(),
            'deep_policy_lab' => const DeepPolicyLab(),
            'deep_artifact_lab' => const DeepArtifactLab(),
            'llm_tokenizer_lab' => const TokenizerLab(),
            'llm_objective_lab' => const LanguageObjectiveLab(),
            'llm_decoding_lab' => const LLMDecodingLab(),
            'embedding_geometry_lab' => const EmbeddingGeometryLab(),
            'semantic_search_lab' => const SemanticSearchLab(),
            'retrieval_evaluation_lab' => const RetrievalEvaluationLab(),
            'rag_chunk_lab' => const RAGChunkLab(),
            'rag_pipeline_lab' => const RAGPipelineLab(),
            'rag_evidence_audit_lab' => const RAGEvidenceAuditLab(),
            'adaptation_mask_lab' => const ResponseMaskLab(),
            'adaptation_lora_lab' => const LoRAUpdateLab(),
            'adaptation_audit_lab' => const AdaptationAuditLab(),
            'portfolio_evidence' => const PortfolioEvidenceLab(),
            'portfolio_audit' => const PortfolioAuditLab(),
            'portfolio_mock' => MockDefenseLab(controller: c),
            'interview_topk' => const TopKPracticeLab(),
            'interview_sql' => const SqlInterviewLab(),
            'interview_metrics' => const MetricDebugLab(),
            'design_architecture' => const ArchitectureCapacityLab(),
            'design_review_policy' => const SelectiveReviewLab(),
            'design_failure' => const CaseFailureLab(),
            'causal_trial' => const TrialInferenceLab(),
            'causal_design' => const ExperimentDesignLab(),
            'causal_observational' => const ObservationalAuditLab(),
            'mlops_release' => const ReleaseRoutingLab(),
            'mlops_monitor' => const MonitoringDriftLab(),
            'mlops_incident' => const SLOIncidentLab(),
            'feature_point_in_time' => const PointInTimeFeatureLab(),
            'feature_replay' => const PipelineReplayLab(),
            'feature_consistency' => const FeatureConsistencyLab(),
            'capstone_retrieval' => const CapstoneRetrievalLab(),
            'capstone_evaluation' => const CapstoneEvaluationLab(),
            'capstone_serving' => const CapstoneServingLab(),
            'recommendation_paired' => const PairedEvaluationLab(),
            'recommendation_diversity' => const DiversityRerankingLab(),
            'recommendation_exposure' => const ExposureExperimentLab(),
            'deep_retrieval' => const DeepRetrievalLab(),
            'deep_batch' => const ContrastiveBatchLab(),
            'deep_audit' => const DeepRankingAuditLab(),
            'factor_workbench' => const FactorWorkbench(),
            'factor_als' => const ALSUpdateLab(),
            'factor_ranking' => const RankingLossLab(),
            'recommendation_feedback' => const FeedbackBaselineLab(),
            'recommendation_workbench' => const RecommendationWorkbench(),
            'recommendation_evaluation' => const RecommendationEvaluationLab(),
            'gen_capstone_workbench' => const EvidenceWorkbench(),
            'gen_capstone_score' => const CapstoneScorecard(),
            'gen_capstone_release' => const CapstoneReleaseAudit(),
            'diffusion_noise_lab' => const ForwardNoiseLab(),
            'diffusion_sampling_lab' => const ReverseSamplingLab(),
            'diffusion_alignment_lab' => const MultimodalAlignmentLab(),
            'generative_vae_lab' => const VaeObjectiveLab(),
            'generative_latent_lab' => const LatentSpaceLab(),
            'generative_gan_lab' => const GanGameLab(),
            'reliability_score_lab' => const EvaluationScoreLab(),
            'reliability_risk_lab' => const SelectiveRiskLab(),
            'reliability_serving_lab' => const ServingReplayLab(),
            _ => const ThresholdLab(),
          },
        ],
      );
    }
    if (b.type == 'optimization_lab' || b.type == 'prediction_lab') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichProse(
            b.body,
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
              height: 2,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          if (b.type == 'optimization_lab')
            const OptimizationLab()
          else
            const MultipleFeatureLab(),
        ],
      );
    }
    if (b.type == 'lab') {
      return Column(
        children: [
          RichProse(
            b.body,
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
              height: 2,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          const RegressionLab(),
        ],
      );
    }
    if (b.type == 'code') return CodeBlock(code: b.body, title: b.title);
    if (b.type == 'math') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: HorizontalReadingView(
          hint: 'পুরো সমীকরণ দেখতে ডানে-বাঁয়ে সরান।',
          child: Math.tex(
            b.body,
            textStyle: TextStyle(
              fontSize: 19,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      );
    }
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (b.title.isNotEmpty) ...[
          RichProse(
            b.title,
            selectable: false,
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 12),
        ],
        RichProse(
          b.body,
          style: TextStyle(
            fontFamily: 'NotoSansBengali',
            fontFamilyFallback: const ['Manrope', 'NotoSansMath', 'NotoSans'],
            fontSize: 14,
            height: 2.1,
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: .90),
          ),
        ),
      ],
    );
    return b.type == 'callout'
        ? Panel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(child: copy),
              ],
            ),
          )
        : copy;
  }

  Future<void> _note() async {
    await showDialog<void>(
      context: context,
      builder: (_) => NoteDialog(controller: c, lesson: l),
    );
  }
}

class NoteDialog extends StatefulWidget {
  final LearningController controller;
  final Lesson lesson;
  const NoteDialog({super.key, required this.controller, required this.lesson});
  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late final text = TextEditingController(
    text: widget.controller.note(widget.lesson.id),
  );
  bool saving = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(
      'A note to your future self',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    ),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.lesson.title, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 18),
          TextField(
            key: const Key('note-field'),
            controller: text,
            minLines: 5,
            maxLines: 8,
            maxLength: 10000,
            style: const TextStyle(
              fontFamilyFallback: ['NotoSansBengali'],
              height: 1.9,
            ),
            decoration: const InputDecoration(hintText: 'আজ আমি শিখলাম…'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Saved locally when you tap Save note.',
            style: TextStyle(fontSize: 10),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                setState(() => saving = true);
                try {
                  await widget.controller.saveNote(widget.lesson.id, text.text);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) showFailure(context, e);
                  if (mounted) setState(() => saving = false);
                }
              },
        child: Text(saving ? 'Saving…' : 'Save note'),
      ),
    ],
  );
}
