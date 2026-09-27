import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/admin/ec_status_chip.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/consent_models.dart';
import '../../data/repositories/consent_repository.dart';
import '../../widgets/consent_widgets.dart';
import 'console_common.dart';

/// INSURER_ADMIN: this insurer's own POPIA consent / mandate wording. One form for linking a
/// policy (sent after the document check) and one for claims (sent when a claim is verified).
/// Each save is a new version; forms already sent keep the text they were sent with.
class ConsentTemplatesPage extends StatefulWidget {
  const ConsentTemplatesPage({super.key, this.repository});
  final ConsentRepository? repository;

  @override
  State<ConsentTemplatesPage> createState() => _ConsentTemplatesPageState();
}

class _ConsentTemplatesPageState extends State<ConsentTemplatesPage> {
  late final ConsentRepository _repo = widget.repository ?? ConsentRepository();
  late Future<ConsentTemplates> _future = _repo.templates();

  void _reload() => setState(() { _future = _repo.templates(); });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConsentTemplates>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView(message: 'Loading your consent forms…');
        if (snap.hasError) return Center(child: EcStateMessage.error(errorMessage(snap.error!), onRetry: _reload));
        final t = snap.data!;
        final editors = [
          _TemplateEditor(
            key: const Key('template-onboarding'),
            title: 'Onboarding consent',
            subtitle: 'Sent when you have checked every document of a policy request. You approve after the customer signs.',
            template: t.onboarding,
            placeholders: t.placeholders,
            repository: _repo,
          ),
          _TemplateEditor(
            key: const Key('template-claim'),
            title: 'Claim mandate & consent',
            subtitle: 'Sent automatically when an assessor verifies a claim. Screening waits for the signature.',
            template: t.claim,
            placeholders: t.placeholders,
            repository: _repo,
          ),
        ];
        return LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 1100;
          return EcPage(children: [
            const EcPageHeader(
              title: 'Consent forms',
              subtitle: 'Your own POPIA consent and mandate wording. Customers read and sign it in the app before work continues.',
            ),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: Column(children: [editors[0], const SizedBox(height: EcSpace.xl), editors[1]])),
                const SizedBox(width: EcSpace.xl),
                const Expanded(flex: 2, child: _PopiaChecklist()),
              ])
            else ...[
              const _PopiaChecklist(),
              editors[0],
              editors[1],
            ],
          ]);
        });
      },
    );
  }
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({super.key, required this.title, required this.subtitle, required this.template, required this.placeholders, required this.repository});
  final String title;
  final String subtitle;
  final ConsentTemplate template;
  final List<String> placeholders;
  final ConsentRepository repository;

  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late ConsentTemplate _t = widget.template;
  late final TextEditingController _body = TextEditingController(text: widget.template.body);
  final _focus = FocusNode();
  bool _saving = false;

  @override
  void dispose() {
    _body.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _length => _body.text.trim().length;
  bool get _dirty => _body.text != _t.body;
  bool get _validLength => _length >= ConsentTemplate.minLength && _length <= ConsentTemplate.maxLength;

  /// Inserts [p] at the cursor (or replaces the selection); appends when the field has no cursor.
  void _insert(String p) {
    final v = _body.value;
    final sel = v.selection;
    final start = sel.isValid ? sel.start : v.text.length;
    final end = sel.isValid ? sel.end : v.text.length;
    final text = v.text.replaceRange(start, end, p);
    _body.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: start + p.length));
    _focus.requestFocus();
    setState(() {});
  }

  Future<void> _save() async {
    final next = _t.version + 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Save version $next?'),
        content: Text('Saves version $next. Forms already sent keep their text.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(key: const Key('confirm-save-template'), onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.saveTemplate(_t.kind, _body.text.trim());
      if (!mounted) return;
      setState(() {
        _t = saved;
        _body.text = saved.body;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.title}: version ${saved.version} saved. New forms use it from now on.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final kind = _t.kind;
    final String? lengthError = _length < ConsentTemplate.minLength
        ? 'At least ${ConsentTemplate.minLength} characters (now $_length).'
        : _length > ConsentTemplate.maxLength
            ? 'At most ${ConsentTemplate.maxLength} characters (now $_length).'
            : null;
    return EcSection(
      title: widget.title,
      subtitle: widget.subtitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: EcSpace.sm, runSpacing: EcSpace.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _t.isStarter
              ? const ConsentBadge(label: 'EasyClaim starter text', icon: Icons.auto_awesome_outlined, kind: EcToneKind.info)
              : ConsentBadge(label: 'Version ${_t.version}', icon: Icons.history_edu_outlined, kind: EcToneKind.success),
          Text(_t.updatedAt == null ? 'Not customised yet' : 'Last updated ${formatConsentDate(_t.updatedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ]),
        const SizedBox(height: EcSpace.md),
        Text('Placeholders (tap to insert at the cursor)', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        const SizedBox(height: EcSpace.xs),
        Wrap(spacing: EcSpace.sm, runSpacing: EcSpace.xs, children: [
          for (final p in widget.placeholders)
            ActionChip(
              key: Key('placeholder-$kind-$p'),
              label: Text(p, style: const TextStyle(fontFamily: 'monospace')),
              tooltip: 'Insert $p',
              onPressed: _saving ? null : () => _insert(p),
            ),
        ]),
        const SizedBox(height: EcSpace.md),
        TextField(
          key: Key('template-body-$kind'),
          controller: _body,
          focusNode: _focus,
          enabled: !_saving,
          minLines: 10,
          maxLines: 22,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: 'Form text',
            alignLabelWithHint: true,
            helperText: lengthError == null ? '$_length / ${ConsentTemplate.maxLength} characters' : null,
            errorText: lengthError,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: EcSpace.md),
        Wrap(spacing: EcSpace.md, runSpacing: EcSpace.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilledButton.icon(
            key: Key('save-template-$kind'),
            onPressed: _dirty && _validLength && !_saving ? _save : null,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: Text('Save as version ${_t.version + 1}'),
          ),
          if (_dirty)
            TextButton(
              onPressed: _saving ? null : () => setState(() => _body.text = _t.body),
              child: const Text('Discard changes'),
            ),
        ]),
      ]),
    );
  }
}

/// Guidance only (not enforced): what POPIA expects a consent / mandate form to say.
class _PopiaChecklist extends StatelessWidget {
  const _PopiaChecklist();

  static const _items = [
    ('Purpose', 'Why you process the information: assessing the policy link or the claim, and paying it.'),
    ('What information', 'Identity, contact, policy, claim, evidence and bank details. Say so explicitly if health or other special personal information is involved (POPIA s26–27).'),
    ('Who it is shared with', 'Staff, assessors and service providers, reinsurers, fraud-prevention bodies where the law allows, and where the law requires it.'),
    ('Retention', 'How long you keep it: only as long as needed or as the law requires.'),
    ('Right to withdraw', 'The customer may withdraw consent at any time in the app; processing that already happened stays lawful.'),
    ('Right to complain', 'Access and correction rights, and the right to complain to the Information Regulator (inforeg.org.za).'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EcSection(
      title: 'What a POPIA consent form should cover',
      subtitle: 'Guidance only. Your compliance officer decides the final wording.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (title, text) in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: EcSpace.md),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check_circle_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: EcSpace.sm),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '$title. ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: text),
                ])),
              ),
            ]),
          ),
        Text('Placeholders are filled in when a form is sent. The text is fixed with a fingerprint at that moment, so later edits never change a form a customer already received.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}
