import 'package:flutter/material.dart';

import '../core/api/api_exception.dart';
import '../core/realtime/live_refresh.dart';
import '../core/realtime/realtime_service.dart';
import '../core/theme/ec_tokens.dart';
import '../core/widgets/state_views.dart';
import '../data/models/consent_models.dart';
import '../data/repositories/consent_repository.dart';
import '../widgets/consent_widgets.dart';

/// Customer: one POPIA consent / mandate form written by the insurer. Pending forms are read and
/// signed here (tick + full name on record + password = the digital signature) or declined;
/// signed forms show the seal and can be withdrawn. The server checks the name, the password and
/// the state on every call, and seals the signed record.
class ConsentFormScreen extends StatefulWidget {
  const ConsentFormScreen({super.key, required this.consentId, this.repository});
  final String consentId;
  final ConsentRepository? repository;

  @override
  State<ConsentFormScreen> createState() => _ConsentFormScreenState();
}

class _ConsentFormScreenState extends State<ConsentFormScreen> with LiveRefresh {
  late final ConsentRepository _repo = widget.repository ?? ConsentRepository();
  final _name = TextEditingController();
  final _password = TextEditingController();
  Consent? _c;
  Object? _loadError;
  bool _loading = true;
  bool _agree = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _c == null;
      _loadError = null;
    });
    try {
      final c = await _repo.get(widget.consentId);
      if (mounted) setState(() => _c = c);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Live: this form changed elsewhere (signed on another device, replaced by a new form).
  @override
  bool wantsLive(RealtimeEvent e) => e.isConsent && e.consentId == widget.consentId && e.status != 'viewed';

  @override
  bool get reloadOnResync => false;

  @override
  void onLive() {
    if (!_busy) _load();
  }

  bool get _canSign => _agree && _name.text.trim().length >= 2 && _password.text.isNotEmpty && !_busy;

  String _signError(ApiException e) => switch (e.code) {
        'name_mismatch' => 'The name must match the name on record: ${_c?.signAs ?? 'your full legal name'}',
        'invalid_credentials' => 'Wrong password.',
        'too_many_attempts' => 'Too many wrong passwords. Try again in 15 minutes.',
        _ => e.message,
      };

  Future<void> _sign() async {
    if (!_canSign) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final signed = await _repo.sign(widget.consentId, fullName: _name.text, password: _password.text);
      if (!mounted) return;
      _password.clear();
      setState(() => _c = signed);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Consent form signed. Your insurer can continue.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      _password.clear();
      setState(() => _error = _signError(e));
      // The form may have changed (closed or replaced): show its current state.
      if (e.statusCode == 409) await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respondNo({required bool withdraw}) async {
    final c = _c!;
    final what = c.isClaim ? 'this claim' : 'this policy';
    final reason = await showOptionalReasonDialog(
      context,
      title: withdraw ? 'Withdraw your consent?' : 'Decline this consent form?',
      message: withdraw
          ? 'Your insurer may be unable to continue with $what until you sign a new form. Processing that already happened stays on record.'
          : 'Your insurer cannot continue with $what until you sign a consent form. You can ask them to send a new one.',
      confirmLabel: withdraw ? 'Withdraw consent' : 'Decline',
      confirmKey: Key(withdraw ? 'confirm-consent-withdraw' : 'confirm-consent-decline'),
      destructive: true,
    );
    if (reason == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = withdraw ? await _repo.withdraw(c.id, reason: reason) : await _repo.decline(c.id, reason: reason);
      if (!mounted) return;
      setState(() => _c = updated);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(withdraw ? 'Consent withdrawn. Your insurer has been told.' : 'Consent form declined.')));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consent form')),
      body: _loading
          ? const LoadingView(message: 'Loading the form…')
          : _c == null
              ? ErrorView(error: _loadError ?? 'Not found', onRetry: _load)
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView(padding: const EdgeInsets.all(EcSpace.lg), children: _body(_c!)),
                  ),
                ),
    );
  }

  List<Widget> _body(Consent c) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    const fullWidth = Size(double.infinity, 48);
    return [
      // Header: who wrote it, what it is for, where it stands.
      Semantics(
        header: true,
        child: Text(c.insurerName ?? 'Your insurer', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: EcSpace.xs),
      Text('POPIA consent and mandate for ${consentSubjectText(c)}', style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
      const SizedBox(height: EcSpace.sm),
      Wrap(spacing: EcSpace.sm, runSpacing: EcSpace.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ConsentStatusChip(status: c.status),
        Text('Sent ${formatConsentDate(c.requestedAt)}', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      ]),
      const SizedBox(height: EcSpace.lg),
      if (c.isPending)
        Padding(
          padding: const EdgeInsets.only(bottom: EcSpace.md),
          child: Text('Your insurer checked your documents. Read the form below; it explains what information they use, why, who they share it with, and your rights.',
              style: theme.textTheme.bodyMedium),
        ),
      ConsentTextCard(body: c.body ?? ''),
      if (c.fingerprint != null) ...[
        const SizedBox(height: EcSpace.xs),
        Text('Form fingerprint ${c.fingerprint}', style: theme.textTheme.bodySmall?.copyWith(color: muted, fontFamily: 'monospace')),
      ],
      const SizedBox(height: EcSpace.lg),
      if (c.isPending) ..._signForm(c, fullWidth),
      if (c.isSigned) ..._signedState(c, fullWidth),
      if (c.isRefused)
        _stateCard(
          icon: Icons.pause_circle_outline,
          title: c.isWithdrawn ? 'You withdrew this consent on ${formatConsentDate(c.respondedAt)}.' : 'You declined this form on ${formatConsentDate(c.respondedAt)}.',
          lines: [
            if (c.reason != null) 'Your reason: ${c.reason}',
            'Your insurer cannot continue with ${c.isClaim ? 'this claim' : 'this policy'} until you sign a new consent form. Ask your insurer to send one if you change your mind.',
          ],
        ),
      if (c.status == ConsentStatus.superseded)
        _stateCard(icon: Icons.history, title: 'This form was replaced by a newer one.', lines: const ['Open the latest form from Profile › Consent forms.']),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: EcSpace.md),
          child: Semantics(
            liveRegion: true,
            child: Text(_error!, key: const Key('consent-error'), style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
          ),
        ),
      const SizedBox(height: EcSpace.xl),
    ];
  }

  List<Widget> _signForm(Consent c, Size fullWidth) => [
        Text('Sign with your digital signature', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: EcSpace.sm),
        CheckboxListTile(
          key: const Key('consent-agree'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _agree,
          onChanged: _busy ? null : (v) => setState(() => _agree = v ?? false),
          title: const Text('I have read this form and I agree'),
        ),
        const SizedBox(height: EcSpace.sm),
        TextField(
          key: const Key('consent-name'),
          controller: _name,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(
            labelText: 'Full name',
            helperText: c.signAs == null ? 'Type your full name as it appears on record' : 'Type your full name as it appears on record: ${c.signAs}',
            helperMaxLines: 3,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: EcSpace.md),
        TextField(
          key: const Key('consent-password'),
          controller: _password,
          enabled: !_busy,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Password',
            helperText: 'Re-enter your EasyClaim password to confirm it is you.',
            helperMaxLines: 2,
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _sign(),
        ),
        const SizedBox(height: EcSpace.lg),
        FilledButton.icon(
          key: const Key('consent-sign'),
          onPressed: _canSign ? _sign : null,
          icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.draw_outlined),
          label: const Text('Sign consent form'),
          style: FilledButton.styleFrom(minimumSize: fullWidth),
        ),
        const SizedBox(height: EcSpace.sm),
        OutlinedButton(
          key: const Key('consent-decline'),
          onPressed: _busy ? null : () => _respondNo(withdraw: false),
          style: OutlinedButton.styleFrom(minimumSize: fullWidth),
          child: const Text('Decline'),
        ),
        const SizedBox(height: EcSpace.sm),
        Text('Signing records your name, the time and this exact text. You can withdraw your consent later from Profile › Consent forms.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ];

  List<Widget> _signedState(Consent c, Size fullWidth) => [
        _stateCard(
          icon: Icons.task_alt,
          title: 'Signed by ${c.signedName ?? '—'} on ${formatConsentDate(c.signedAt)}',
          trailing: ConsentSealChip(seal: c.seal),
          lines: [
            if (c.seal != 'VALID') 'The seal on this record could not be confirmed. Contact your insurer if this does not change.',
            'You can withdraw your consent at any time. Your insurer may then be unable to continue.',
          ],
        ),
        const SizedBox(height: EcSpace.md),
        OutlinedButton.icon(
          key: const Key('consent-withdraw'),
          onPressed: _busy ? null : () => _respondNo(withdraw: true),
          icon: const Icon(Icons.undo),
          label: const Text('Withdraw consent'),
          style: OutlinedButton.styleFrom(minimumSize: fullWidth, foregroundColor: Theme.of(context).colorScheme.error),
        ),
      ];

  Widget _stateCard({required IconData icon, required String title, List<String> lines = const [], Widget? trailing}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(EcSpace.lg),
      decoration: BoxDecoration(borderRadius: EcRadius.card, border: Border.all(color: theme.brightness == Brightness.dark ? EcColors.darkLine : EcColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: EcSpace.sm),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        if (trailing != null) Padding(padding: const EdgeInsets.only(top: EcSpace.sm, left: 28), child: trailing),
        for (final l in lines) Padding(padding: const EdgeInsets.only(top: EcSpace.xs, left: 28), child: Text(l)),
      ]),
    );
  }
}

/// Customer: every consent form they were sent (Profile › Consent forms), newest first.
class ConsentFormsScreen extends StatefulWidget {
  const ConsentFormsScreen({super.key, this.repository});
  final ConsentRepository? repository;

  @override
  State<ConsentFormsScreen> createState() => _ConsentFormsScreenState();
}

class _ConsentFormsScreenState extends State<ConsentFormsScreen> with LiveRefresh {
  late final ConsentRepository _repo = widget.repository ?? ConsentRepository();
  late Future<List<Consent>> _future = _repo.mine();
  bool _quiet = false;

  // Live: a new form from an insurer, or a form signed / declined / withdrawn elsewhere.
  @override
  bool wantsLive(RealtimeEvent e) => e.isConsent;

  @override
  void onLive() => setState(() {
        _quiet = true;
        _future = _repo.mine();
      });

  void _reload() => setState(() {
        _quiet = false;
        _future = _repo.mine();
      });

  Future<void> _open(Consent c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConsentFormScreen(consentId: c.id, repository: _repo)));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Consent forms')),
      body: FutureBuilder<List<Consent>>(
        future: _future,
        builder: (context, snap) {
          final stale = _quiet && snap.hasData;
          if (snap.connectionState != ConnectionState.done && !stale) return const LoadingView();
          if (snap.hasError && !stale) return ErrorView(error: snap.error!, onRetry: _reload);
          final items = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(padding: const EdgeInsets.all(EcSpace.lg), children: [
              Text('Your insurers send these after checking your documents. They say how your information is used; you can withdraw a signed consent here.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: EcSpace.md),
              if (items.isEmpty) const EmptyView(message: 'No consent forms yet.', icon: Icons.verified_user_outlined),
              for (final c in items)
                Card(
                  margin: const EdgeInsets.only(bottom: EcSpace.sm),
                  child: ListTile(
                    key: Key('consent-row-${c.id}'),
                    minVerticalPadding: EcSpace.md,
                    onTap: () => _open(c),
                    title: Text(c.insurerName ?? 'Insurer', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${consentSubjectText(c)} · sent ${formatConsentDate(c.requestedAt)}'),
                      const SizedBox(height: EcSpace.xs),
                      ConsentStatusChip(status: c.status),
                    ]),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}
