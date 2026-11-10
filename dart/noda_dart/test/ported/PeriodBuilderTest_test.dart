// Ported from NodaTime 6e024dde: src/NodaTime.Test/PeriodBuilderTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: C#'s object initializers are cascades.

import 'package:noda_dart/src/Period.dart';
import 'package:noda_dart/src/PeriodBuilder.dart';
import 'package:noda_dart/src/PeriodUnits.generated.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../scenarios/PeriodBuilderTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'Indexer_Getter_ValidUnits': (args) {
      var builder = PeriodBuilder()
        ..Months = 1
        ..Weeks = 2
        ..Days = 3
        ..Hours = 4
        ..Minutes = 5
        ..Seconds = 6
        ..Milliseconds = 7
        ..Ticks = 8
        ..Nanoseconds = 9;
      Assert.AreEqual(0, builder[PeriodUnits.Years]);
      Assert.AreEqual(1, builder[PeriodUnits.Months]);
      Assert.AreEqual(2, builder[PeriodUnits.Weeks]);
      Assert.AreEqual(3, builder[PeriodUnits.Days]);
      Assert.AreEqual(4, builder[PeriodUnits.Hours]);
      Assert.AreEqual(5, builder[PeriodUnits.Minutes]);
      Assert.AreEqual(6, builder[PeriodUnits.Seconds]);
      Assert.AreEqual(7, builder[PeriodUnits.Milliseconds]);
      Assert.AreEqual(8, builder[PeriodUnits.Ticks]);
      Assert.AreEqual(9, builder[PeriodUnits.Nanoseconds]);
    },

    'Index_Getter_InvalidUnits': (args) {
      var builder = PeriodBuilder();
      Assert.Throws<RangeError>(() => Call(builder[PeriodUnits(0)]));
      Assert.Throws<RangeError>(() => Call(builder[PeriodUnits(-1)]));
      Assert.Throws<RangeError>(() => Call(builder[PeriodUnits.DateAndTime]));
    },

    'Indexer_Setter_ValidUnits': (args) {
      var builder = PeriodBuilder();
      builder[PeriodUnits.Months] = 1;
      builder[PeriodUnits.Weeks] = 2;
      builder[PeriodUnits.Days] = 3;
      builder[PeriodUnits.Hours] = 4;
      builder[PeriodUnits.Minutes] = 5;
      builder[PeriodUnits.Seconds] = 6;
      builder[PeriodUnits.Milliseconds] = 7;
      builder[PeriodUnits.Ticks] = 8;
      var expected = (PeriodBuilder()
            ..Years = 0
            ..Months = 1
            ..Weeks = 2
            ..Days = 3
            ..Hours = 4
            ..Minutes = 5
            ..Seconds = 6
            ..Milliseconds = 7
            ..Ticks = 8)
          .Build();
      Assert.AreEqual(expected, builder.Build());
    },

    'Index_Setter_InvalidUnits': (args) {
      var builder = PeriodBuilder();
      Assert.Throws<RangeError>(() => builder[PeriodUnits(0)] = 1);
      Assert.Throws<RangeError>(() => builder[PeriodUnits(-1)] = 1);
      Assert.Throws<RangeError>(() => builder[PeriodUnits.DateAndTime] = 1);
    },

    'Build_SingleUnit': (args) {
      Period period = (PeriodBuilder()..Hours = 10).Build();

      Period expected = Period.FromHours(10);
      Assert.AreEqual(expected, period);
    },

    'Build_MultipleUnits': (args) {
      Period period = (PeriodBuilder()
            ..Days = 5
            ..Minutes = -10)
          .Build();

      Period expected = Period.FromDays(5) + Period.FromMinutes(-10);
      Assert.AreEqual(expected, period);
    },

    'Build_Zero': (args) {
      Assert.AreEqual(Period.Zero, PeriodBuilder().Build());
    },
  }, skip: {
    'XmlSerialization': SkipReasons.Xml,
    'XmlSerialization_ExpectedUse': SkipReasons.Xml,
  });
}

// Not ported: XmlSerializationDemo and BuilderEqualityComparer (only used by the XML serialization tests).

void Call(Object ignored) {}
