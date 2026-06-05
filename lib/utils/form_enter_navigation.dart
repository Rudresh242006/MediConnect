import 'package:flutter/material.dart';

/// Helpers for Enter-key field navigation and submit-on-last-field.
class FormEnterNavigation {
  static void focusNext(BuildContext context, FocusNode? next) {
    if (next != null) {
      FocusScope.of(context).requestFocus(next);
    } else {
      FocusScope.of(context).nextFocus();
    }
  }

  static void focusNextOrUnfocus(BuildContext context, FocusNode? next) {
    if (next != null) {
      focusNext(context, next);
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  /// Moves to [nextFocus], or runs [onSubmit] on the last field (e.g. Continue / Login).
  static void onFieldDone(
    BuildContext context, {
    FocusNode? nextFocus,
    VoidCallback? onSubmit,
  }) {
    if (nextFocus != null) {
      focusNext(context, nextFocus);
      return;
    }
    FocusScope.of(context).unfocus();
    onSubmit?.call();
  }
}
