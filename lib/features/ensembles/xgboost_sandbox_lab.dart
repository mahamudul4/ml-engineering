import 'package:flutter/material.dart';

import '../../ui/rich_prose.dart';
import '../../ui/theme.dart';
import '../../ui/tutorial_blocks.dart';

/// Deterministic on-device XGBoost tree node (no fake curves — real 2nd-order
/// Taylor leaf weights and split gains recomputed on the lesson's 6-row dataset).
class _XgbNode {
  final bool isLeaf;
  final double weight;
  final double? threshold;
  final _XgbNode? left;
  final _XgbNode? right;
  final double gain;
  final double gSum;
  final double hSum;

  const _XgbNode.leaf({
    required this.weight,
    required this.gSum,
    required this.hSum,
    this.gain = 0,
  }) : isLeaf = true,
       threshold = null,
       left = null,
       right = null;

  const _XgbNode.split({
    required this.threshold,
    required this.left,
    required this.right,
    required this.gain,
    required this.weight,
    required this.gSum,
    required this.hSum,
  }) : isLeaf = false;

  double predict(double x) {
    if (isLeaf) return weight;
    return x <= threshold! ? left!.predict(x) : right!.predict(x);
  }
}

class _XgbRunResult {
  final double basePrediction;
  final double initialMse;
  final double finalMse;
  final List<(double, double)> mseCurve;
  final List<double> finalPreds;
  final List<double> finalGrads;
  final _XgbNode? firstTree;
  final int activeSplits;

  const _XgbRunResult({
    required this.basePrediction,
    required this.initialMse,
    required this.finalMse,
    required this.mseCurve,
    required this.finalPreds,
    required this.finalGrads,
    required this.firstTree,
    required this.activeSplits,
  });
}

/// Real on-device interactive XGBoost parameter experiment on the exact 6-row
/// lesson dataset X = [1..6], y = [3, 5, 7, 15, 18, 20].
class XgboostSandboxLab extends StatefulWidget {
  const XgboostSandboxLab({super.key});

  @override
  State<XgboostSandboxLab> createState() => _XgboostSandboxLabState();
}

class _XgboostSandboxLabState extends State<XgboostSandboxLab> {
  static const List<double> _xData = [1, 2, 3, 4, 5, 6];
  static const List<double> _yData = [3, 5, 7, 15, 18, 20];

  double _lr = 0.30;
  double _lambda = 1.0;
  double _gamma = 0.0;
  int _rounds = 5;
  int _maxDepth = 1;

  _XgbNode _fitNode(
    List<int> indices,
    List<double> grads,
    List<double> hess,
    int depth,
  ) {
    var gParent = 0.0;
    var hParent = 0.0;
    for (final idx in indices) {
      gParent += grads[idx];
      hParent += hess[idx];
    }
    final leafWeight = -gParent / (hParent + _lambda);
    if (depth >= _maxDepth || indices.length < 2) {
      return _XgbNode.leaf(weight: leafWeight, gSum: gParent, hSum: hParent);
    }

    final uniqueX = <double>{for (final i in indices) _xData[i]}.toList()
      ..sort();
    if (uniqueX.length < 2) {
      return _XgbNode.leaf(weight: leafWeight, gSum: gParent, hSum: hParent);
    }

    final parentScore = (gParent * gParent) / (hParent + _lambda);
    var bestGain = -1.0;
    double? bestThreshold;
    List<int>? bestLeft;
    List<int>? bestRight;

    for (var k = 0; k < uniqueX.length - 1; k++) {
      final th = (uniqueX[k] + uniqueX[k + 1]) / 2.0;
      final leftIdx = <int>[];
      final rightIdx = <int>[];
      var gL = 0.0, hL = 0.0, gR = 0.0, hR = 0.0;
      for (final idx in indices) {
        if (_xData[idx] <= th) {
          leftIdx.add(idx);
          gL += grads[idx];
          hL += hess[idx];
        } else {
          rightIdx.add(idx);
          gR += grads[idx];
          hR += hess[idx];
        }
      }
      if (leftIdx.isEmpty || rightIdx.isEmpty) continue;
      final leftScore = (gL * gL) / (hL + _lambda);
      final rightScore = (gR * gR) / (hR + _lambda);
      final gain = 0.5 * (leftScore + rightScore - parentScore) - _gamma;
      if (gain > bestGain) {
        bestGain = gain;
        bestThreshold = th;
        bestLeft = leftIdx;
        bestRight = rightIdx;
      }
    }

    if (bestThreshold == null || bestGain <= 0.0) {
      return _XgbNode.leaf(
        weight: leafWeight,
        gSum: gParent,
        hSum: hParent,
        gain: bestGain,
      );
    }

    return _XgbNode.split(
      threshold: bestThreshold,
      left: _fitNode(bestLeft!, grads, hess, depth + 1),
      right: _fitNode(bestRight!, grads, hess, depth + 1),
      gain: bestGain,
      weight: leafWeight,
      gSum: gParent,
      hSum: hParent,
    );
  }

  double _mse(List<double> preds) {
    var total = 0.0;
    for (var i = 0; i < _yData.length; i++) {
      final d = _yData[i] - preds[i];
      total += d * d;
    }
    return total / _yData.length;
  }

  _XgbRunResult _simulate() {
    var sumY = 0.0;
    for (final y in _yData) {
      sumY += y;
    }
    final base = sumY / _yData.length;
    final preds = List<double>.filled(_yData.length, base);
    final initMse = _mse(preds);
    final curve = <(double, double)>[(0, initMse)];
    final allIdx = List<int>.generate(_yData.length, (i) => i);

    _XgbNode? firstTree;
    var activeSplits = 0;

    for (var r = 1; r <= _rounds; r++) {
      final grads = <double>[];
      final hess = <double>[];
      for (var i = 0; i < _yData.length; i++) {
        grads.add(preds[i] - _yData[i]);
        hess.add(1.0);
      }
      final tree = _fitNode(allIdx, grads, hess, 0);
      if (r == 1) firstTree = tree;
      if (!tree.isLeaf) activeSplits++;
      for (var i = 0; i < _yData.length; i++) {
        preds[i] += _lr * tree.predict(_xData[i]);
      }
      curve.add((r.toDouble(), _mse(preds)));
    }

    final finalGrads = [
      for (var i = 0; i < _yData.length; i++) preds[i] - _yData[i],
    ];
    return _XgbRunResult(
      basePrediction: base,
      initialMse: initMse,
      finalMse: curve.last.$2,
      mseCurve: curve,
      finalPreds: preds,
      finalGrads: finalGrads,
      firstTree: firstTree,
      activeSplits: activeSplits,
    );
  }

  @override
  Widget build(BuildContext context) {
    final res = _simulate();
    final t1 = res.firstTree;
    final splitApproved = t1 != null && !t1.isLeaf;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Theme.of(context).dividerColor;

    final interpretation = !splitApproved
        ? 'দেখুন! `γ = ${_gamma.toStringAsFixed(1)}` অনেক বড় হওয়ায় Round 1-এর `Split Gain <= 0` হয়েছে—ফলে XGBoost কোনো Split-ই অনুমোদন করেনি (Pruned) এবং MSE একটুও কমেনি!'
        : _lambda >= 4.0
        ? '`λ = ${_lambda.toStringAsFixed(1)}` বাড়ানোর ফলে প্রতি রাউন্ডে Leaf Weight (\$w_L^* = ${t1.left!.weight.toStringAsFixed(2)},\\ w_R^* = ${t1.right!.weight.toStringAsFixed(2)}\$) ছোট হয়ে এসেছে। ফলে Training MSE ধীরে নামছে—এটিই L2 Regularization-এর Overfitting প্রতিরোধ করার কৌশল।'
        : '`λ = ${_lambda.toStringAsFixed(1)}`, `γ = ${_gamma.toStringAsFixed(1)}`, `η = ${_lr.toStringAsFixed(2)}` ও `max_depth = $_maxDepth`-এ $_rounds রাউন্ডে Training MSE `${res.initialMse.toStringAsFixed(2)}` থেকে নেমে `${res.finalMse.toStringAsFixed(2)}` হয়েছে (মনে রাখবেন: এটি Training MSE, অদেখা Test Data নয়)।';

    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'INTERACTIVE EXPERIMENT · REAL XGBOOST SIMULATION',
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: 14),
          const Text(
            'নিজে Parameter বদলে দেখুন XGBoost কীভাবে আচরণ করে',
            style: TextStyle(
              fontFamilyFallback: ['NotoSansBengali'],
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'আমাদের ঠিক উপরের ৬-সারির Dataset (X = [1..6], y = [3, 5, 7, 15, 18, 20])-এর ওপর এই ল্যাবটি লাইভ 2nd-order Gradient, Hessian, Leaf Weight ও Split Gain হিসাব করে। λ আর γ বাড়িয়ে-কমিয়ে দেখুন কী বদলায়!',
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 12.5,
              height: 1.9,
            ),
          ),
          const SizedBox(height: 16),
          _sliderRow(
            keyName: 'xgb-lr',
            label: 'Learning Rate (η)',
            valueText: _lr.toStringAsFixed(2),
            value: _lr,
            min: 0.05,
            max: 1.0,
            divisions: 19,
            onChanged: (v) => setState(() => _lr = v),
          ),
          _sliderRow(
            keyName: 'xgb-lambda',
            label: 'L2 Penalty (λ)',
            valueText: _lambda.toStringAsFixed(1),
            value: _lambda,
            min: 0.0,
            max: 10.0,
            divisions: 20,
            onChanged: (v) => setState(() => _lambda = v),
          ),
          _sliderRow(
            keyName: 'xgb-gamma',
            label: 'Split Complexity Cost (γ)',
            valueText: _gamma.toStringAsFixed(0),
            value: _gamma,
            min: 0.0,
            max: 110.0,
            divisions: 22,
            onChanged: (v) => setState(() => _gamma = v),
          ),
          _sliderRow(
            keyName: 'xgb-rounds',
            label: 'Number of Trees (Rounds)',
            valueText: '$_rounds',
            value: _rounds.toDouble(),
            min: 1,
            max: 15,
            divisions: 14,
            onChanged: (v) => setState(() => _rounds = v.round()),
          ),
          _sliderRow(
            keyName: 'xgb-depth',
            label: 'Max Depth',
            valueText: '$_maxDepth',
            value: _maxDepth.toDouble(),
            min: 1,
            max: 3,
            divisions: 2,
            onChanged: (v) => setState(() => _maxDepth = v.round()),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('xgb-reset'),
              onPressed: () => setState(() {
                _lr = 0.30;
                _lambda = 1.0;
                _gamma = 0.0;
                _rounds = 5;
                _maxDepth = 1;
              }),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset defaults'),
            ),
          ),
          const SizedBox(height: 10),
          // Round 1 Split Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (splitApproved ? forest : const Color(0xFFB44C3B))
                  .withValues(alpha: isDark ? .18 : .08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (splitApproved ? forest : const Color(0xFFB44C3B))
                    .withValues(alpha: .45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  splitApproved
                      ? 'Round 1 Root Split Approved: x ≤ ${t1.threshold!.toStringAsFixed(1)}  (Gain = ${t1.gain.toStringAsFixed(2)})'
                      : 'Round 1 Root Split Pruned by γ! (Net Gain = ${t1?.gain.toStringAsFixed(2) ?? '0.00'} ≤ 0)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: splitApproved ? forest : const Color(0xFFB44C3B),
                  ),
                ),
                if (splitApproved) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${_maxDepth == 1 ? 'Left Leaf' : 'Root Left'}: G_L = ${t1.left!.gSum.toStringAsFixed(1)}, H_L = ${t1.left!.hSum.toStringAsFixed(1)}, w_L* = ${t1.left!.weight.toStringAsFixed(4)}   |   '
                    '${_maxDepth == 1 ? 'Right Leaf' : 'Root Right'}: G_R = ${t1.right!.gSum.toStringAsFixed(1)}, H_R = ${t1.right!.hSum.toStringAsFixed(1)}, w_R* = ${t1.right!.weight.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: ['NotoSansBengali', 'NotoSans'],
                      fontSize: 11.5,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          LineChartCard(
            title: 'Live Training MSE vs. Number of Trees',
            xLabel: 'Boosting Round (Trees)',
            yLabel: 'Training MSE',
            series: [
              ChartSeriesData(
                name: 'XGBoost (η=${_lr.toStringAsFixed(2)}, λ=${_lambda.toStringAsFixed(1)})',
                points: res.mseCurve,
                color: forest,
              ),
            ],
            metrics: [
              {'label': 'Initial MSE (Round 0)', 'value': res.initialMse.toStringAsFixed(2)},
              {'label': 'Round $_rounds Training MSE', 'value': res.finalMse.toStringAsFixed(2)},
              {'label': 'Active Split Rounds', 'value': '${res.activeSplits} / $_rounds'},
            ],
            provenance:
                'এই কার্ভটি প্রতিবার স্লাইডার নাড়লেই ডিভাইসে আসল 2nd-order XGBoost লুপ চালিয়ে রিকম্পিউট হচ্ছে (Training MSE; Test Generalization নয়)।',
          ),
          const SizedBox(height: 14),
          // Live 6-row state table after Round M
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: Table(
              border: TableBorder.symmetric(
                inside: BorderSide(color: borderColor.withValues(alpha: .6)),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: forest.withValues(alpha: isDark ? .20 : .09),
                  ),
                  children: const [
                    _Cell('X', bold: true),
                    _Cell('Actual y', bold: true),
                    _Cell('Pred F', bold: true),
                    _Cell('Grad g = F-y', bold: true),
                  ],
                ),
                for (var i = 0; i < _xData.length; i++)
                  TableRow(
                    children: [
                      _Cell(_xData[i].toStringAsFixed(0)),
                      _Cell(_yData[i].toStringAsFixed(0)),
                      _Cell(res.finalPreds[i].toStringAsFixed(2)),
                      _Cell(
                        (res.finalGrads[i] >= 0 ? '+' : '') +
                            res.finalGrads[i].toStringAsFixed(2),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          RichProse(
            interpretation,
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
              fontSize: 13,
              height: 1.9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderRow({
    required String keyName,
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          Text(
            valueText,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      Slider(
        key: ValueKey(keyName),
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    ],
  );
}

class _Cell extends StatelessWidget {
  final String text;
  final bool bold;
  const _Cell(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        fontFamily: bold ? null : 'JetBrainsMono',
      ),
    ),
  );
}
