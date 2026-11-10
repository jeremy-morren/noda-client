// Ported from NodaTime 6e024dde: src/NodaTime.Test/AnnualDateTest.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: ToString(format, provider) is ToStringPattern.

import 'package:noda_dart/src/AnnualDate.dart';
import 'package:noda_dart/src/LocalDate.dart';

import '../helpers/Assertions.dart';
import '../helpers/Decode.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/AnnualDateTest.generated.dart' as scenarios;
import '../scenarios/cultures.generated.dart';

void main() {
  port(scenarios.fixture, {
    'Feb29': (args) {
      var date = AnnualDate(2, 29);
      Assert.AreEqual(29, date.Day);
      Assert.AreEqual(2, date.Month);
      Assert.AreEqual(LocalDate(2016, 2, 29), date.InYear(2016));
      Assert.IsTrue(date.IsValidYear(2016));
      Assert.AreEqual(LocalDate(2015, 2, 28), date.InYear(2015));
      Assert.IsFalse(date.IsValidYear(2015));
    },

    'June19': (args) {
      var date = AnnualDate(6, 19);
      Assert.AreEqual(19, date.Day);
      Assert.AreEqual(6, date.Month);
      Assert.AreEqual(LocalDate(2016, 6, 19), date.InYear(2016));
      Assert.IsTrue(date.IsValidYear(2016));
      Assert.AreEqual(LocalDate(2015, 6, 19), date.InYear(2015));
      Assert.IsTrue(date.IsValidYear(2015));
    },

    'Validation': (args) {
      // Feb 30th is invalid, but January 30th is fine
      Assert.Throws<RangeError>(() => AnnualDate(2, 30));
      AnnualDate(1, 30).Consume();

      // 13th month is invalid
      Assert.Throws<RangeError>(() => AnnualDate(13, 1));
    },

    'EqualityAndComparision': (args) {
      var value = AnnualDate(6, 19);
      var equalValue = AnnualDate(6, 19);
      var greaterValue1 = AnnualDate(6, 20);
      var greaterValue2 = AnnualDate(7, 1);

      TestHelper.TestEqualsStruct(value, equalValue, [greaterValue1, greaterValue2]);
      TestHelper.TestCompareToStruct(value, equalValue, [greaterValue1, greaterValue2]);
      TestHelper.TestNonGenericCompareTo(value, equalValue, [greaterValue1, greaterValue2]);
      TestHelper.TestOperatorComparisonEquality(value, equalValue, [greaterValue1, greaterValue2]);
      TestHelper.TestOperatorComparison(value, equalValue, [greaterValue1, greaterValue2]);
    },

    'ToStringTest': (args) {
      Assert.AreEqual('02-01', AnnualDate(2, 1).toString());
      Assert.AreEqual('02-10', AnnualDate(2, 10).toString());
      Assert.AreEqual('12-01', AnnualDate(12, 1).toString());
      Assert.AreEqual('12-20', AnnualDate(12, 20).toString());
    },

    'ToString_WithFormat': (args) {
      Assert.AreEqual('02-01', AnnualDate(2, 1).ToStringPattern('G', scenarioCulture('Cultures.FrFr')));
      Assert.AreEqual('02-01', AnnualDate(2, 1).ToStringPattern(null, scenarioCulture('Cultures.FrFr')));
      Assert.AreEqual('02/01', AnnualDate(2, 1).ToStringPattern('MM/dd', scenarioCulture('Cultures.FrFr')));
      Assert.AreEqual('02-01', AnnualDate(2, 1).ToStringPattern('MM/dd', scenarioCulture('Cultures.FrCa')));
    },
  }, skip: {
    'DefaultValueIsJanuary1st': SkipReasons.DefaultConstructor,
    'XmlSerialization': SkipReasons.Xml,
    'XmlSerialization_Invalid': SkipReasons.Xml,
  }, cultures: scenarioCultures);
}
