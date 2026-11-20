import 'package:flutter/material.dart';

import '../../state/learning_controller.dart';
import '../../ui/theme.dart';
import 'portfolio_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _heading = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
String _value(dynamic v) => v == null
    ? 'undefined'
    : v is double
    ? v.toStringAsFixed(6)
    : '$v';
Widget _choices(
  String name,
  List<String> values,
  String selected,
  ValueChanged<String> change,
) => Wrap(
  spacing: 10,
  runSpacing: 8,
  children: [
    for (final value in values)
      ChoiceChip(
        key: Key('$name-$value'),
        label: Text(value),
        selected: selected == value,
        onSelected: (_) => change(value),
      ),
  ],
);
Widget _assets(
  Future<PortfolioAssets> f,
  Widget Function(PortfolioAssets) body,
) => FutureBuilder<PortfolioAssets>(
  future: f,
  builder: (context, s) => s.hasError
      ? const Panel(
          child: Text('Bundled portfolio evidence could not be loaded.'),
        )
      : s.hasData
      ? body(s.data!)
      : const Center(child: CircularProgressIndicator()),
);
const _notice = Text(
  'Frozen prior capstones: UCI Wine Quality, GroupLens MovieLens ও SciFact। Original licenses/notices retained। Previously observed diagnostics, নতুন training/holdout scoring/production timing নয়। Portfolio template ব্যবহার করলে নিজের contribution ওindependent evidence যোগ করুন।',
  style: _bn,
);
Widget _projectPicker(
  PortfolioAssets a,
  String key,
  String project,
  ValueChanged<String> changed,
) => DropdownButtonFormField<String>(
  key: ValueKey('$key-$project'),
  initialValue: project,
  isExpanded: true,
  decoration: const InputDecoration(labelText: 'Evidence project'),
  items: [
    for (final id in portfolioProjects)
      DropdownMenuItem(value: id, child: Text(a.data['cards'][id]['title'])),
  ],
  onChanged: (v) => changed(v!),
);

class PortfolioEvidenceLab extends StatefulWidget {
  const PortfolioEvidenceLab({super.key});
  @override
  State<PortfolioEvidenceLab> createState() => _PortfolioEvidenceLabState();
}

class _PortfolioEvidenceLabState extends State<PortfolioEvidenceLab> {
  final data = PortfolioAssets.load();
  String project = 'classical', scope = 'all';
  @override
  Widget build(BuildContext context) => _assets(data, (a) {
    final card = a.data['cards'][project], r = a.summary(project, scope: scope);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 06 · PORTFOLIO EVIDENCE',
            icon: Icons.folder_open_outlined,
          ),
          _gap,
          const Text('Connect each claim to evidence.', style: _heading),
          _gap,
          const Text(
            'চারটি capstone-এর frozen row-level evidence থেকে summary আবার গণনা করুন। Cross-project metrics-এর task, population ওselection আলাদা; এক leaderboard-এ তুলনা নয়। Model retraining বাnew evaluation হচ্ছে না।',
            style: _bn,
          ),
          _gap,
          _projectPicker(
            a,
            'evidence-project',
            project,
            (v) => setState(() => project = v),
          ),
          _gap,
          _choices(
            'evidence-scope',
            portfolioSlices,
            scope,
            (v) => setState(() => scope = v),
          ),
          _gap,
          const Text(
            'all/first5/last5 হলো stored order-এর descriptive slices। এগুলো random sample, demographic subgroup বাfairness estimate নয়। Small slices-এর missing denominator undefined দেখায়।',
            style: _bn,
          ),
          _gap,
          Text(card['protocol'], style: _bn),
          _gap,
          for (final e in r.entries)
            Text('${e.key}: ${_value(e.value)}', style: _bn),
          _gap,
          Text('Remaining limits: ${card['limits']}', style: _bn),
          _gap,
          if (project == 'deep')
            const Text(
              'CV AP selection MLP বেছে নিয়েছিল; decision-validation-এ mean cost logistic≈0.323560, MLP≈0.328796। তাই “deep model সব metric-এ superior” বলা যায় না। Fixed threshold/action-cost ওcandidate-selection criterion আলাদা।',
              style: _bn,
            ),
          if (project == 'recommendation')
            const Text(
              '74 stored audit users-এর মধ্যে empty eligible-gold users metric denominator থেকে বাদ পড়ে। Macro user mean এবংpooled event ratio এক নয়। Historical positive feedback MNAR; online causal utility অজানা।',
              style: _bn,
            ),
          if (project == 'rag')
            const Text(
              'ছয়টি saved train/dev-mixed sample-এর format/quote/emission inspect করছি;188-dev aggregate answer accuracy নয়। “verified_answers: 0” মানে এই workflow কোনো answer scientifically verify করেনি; সব hypotheses false বলা হয়নি।',
              style: _bn,
            ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              project = 'classical';
              scope = 'all';
            }),
            child: const Text('Reset evidence review'),
          ),
          _gap,
          _notice,
        ],
      ),
    );
  });
}

class PortfolioAuditLab extends StatefulWidget {
  const PortfolioAuditLab({super.key});
  @override
  State<PortfolioAuditLab> createState() => _PortfolioAuditLabState();
}

class _PortfolioAuditLabState extends State<PortfolioAuditLab> {
  final data = PortfolioAssets.load();
  String project = 'classical', fault = 'none';
  @override
  Widget build(BuildContext context) => _assets(data, (a) {
    final card = Map<String, dynamic>.from(a.data['cards'][project]),
        audit = portfolioAudit(card, fault: fault);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 06 · CLAIM & ARTIFACT AUDIT',
            icon: Icons.fact_check_outlined,
          ),
          _gap,
          const Text('Audit the bytes. Bound the claim.', style: _heading),
          _gap,
          const Text(
            'এটি explicit metadata/claim fixture। CLI verifier actual source bytes, dependency hashes, derived summaries ওlicense notices যাচাই করে। App-এ নিচের loaded contract-এর compatibility review হয়; signature verification বাruntime cryptographic attestation দাবি নয়।',
            style: _bn,
          ),
          _gap,
          _projectPicker(
            a,
            'audit-project',
            project,
            (v) => setState(() => project = v),
          ),
          _gap,
          _choices(
            'audit-fault',
            portfolioFaults,
            fault,
            (v) => setState(() => fault = v),
          ),
          _gap,
          Text(
            'Evidence gate: ${audit['passed'] ? 'PASS' : 'BLOCKED'}\nIssues: ${(audit['issues'] as List).isEmpty ? 'none' : (audit['issues'] as List).join(', ')}',
            style: _bn,
          ),
          _gap,
          for (final e in (audit['loaded'] as Map).entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SelectableText('${e.key}: ${e.value}', style: _bn),
            ),
          _gap,
          const Text(
            'Matching hash নিজে scientific validity, data rights বাpersonal ownership প্রমাণ করে না। Trusted expected identity চাই। Missing license notice retain/restore করুন; production measurements না থাকলে production claim বাদ দিন। Code ঠিক হলেও evidence scope বদলানো যায় না।',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              project = 'classical';
              fault = 'none';
            }),
            child: const Text('Reset portfolio audit'),
          ),
          _gap,
          _notice,
        ],
      ),
    );
  });
}

class MockDefenseLab extends StatefulWidget {
  final LearningController? controller;
  const MockDefenseLab({super.key, this.controller});
  @override
  State<MockDefenseLab> createState() => _MockDefenseLabState();
}

class _MockDefenseLabState extends State<MockDefenseLab> {
  final data = PortfolioAssets.load(), text = TextEditingController();
  String role = 'ml_engineer', round = 'project', message = '';
  Set<String> checked = {};
  bool busy = true;
  int revision = 0;
  MockDraftStore? get store => widget.controller == null
      ? null
      : MockDraftStore(widget.controller!.repository);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final token = ++revision;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final d =
          await (store?.load(role, round) ?? Future.value(MockDraft.empty()));
      if (!mounted || token != revision) return;
      setState(() {
        text.text = d.text;
        checked = d.checked.toSet();
        busy = false;
      });
    } catch (_) {
      if (mounted && token == revision) {
        setState(() {
          busy = false;
          text.clear();
          checked = {};
          message =
              'Saved draft could not be read. No stored data was overwritten.';
        });
      }
    }
  }

  Future<void> save() async {
    if (text.text.length > 8000) {
      setState(() => message = 'Draft is too long; shorten it before saving.');
      return;
    }
    final target = store;
    if (target == null) {
      setState(
        () => message =
            'Preview draft only; open this lab in the learning app to save.',
      );
      return;
    }
    final token = revision;
    final r = role, s = round;
    final draft = MockDraft(text.text, checked);
    setState(() => busy = true);
    try {
      await target.save(r, s, draft);
      if (mounted && token == revision) {
        setState(() {
          busy = false;
          message = 'Draft saved on this device.';
        });
      }
    } catch (_) {
      if (mounted && token == revision) {
        setState(() {
          busy = false;
          message = 'Draft could not be saved. Keep this text and retry.';
        });
      }
    }
  }

  @override
  void dispose() {
    revision++;
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _assets(data, (a) {
    final card = a.data['mock_cards']['$role:$round'];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 06 · MOCK DEFENSE WORKBENCH',
            icon: Icons.record_voice_over_outlined,
          ),
          _gap,
          const Text('Explain it. Write it. Review it.', style: _heading),
          _gap,
          const Text(
            'চারটি role × চারটি round =16 original practice prompts। Draft ওself-review checks প্রতিটি role/round-এর জন্য আলাদা save হয়। Switching-এর আগে Save mock draft চাপুন; unsaved edits retained হয় না। Checklist manual evidence review, validated hiring score বাinterviewer judgment নয়।',
            style: _bn,
          ),
          _gap,
          const Text('Practice role'),
          IgnorePointer(
            ignoring: busy,
            child: _choices('mock-role', mockRoles, role, (v) {
              role = v;
              load();
            }),
          ),
          _gap,
          const Text('Round'),
          IgnorePointer(
            ignoring: busy,
            child: _choices('mock-round', mockRounds, round, (v) {
              round = v;
              load();
            }),
          ),
          _gap,
          Text(
            '${card['role']} · ${card['stage']}\nFocus: ${card['focus']}\n${card['prompt']}\n\nFollow-up: ${card['follow_up']}',
            style: _bn,
          ),
          _gap,
          TextField(
            key: const Key('mock-draft'),
            controller: text,
            enabled: !busy,
            minLines: 5,
            maxLines: 12,
            maxLength: 8000,
            decoration: const InputDecoration(
              labelText: 'Your defense draft',
              hintText:
                  'Contract → source → baseline → checks → failure → limits',
            ),
            style: _bn,
          ),
          _gap,
          for (final key in mockChecks)
            CheckboxListTile(
              key: Key('mock-check-$key'),
              contentPadding: EdgeInsets.zero,
              value: checked.contains(key),
              title: Text(card['review'][key], style: _bn),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      v == true ? checked.add(key) : checked.remove(key);
                    }),
            ),
          _gap,
          Text(
            'Self-reviewed evidence items: ${checked.length} / 6',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const Key('mock-save'),
                onPressed: busy ? null : save,
                child: const Text('Save mock draft'),
              ),
              OutlinedButton(
                onPressed: busy ? null : load,
                child: const Text('Reload saved draft'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        text.clear();
                        checked = {};
                        message = 'Current edits cleared; saved draft unchanged until Save.';
                      }),
                child: const Text('Clear current edits'),
              ),
            ],
          ),
          _gap,
          if (busy) const Text('Loading or saving local draft…', style: _bn),
          if (message.isNotEmpty) Text(message, style: _bn),
          _gap,
          const Text(
            'নিজের contribution, tested failure ওremaining unknown নির্দিষ্ট করে লিখুন। Prompt/reference দেখে নিজের কাজের দাবি তৈরি করবেন না। Actual oral feedback ওunseen task performance এখানে observed নয়।',
            style: _bn,
          ),
          _gap,
          _notice,
        ],
      ),
    );
  });
}
