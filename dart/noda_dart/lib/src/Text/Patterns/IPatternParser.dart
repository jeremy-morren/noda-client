// Ported from NodaTime 6e024dde: src/NodaTime/Text/Patterns/IPatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../Globalization/NodaFormatInfo.dart';
import '../IPattern.dart';

/// Internal interface used by FixedFormatInfoPatternParser. Unfortunately
/// even though this is internal, implementations must either use public methods
/// or explicit interface implementation.
@internal
abstract interface class IPatternParser<T> {
  IPattern<T> ParsePattern(String pattern, NodaFormatInfo formatInfo);
}
