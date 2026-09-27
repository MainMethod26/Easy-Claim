import 'package:flutter/material.dart';

import '../theme/ec_tokens.dart';

/// Makes a custom-drawn control behave like a real button: it is announced as a button with
/// [label], can be reached with Tab and activated with Enter/Space, shows a visible focus ring
/// and a hover tint, and is at least 48x48 logical pixels.
///
/// The child keeps its own look. Pressed-state animations can listen to [onPressedChanged]
/// (called on tap-down/up/cancel and while activated from the keyboard).
/// When [onTap] is null the control is disabled: not focusable, announced as disabled.
class EcTapTarget extends StatefulWidget {
  const EcTapTarget({
    super.key,
    required this.onTap,
    required this.label,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(EcRadius.md)),
    this.onPressedChanged,
    this.selected,
    this.hint,
    this.excludeChildSemantics = true,
    this.focusRingColor,
    this.minSize = 48,
    this.shape = BoxShape.rectangle,
  });

  final VoidCallback? onTap;

  /// What a screen reader announces, e.g. "Start a new claim".
  final String label;
  final String? hint;
  final Widget child;
  final BorderRadius borderRadius;
  final ValueChanged<bool>? onPressedChanged;

  /// For tab-like controls (nav bar items, sub-tabs): announced as selected.
  final bool? selected;

  /// True (default): the [label] replaces the child's own text in the semantics tree, so the
  /// button is read once and cleanly. Set false when the child has extra information to read.
  final bool excludeChildSemantics;
  final Color? focusRingColor;
  final double minSize;
  final BoxShape shape;

  @override
  State<EcTapTarget> createState() => _EcTapTargetState();
}

class _EcTapTargetState extends State<EcTapTarget> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final ring = widget.focusRingColor ?? EcColors.ink;
    final circle = widget.shape == BoxShape.circle;
    final showRing = enabled && _focused;
    final showHover = enabled && _hovered && !_focused;

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.label,
      hint: widget.hint,
      excludeSemantics: widget.excludeChildSemantics,
      // Set explicitly: excluding the child's semantics also drops the InkWell's own tap action
      // and focus flags, which a screen reader needs to activate the control.
      focusable: enabled,
      focused: enabled && _focused,
      onTap: widget.onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: widget.onPressedChanged,
          onFocusChange: (f) => setState(() => _focused = f),
          onHover: (h) => setState(() => _hovered = h),
          borderRadius: circle ? null : widget.borderRadius,
          customBorder: circle ? const CircleBorder() : null,
          // The child paints its own background, so ink would be hidden underneath; the focus
          // ring and hover tint below are drawn on top instead.
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.minSize,
              minHeight: widget.minSize,
            ),
            child: Container(
              alignment: null,
              foregroundDecoration: BoxDecoration(
                shape: widget.shape,
                borderRadius: circle ? null : widget.borderRadius,
                color: showHover ? Colors.black.withValues(alpha: 0.04) : null,
                border: showRing
                    ? Border.all(
                        color: ring,
                        width: 2.5,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      )
                    : null,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
