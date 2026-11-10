// Ported from NodaTime 6e024dde: src/NodaTime/Text/IPartialPattern.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'IPattern.dart';
import 'ParseResult.dart';
import 'ValueCursor.dart';

/// Internal interface supporting partial parsing and formatting. This is used
/// when one pattern is embedded within another.
///
/// [T]: The type of value to be parsed or formatted.
@internal
abstract interface class IPartialPattern<T> implements IPattern<T> {
  /// Parses a value from the current position in the cursor. This will
  /// not fail if the pattern ends before the cursor does - that's expected
  /// in most cases.
  ///
  /// [cursor]: The cursor to parse from.
  ///
  /// Returns the result of parsing from the cursor.
  ParseResult<T> ParsePartial(ValueCursor cursor);
}
