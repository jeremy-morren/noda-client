// Ported from NodaTime 6e024dde: src/NodaTime/Fields/IDatePeriodField.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../LocalDate.dart';

/// General representation of the difference between two dates in a particular time unit,
/// such as "days" or "months".
@internal
abstract interface class IDatePeriodField {
  /// Adds a duration value (which may be negative) to the date. This may not
  /// be reversible; for example, adding a month to January 30th will result in
  /// February 28th or February 29th.
  ///
  /// [localDate]: The local date to add to
  /// [value]: The value to add, in the units of the field
  ///
  /// Returns the updated local date
  LocalDate Add(LocalDate localDate, int value);

  /// Computes the difference between two local dates, as measured in the units
  /// of this field, rounding towards zero. This rounding means that
  /// unit.Add(start, unit.UnitsBetween(start, end)) always ends up with a date
  /// between start and end. (Ideally equal to end, but importantly, it never overshoots.)
  ///
  /// [start]: The start date
  /// [end]: The end date
  ///
  /// Returns the difference in the units of this field
  int UnitsBetween(LocalDate start, LocalDate end);
}
