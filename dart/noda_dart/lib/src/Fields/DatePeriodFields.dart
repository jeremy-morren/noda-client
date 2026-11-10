// Ported from NodaTime 6e024dde: src/NodaTime/Fields/DatePeriodFields.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'FixedLengthDatePeriodField.dart';
import 'IDatePeriodField.dart';
import 'MonthsPeriodField.dart';
import 'YearsPeriodField.dart';

/// All the period fields.
@internal
abstract final class DatePeriodFields {
  static final IDatePeriodField DaysField = FixedLengthDatePeriodField.NewUnitDays(1);
  static final IDatePeriodField WeeksField = FixedLengthDatePeriodField.NewUnitDays(7);
  static final IDatePeriodField MonthsField = MonthsPeriodField.New();
  static final IDatePeriodField YearsField = YearsPeriodField.New();
}
