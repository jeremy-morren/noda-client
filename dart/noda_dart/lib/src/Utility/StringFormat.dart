// noda_dart: new code. .NET's invariant-culture string.Format and double.ToString, where Dart's differ.

/// .NET's invariant-culture formatting of values and composite format strings.
abstract final class StringFormat {
  /// `string.Format(CultureInfo.InvariantCulture, format, args)`: "{0}", "{0,5}", "{{" and "}}" only.
  static String Format(String format, List<Object?> args) {
    final result = StringBuffer();
    for (var i = 0; i < format.length; i++) {
      final ch = format[i];
      if (ch == '{') {
        if (i + 1 < format.length && format[i + 1] == '{') {
          result.write('{');
          i++;
          continue;
        }
        final end = format.indexOf('}', i);
        if (end == -1) {
          throw FormatException('Invalid format string: $format');
        }
        final spec = format.substring(i + 1, end);
        final colon = spec.indexOf(':');
        final indexAndAlignment = colon == -1 ? spec : spec.substring(0, colon);
        final comma = indexAndAlignment.indexOf(',');
        final indexText = comma == -1 ? indexAndAlignment : indexAndAlignment.substring(0, comma);
        final index = int.parse(indexText.trim());
        if (index < 0 || index >= args.length) {
          throw FormatException('Index (zero based) must be greater than or equal to zero and less than the size of the argument list.');
        }
        var text = FormatValue(args[index]);
        if (comma != -1) {
          final alignment = int.parse(indexAndAlignment.substring(comma + 1).trim());
          text = alignment >= 0 ? text.padLeft(alignment) : text.padRight(-alignment);
        }
        result.write(text);
        i = end;
      } else if (ch == '}') {
        if (i + 1 < format.length && format[i + 1] == '}') {
          i++;
        }
        result.write('}');
      } else {
        result.write(ch);
      }
    }
    return result.toString();
  }

  /// [value] as .NET's invariant culture formats it (null as "").
  static String FormatValue(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is int) {
      return value.toString();
    }
    if (value is double) {
      return FormatDouble(value);
    }
    return value.toString();
  }

  /// `value.ToString(CultureInfo.InvariantCulture)`, as .NET Core 3.0+ formats a double.
  static String FormatDouble(double value) {
    if (value.isNaN) {
      return 'NaN';
    }
    if (value.isInfinite) {
      return value > 0 ? 'Infinity' : '-Infinity';
    }
    final sign = value.isNegative ? '-' : '';
    if (value == 0) {
      return '${sign}0';
    }
    final exponential = value.abs().toStringAsExponential();
    final e = exponential.indexOf('e');
    final digits = exponential.substring(0, e).replaceAll('.', '');
    final exponent = int.parse(exponential.substring(e + 1));
    // .NET's "scale": the position of the decimal point relative to the first digit.
    final scale = exponent + 1;
    // (Number.Formatting.cs: nMaxDigits = Math.Max(number.DigitsCount, DoublePrecision), then FormatGeneral.)
    final maxDigits = digits.length > 15 ? digits.length : 15;
    if (scale > maxDigits || scale < -3) {
      final mantissa = digits.length == 1 ? digits : '${digits[0]}.${digits.substring(1)}';
      final exponentSign = exponent < 0 ? '-' : '+';
      final exponentDigits = exponent.abs().toString().padLeft(2, '0');
      return '$sign${mantissa}E$exponentSign$exponentDigits';
    }
    if (scale <= 0) {
      return '${sign}0.${'0' * -scale}$digits';
    }
    if (scale >= digits.length) {
      return '$sign$digits${'0' * (scale - digits.length)}';
    }
    return '$sign${digits.substring(0, scale)}.${digits.substring(scale)}';
  }
}
