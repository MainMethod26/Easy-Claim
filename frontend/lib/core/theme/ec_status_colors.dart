import 'package:flutter/material.dart';

import 'ec_tokens.dart';

/// A foreground/background pair for one status, tuned for text contrast (WCAG AA) on its
/// container in both themes.
@immutable
class EcTone {
  const EcTone(this.foreground, this.background);
  final Color foreground;
  final Color background;

  static EcTone lerp(EcTone a, EcTone b, double t) =>
      EcTone(Color.lerp(a.foreground, b.foreground, t)!, Color.lerp(a.background, b.background, t)!);
}

/// Semantic status colours as a ThemeExtension, so status styling comes from the theme
/// (light and dark) instead of hard-coded hex values in each screen.
///
/// Status is never communicated by colour alone: every chip pairs the tone with an icon and
/// a label (WCAG 1.4.1). See `EcStatusChip`.
@immutable
class EcStatusColors extends ThemeExtension<EcStatusColors> {
  const EcStatusColors({
    required this.neutral,
    required this.info,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final EcTone neutral;
  final EcTone info;
  final EcTone success;
  final EcTone warning;
  final EcTone danger;

  static const light = EcStatusColors(
    neutral: EcTone(Color(0xFF334155), Color(0xFFF1F5F9)),
    info: EcTone(Color(0xFF1D4ED8), Color(0xFFEFF6FF)),
    success: EcTone(Color(0xFF15803D), Color(0xFFF0FDF4)),
    warning: EcTone(Color(0xFFB45309), Color(0xFFFFFBEB)),
    danger: EcTone(Color(0xFFB91C1C), Color(0xFFFEF2F2)),
  );

  static const dark = EcStatusColors(
    neutral: EcTone(Color(0xFFCBD5E1), Color(0xFF1E293B)),
    info: EcTone(Color(0xFF93C5FD), Color(0xFF172554)),
    success: EcTone(Color(0xFF86EFAC), Color(0xFF052E16)),
    warning: EcTone(Color(0xFFFCD34D), Color(0xFF451A03)),
    danger: EcTone(Color(0xFFFCA5A5), Color(0xFF450A0A)),
  );

  /// Reads the extension from the theme, falling back to the light palette.
  static EcStatusColors of(BuildContext context) =>
      Theme.of(context).extension<EcStatusColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  EcStatusColors copyWith({EcTone? neutral, EcTone? info, EcTone? success, EcTone? warning, EcTone? danger}) =>
      EcStatusColors(
        neutral: neutral ?? this.neutral,
        info: info ?? this.info,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
      );

  @override
  EcStatusColors lerp(ThemeExtension<EcStatusColors>? other, double t) {
    if (other is! EcStatusColors) return this;
    return EcStatusColors(
      neutral: EcTone.lerp(neutral, other.neutral, t),
      info: EcTone.lerp(info, other.info, t),
      success: EcTone.lerp(success, other.success, t),
      warning: EcTone.lerp(warning, other.warning, t),
      danger: EcTone.lerp(danger, other.danger, t),
    );
  }
}

/// Keeps the semantic base colours referenced so the palette stays in one file.
const ecSemanticBase = [EcColors.success, EcColors.warning, EcColors.danger, EcColors.info];
