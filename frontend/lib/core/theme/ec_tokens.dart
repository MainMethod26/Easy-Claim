import 'package:flutter/material.dart';

/// EasyClaim design tokens.
///
/// These are the colours the app already uses (EasyClaim orange on Tailwind-style slate
/// neutrals), collected in one place so every role's screens share a single visual language.
/// Professional = restraint: one accent colour, neutrals doing most of the work, a small
/// spacing scale and one corner radius. See docs/admin/DESIGN_BRIEF.md.
class EcColors {
  EcColors._();

  // Brand accent (the only saturated colour used for primary actions).
  static const brand = Color(0xFFFF5500);
  static const brandDark = Color(0xFFFF6D00);

  /// Orange for text and small icons on white/light surfaces. The brand orange is only ~3:1 on
  /// white, so it stays for filled buttons and backgrounds; this one is ≥ 4.5:1 (WCAG AA).
  static const brandText = Color(0xFFC2410C);

  // Slate neutrals (light theme).
  static const ink = Color(0xFF0F172A); // headings, primary text
  static const inkMuted = Color(0xFF64748B); // secondary text
  static const inkSubtle = Color(0xFF94A3B8); // placeholders, disabled
  static const line = Color(0xFFE2E8F0); // borders, dividers
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8FAFC); // page background
  static const surfaceSunken = Color(0xFFF1F5F9); // table header, hover

  // Slate neutrals (dark theme).
  static const darkBg = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF0F172A);
  static const darkSurfaceAlt = Color(0xFF111A2E);
  static const darkLine = Color(0xFF1E293B);
  static const darkInk = Color(0xFFE2E8F0);
  static const darkInkMuted = Color(0xFF94A3B8);

  // Semantic base colours (the app already uses these values).
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF0055FF);
}

/// 4/8-point spacing scale.
class EcSpace {
  EcSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// One radius for cards, inputs and chips keeps the UI calm.
class EcRadius {
  EcRadius._();
  static const sm = 6.0;
  static const md = 8.0;
  static const pill = 999.0;
  static BorderRadius get card => BorderRadius.circular(md);
}

/// Material 3 window-size breakpoints used by the admin shell.
class EcBreakpoints {
  EcBreakpoints._();
  static const compact = 600.0; // below: modal drawer
  static const expanded = 1200.0; // at/above: extended sidebar; in between: navigation rail
}

/// Numbers in KPIs and tables use tabular figures so columns line up.
const ecTabularFigures = [FontFeature.tabularFigures()];
