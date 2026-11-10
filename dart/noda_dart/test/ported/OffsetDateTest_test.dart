// Ported from NodaTime 6e024dde: src/NodaTime.Test/OffsetDateTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: no reflection: LocalDateProperties lists the common properties by hand.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/DateAdjusters.dart';
import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/OffsetDate.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/OffsetDateTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'LocalDateProperties': (args) {
      LocalDate local = LocalDate(2012, 6, 19, CalendarSystem.Julian);
      Offset offset = Offset.FromHours(5);

      OffsetDate od = OffsetDate(local, offset);

      // noda_dart: the properties OffsetDate declares that LocalDate declares too (C# finds them by reflection).
      final commonProperties = <String, (Object? Function(LocalDate), Object? Function(OffsetDate))>{
        'Calendar': ((x) => x.Calendar, (x) => x.Calendar),
        'Year': ((x) => x.Year, (x) => x.Year),
        'Month': ((x) => x.Month, (x) => x.Month),
        'Day': ((x) => x.Day, (x) => x.Day),
        'DayOfWeek': ((x) => x.DayOfWeek, (x) => x.DayOfWeek),
        'YearOfEra': ((x) => x.YearOfEra, (x) => x.YearOfEra),
        'Era': ((x) => x.Era, (x) => x.Era),
        'DayOfYear': ((x) => x.DayOfYear, (x) => x.DayOfYear),
      };
      for (final property in commonProperties.entries) {
        Assert.AreEqual(property.value.$1(local), property.value.$2(od), property.key);
      }
    },

    'ComponentProperties': (args) {
      var date = LocalDate(2012, 1, 2);
      var offset = Offset.FromHours(5);

      var offsetDate = OffsetDate(date, offset);
      Assert.AreEqual(offset, offsetDate.Offset);
      Assert.AreEqual(date, offsetDate.Date);
    },

    'Equality': (args) {
      LocalDate date1 = LocalDate(2012, 10, 6);
      LocalDate date2 = LocalDate(2012, 9, 5);
      Offset offset1 = Offset.FromHours(1);
      Offset offset2 = Offset.FromHours(2);

      OffsetDate equal1 = OffsetDate(date1, offset1);
      OffsetDate equal2 = OffsetDate(date1, offset1);
      OffsetDate unequalByOffset = OffsetDate(date1, offset2);
      OffsetDate unequalByLocal = OffsetDate(date2, offset1);

      TestHelper.TestEqualsStruct(equal1, equal2, [unequalByOffset]);
      TestHelper.TestEqualsStruct(equal1, equal2, [unequalByLocal]);

      TestHelper.TestOperatorEquality(equal1, equal2, unequalByOffset);
      TestHelper.TestOperatorEquality(equal1, equal2, unequalByLocal);
    },

    'At': (args) {
      var date = LocalDate(2012, 6, 19, CalendarSystem.Julian);
      var offset = Offset.FromHours(5);
      var time = LocalTime(14, 15, 12).PlusNanoseconds(123456789);

      Assert.AreEqual(OffsetDate(date, offset).At(time), date.At(time).WithOffset(offset));
    },

    'WithOffset': (args) {
      var date = LocalDate(2012, 6, 19);
      var initial = OffsetDate(date, Offset.FromHours(2));
      var actual = initial.WithOffset(Offset.FromHours(5));
      var expected = OffsetDate(date, Offset.FromHours(5));
      Assert.AreEqual(expected, actual);
    },

    'WithCalendar': (args) {
      var julianDate = LocalDate(2012, 6, 19, CalendarSystem.Julian);
      var isoDate = julianDate.WithCalendar(CalendarSystem.Iso);
      var offset = Offset.FromHours(5);
      var actual = OffsetDate(julianDate, offset).WithCalendar(CalendarSystem.Iso);
      var expected = OffsetDate(isoDate, offset);
      Assert.AreEqual(expected, actual);
    },

    'WithAdjuster': (args) {
      var initial = OffsetDate(LocalDate(2016, 6, 19), Offset.FromHours(-5));
      var actual = initial.With(DateAdjusters.StartOfMonth);
      var expected = OffsetDate(LocalDate(2016, 6, 1), Offset.FromHours(-5));
      Assert.AreEqual(expected, actual);
    },

    'ToString_WithFormat': (args) {
      LocalDate date = LocalDate(2012, 10, 6);
      Offset offset = Offset.FromHours(1);
      OffsetDate offsetDate = OffsetDate(date, offset);
      Assert.AreEqual('2012/10/06 01', offsetDate.ToStringPattern('uuuu/MM/dd o<-HH>', NodaCultureInfo.InvariantCulture));
    },

    'ToString_WithNullFormat': (args) {
      LocalDate date = LocalDate(2012, 10, 6);
      Offset offset = Offset.FromHours(1);
      OffsetDate offsetDate = OffsetDate(date, offset);
      Assert.AreEqual('2012-10-06+01', offsetDate.ToStringPattern(null, NodaCultureInfo.InvariantCulture));
    },

    'ToString_NoFormat': (args) {
      LocalDate date = LocalDate(2012, 10, 6);
      Offset offset = Offset.FromHours(1);
      OffsetDate offsetDate = OffsetDate(date, offset);
      // noda_dart: toString() always uses the invariant culture (no CultureSaver needed).
      Assert.AreEqual('2012-10-06+01', offsetDate.toString());
    },

    'Deconstruction': (args) {
      LocalDate date = LocalDate(2015, 3, 28);
      Offset offset = Offset.FromHours(-2);
      OffsetDate offsetDate = OffsetDate(date, offset);

      var (actualDate, actualOffset) = offsetDate.Deconstruct;

      Assert.Multiple(() {
        Assert.AreEqual(date, actualDate);
        Assert.AreEqual(offset, actualOffset);
      });
    },
  }, skip: {
    'XmlSerialization_Iso': SkipReasons.Xml,
    'XmlSerialization_Bce': SkipReasons.Xml,
    'XmlSerialization_NonIso': SkipReasons.Xml,
    'XmlSerialization_Invalid': SkipReasons.Xml,
  });
}
