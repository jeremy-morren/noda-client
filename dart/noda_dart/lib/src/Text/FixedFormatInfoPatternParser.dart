// Ported from NodaTime 6e024dde: src/NodaTime/Text/FixedFormatInfoPatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaFormatInfo.dart';
import '../Utility/Cache.dart';
import '../Utility/Comparers.dart';
import 'IPattern.dart';
import 'Patterns/IPatternParser.dart';

/// A pattern parser for a single format info, which caches patterns by text/style.
@internal
final class FixedFormatInfoPatternParser<T> {
  // It would be unusual to have more than 50 different patterns for a specific culture
  // within a real app.
  static const int _CacheSize = 50;
  final Cache<String, IPattern<T>> _cache;

  @internal
  FixedFormatInfoPatternParser.NewPatternParserFormatInfo(IPatternParser<T> patternParser, NodaFormatInfo formatInfo)
      : _cache = Cache<String, IPattern<T>>.NewSizeValueFactoryKeyComparer(
            _CacheSize, (patternText) => patternParser.ParsePattern(patternText, formatInfo), _OrdinalStringComparer());

  IPattern<T> ParsePattern(String pattern) => _cache.GetOrAdd(pattern);
}

/// noda_dart: .NET's `StringComparer.Ordinal` (Dart's `String.==` and `hashCode` are ordinal).
final class _OrdinalStringComparer implements IEqualityComparer<String> {
  @override
  bool Equals(String x, String y) => x == y;

  @override
  int GetHashCode(String obj) => obj.hashCode;
}
