import 'package:flutter/services.dart';

/// Keeps a fixed prefix (e.g. `P-`, `D-`) and uppercases alphanumeric suffix.
class PrefixedIdTextInputFormatter extends TextInputFormatter {
  PrefixedIdTextInputFormatter({
    required this.prefix,
    this.maxSuffixLength = 10,
  });

  final String prefix;
  final int maxSuffixLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var suffix = newValue.text.toUpperCase();
    if (suffix.startsWith(prefix)) {
      suffix = suffix.substring(prefix.length);
    } else if (suffix.startsWith(prefix[0])) {
      suffix = suffix.substring(1);
    }
    suffix = suffix.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (suffix.length > maxSuffixLength) {
      suffix = suffix.substring(0, maxSuffixLength);
    }

    final text = '$prefix$suffix';
    var end = newValue.selection.end;
    if (end < prefix.length) end = text.length;
    if (end > text.length) end = text.length;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: end),
      composing: TextRange.empty,
    );
  }
}

/// Uppercases all letters as the user types.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
