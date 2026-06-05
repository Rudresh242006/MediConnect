import 'package:flutter/material.dart';

/// Scrolls the nearest [Scrollable] so [key]'s widget is visible (e.g. first invalid field).
class FormScrollHelper {
  static Future<void> reveal(
    GlobalKey key, {
    double alignment = 0.12,
  }) async {
    final context = key.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      alignment: alignment,
    );
  }

  /// After [FormState.validate], scrolls to and focuses the first field with an error.
  static Future<bool> scrollToFirstInvalidField(
    List<GlobalKey<FormFieldState<dynamic>>> fieldKeys, {
    List<FocusNode?> focusNodes = const [],
  }) async {
    for (var i = 0; i < fieldKeys.length; i++) {
      final state = fieldKeys[i].currentState;
      if (state != null && state.hasError) {
        await reveal(fieldKeys[i]);
        if (i < focusNodes.length && focusNodes[i] != null) {
          focusNodes[i]!.requestFocus();
        }
        return true;
      }
    }
    return false;
  }

  static Future<void> revealSection(
    GlobalKey key, {
    FocusNode? focus,
  }) async {
    await reveal(key);
    focus?.requestFocus();
  }
}
