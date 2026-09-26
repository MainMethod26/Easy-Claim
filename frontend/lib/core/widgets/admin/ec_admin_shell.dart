import 'package:flutter/material.dart';

import '../../theme/ec_tokens.dart';

/// One navigation destination of a role shell.
class EcNavItem {
  const EcNavItem({required this.label, required this.icon, required this.selectedIcon});
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Responsive shell for staff, insurer-admin and superadmin areas of the ONE app.
///
/// It is a layout only: which destinations exist and what each page shows is decided by the
/// role shell that uses it (after the backend has authorised the actor). Material 3 window
/// sizes: compact (< 600) modal drawer, medium (600–1199) navigation rail, expanded (≥ 1200)
/// extended sidebar.
class EcAdminShell extends StatelessWidget {
  const EcAdminShell({
    super.key,
    required this.productTitle,
    required this.scopeLabel,
    required this.scopeIcon,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.body,
    required this.pageTitle,
    this.userName,
    this.userRole,
    this.actions = const [],
    this.onSignOut,
  });

  /// e.g. "EasyClaim".
  final String productTitle;

  /// Scope badge: the insurer name for tenant roles, "Platform" for the superadmin.
  final String scopeLabel;
  final IconData scopeIcon;
  final List<EcNavItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
  final String pageTitle;
  final String? userName;
  final String? userRole;
  final List<Widget> actions;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < EcBreakpoints.compact;
    // Staff consoles sit on the neutral page tone even when the app-wide scaffold is white.
    final pageBg = Theme.of(context).brightness == Brightness.dark ? EcColors.darkBg : EcColors.surfaceAlt;
    final extended = width >= EcBreakpoints.expanded;

    final appBar = AppBar(
      title: Text(pageTitle),
      actions: [
        ...actions,
        _ScopeBadge(label: scopeLabel, icon: scopeIcon),
        const SizedBox(width: EcSpace.sm),
        _UserMenu(name: userName, role: userRole, onSignOut: onSignOut),
        const SizedBox(width: EcSpace.sm),
      ],
    );

    if (compact) {
      return Scaffold(
        backgroundColor: pageBg,
        appBar: appBar,
        drawer: NavigationDrawer(
          selectedIndex: selectedIndex,
          onDestinationSelected: (i) {
            Navigator.of(context).pop();
            onSelect(i);
          },
          children: [
            _Brand(title: productTitle),
            for (final d in destinations)
              NavigationDrawerDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
          ],
        ),
        body: _Page(child: body),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 248,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelect,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: _Brand(title: productTitle, compact: !extended),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Scaffold(backgroundColor: pageBg, appBar: appBar, body: _Page(child: body)),
          ),
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: child,
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.title, this.compact = false});
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(EcRadius.sm)),
      child: const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(EcSpace.lg, EcSpace.lg, EcSpace.lg, EcSpace.xl),
      child: compact
          ? mark
          : Row(mainAxisSize: MainAxisSize.min, children: [mark, const SizedBox(width: EcSpace.sm), Text(title, style: theme.textTheme.titleMedium)]),
    );
  }
}

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: EcSpace.md, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(EcRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({this.name, this.role, this.onSignOut});
  final String? name;
  final String? role;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = (name ?? '?').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    return PopupMenuButton<String>(
      tooltip: 'Account',
      onSelected: (v) {
        if (v == 'signout') onSignOut?.call();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name ?? 'Signed in', style: theme.textTheme.titleSmall),
              if (role != null) Text(role!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'signout', child: Row(children: [Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('Sign out')])),
      ],
      child: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        child: Text(initials.isEmpty ? '?' : initials, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
      ),
    );
  }
}
