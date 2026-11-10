// Ported from NodaTime 6e024dde: src/NodaTime/Text/Patterns/PatternBclSupport.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../Globalization/NodaCultureInfo.dart';
import '../../Globalization/NodaFormatInfo.dart';
import '../FixedFormatInfoPatternParser.dart';
import '../IPattern.dart';

/// Class providing simple support for the various Parse/TryParse/ParseExact/TryParseExact/Format overloads
/// provided by individual types.
@internal
final class PatternBclSupport<T> {
  final FixedFormatInfoPatternParser<T> Function(NodaFormatInfo) _patternParser;
  final String _defaultFormatPattern;

  @internal
  PatternBclSupport.NewDefaultFormatPatternPatternParser(
      String defaultFormatPattern, FixedFormatInfoPatternParser<T> Function(NodaFormatInfo) patternParser)
      : _patternParser = patternParser,
        _defaultFormatPattern = defaultFormatPattern;

  /// Formats a value; this backs each value type's `ToStringPattern(patternText, formatProvider)` (and `toString()`).
  ///
  /// noda_dart: a null format provider means the invariant culture (see [NodaFormatInfo.GetInstance]).
  String Format(T value, String? patternText, IFormatProvider? formatProvider) {
    if (patternText == null || patternText.isEmpty) {
      patternText = _defaultFormatPattern;
    }
    NodaFormatInfo formatInfo = NodaFormatInfo.GetInstance(formatProvider);
    // Note: string.IsNullOrEmpty isn't annotated in netstandard2.0, hence the use of the
    // null-forgiving operator here. *We* know patternText isn't null.
    IPattern<T> pattern = _patternParser(formatInfo).ParsePattern(patternText);
    return pattern.Format(value);
  }
}
