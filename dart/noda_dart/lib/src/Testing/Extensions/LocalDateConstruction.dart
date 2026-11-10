// Ported from NodaTime 6e024dde: src/NodaTime.Testing/Extensions/LocalDateConstruction.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../../LocalDate.dart';

/// Extension methods for constructing [LocalDate] values in the ISO calendar.
extension LocalDateConstruction on int {
  /// Constructs a [LocalDate] in January on the given day and year.
  ///
  /// ```dart
  /// var date = 1.January(2017);
  /// ```
  ///
  /// [day]: The day of January for the new date (this value)
  /// [year]: The year for the new date
  ///
  /// Returns the specified date in January.
  LocalDate January(int year) => LocalDate(year, 1, this);

  /// Constructs a [LocalDate] in February on the given day and year.
  ///
  /// ```dart
  /// var date = 1.February(2017);
  /// ```
  ///
  /// [day]: The day of February for the new date (this value)
  /// [year]: The year for the new date
  ///
  /// Returns the specified date in February.
  LocalDate February(int year) => LocalDate(year, 2, this);

  /// Constructs a [LocalDate] in March on the given day and year.
  ///
  /// ```dart
  /// var date = 1.March(2017);
  /// ```
  ///
  /// [day]: The day of March for the new date (this value)
  /// [year]: The year for the new date
  ///
  /// Returns the specified date in March.
  LocalDate March(int year) => LocalDate(year, 3, this);

  /// Constructs a [LocalDate] in April on the given day and year.
  ///
  /// ```dart
  /// var date = 1.April(2017);
  /// ```
  ///
  /// [day]: The day of April for the new date (this value)
  /// [year]: The year for the new date
  ///
  /// Returns the specified date in April.
  LocalDate April(int year) => LocalDate(year, 4, this);

  /// Constructs a [LocalDate] in May on the given day and year.
  ///
  /// ```dart
  /// var date = 1.May(2017);
  /// ```
  ///
  /// [day]: The day of May for the new date (this value)
  /// [year]: The year for the new date
  ///
  /// Returns the specified date in May.
  LocalDate May(int year) => LocalDate(year, 5, this);

  /// Constructs a [LocalDate] in June on the given day and year.
  ///
  /// ```dart
  /// var date = 1.June(2017);
  /// ```
  ///
  /// [day]: The day of June for the new date (this value)
  /// [year]: The year for the new date
  ///
  /// Returns the specified date in June.
  LocalDate June(int year) => LocalDate(year, 6, this);

  /// Constructs a [LocalDate] in July on the given day and year.
  ///
  /// ```dart
  /// var date = 1.July(2017);
  /// ```
  ///
  /// [day]: The day of July for the new date (this value)
  /// [year]: The year for the new date
  ///
  /// Returns the specified date in July.
  LocalDate July(int year) => LocalDate(year, 7, this);

  /// Constructs a [LocalDate] in August on the given day and year.
  ///
  /// ```dart
  /// var date = 1.August(2017);
  /// ```
  ///
  /// [day]: The day of August for the new date (this value)
  /// [year]: The year for the new date
  ///
  /// Returns the specified date in August.
  LocalDate August(int year) => LocalDate(year, 8, this);

  /// Constructs a [LocalDate] in September on the given day and year.
  ///
  /// ```dart
  /// var date = 1.September(2017);
  /// ```
  ///
  /// [day]: The day of September for the new date (this value)
  /// [year]: The year for the new date
  ///
  /// Returns the specified date in September.
  LocalDate September(int year) => LocalDate(year, 9, this);

  /// Constructs a [LocalDate] in October on the given day and year.
  ///
  /// ```dart
  /// var date = 1.October(2017);
  /// ```
  ///
  /// [day]: The day of October for the new date (this value)
  /// [year]: The year for the new date
  ///
  /// Returns the specified date in October.
  LocalDate October(int year) => LocalDate(year, 10, this);

  /// Constructs a [LocalDate] in November on the given day and year.
  ///
  /// ```dart
  /// var date = 1.November(2017);
  /// ```
  ///
  /// [day]: The day of November for the new date (this value)
  /// [year]: The year for the new date
  ///
  /// Returns the specified date in November.
  LocalDate November(int year) => LocalDate(year, 11, this);

  /// Constructs a [LocalDate] in December on the given day and year.
  ///
  /// ```dart
  /// var date = 1.December(2017);
  /// ```
  ///
  /// [day]: The day of December for the new date (this value)
  /// [year]: The year for the new date
  ///
  /// Returns the specified date in December.
  LocalDate December(int year) => LocalDate(year, 12, this);
}
