// Ported from NodaTime 6e024dde: src/NodaTime.Test/Globalization/NodaFormatInfoTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: NodaCultureInfo is immutable: `new CultureInfo(name)` and Clone() are FromData (with CopyWith).
// CultureSaver isn't ported; tests using it only to show the current culture isn't used run without it.

import 'package:noda_dart/src/Calendars/Era.dart';
import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:noda_dart/src/Globalization/NodaFormatInfo.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Decode.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Globalization/NodaFormatInfoTest.generated.dart' as scenarios;
import '../../scenarios/cultures.generated.dart';

final NodaCultureInfo enUs = scenarioCulture('en-US');
final NodaCultureInfo enGb = scenarioCulture('en-GB');

void main() {
  port(scenarios.fixture, {
    // Just check we can actually build a NodaFormatInfo for every culture, outside
    // text-specific tests.
    'ConvertCulture': (args) {
      final [NodaCultureInfo culture] = args;
      NodaFormatInfo.GetFormatInfo(culture);
    },

    'TestCachingWithReadOnly': (args) {
      var original = NewCultureInfo('en-US');
      // Use a read-only wrapper so that it gets cached
      // (noda_dart: cultures are always read-only.)
      var wrapper = original;

      var nodaWrapper1 = NodaFormatInfo.GetFormatInfo(wrapper);
      var nodaWrapper2 = NodaFormatInfo.GetFormatInfo(wrapper);
      Assert.AreSame(nodaWrapper1, nodaWrapper2);
    },

    'TestCachingWithClonedCulture': (args) {
      var data = scenarioCultures['en-US']!;
      var original = NodaCultureInfo.FromData(data);
      var dayNames = [...data.DateTimeFormat.DayNames];
      dayNames[1] = '@@@';
      var clone = NodaCultureInfo.FromData(data.CopyWith(DateTimeFormat: data.DateTimeFormat.CopyWith(DayNames: dayNames)));
      Assert.AreEqual(original.Name, clone.Name);

      // Fool Noda Time into believing both are read-only, so it can use a cache...
      // (noda_dart: cultures are always read-only.)

      var nodaOriginal = NodaFormatInfo.GetFormatInfo(original);
      var nodaClone = NodaFormatInfo.GetFormatInfo(clone);
      Assert.AreEqual(original.DateTimeFormat.DayNames[1], nodaOriginal.LongDayNames[1]);
      Assert.AreEqual(clone.DateTimeFormat.DayNames[1], nodaClone.LongDayNames[1]);
      // Just check we made a difference...
      Assert.AreNotEqual(nodaOriginal.LongDayNames[1], nodaClone.LongDayNames[1]);
    },

    'TestConstructor': (args) {
      final [bool initializeEagerly] = args;
      var info = NodaFormatInfo.NewCultureInfoInitializeEagerly(enUs, initializeEagerly);
      Assert.AreSame(enUs, info.CultureInfo);
      Assert.NotNull(info.DateTimeFormat);
      Assert.AreEqual(':', info.TimeSeparator);
      Assert.AreEqual('/', info.DateSeparator);
      Assert.IsInstanceOf<String>(info.OffsetPatternLong);
      Assert.IsInstanceOf<String>(info.OffsetPatternMedium);
      Assert.IsInstanceOf<String>(info.OffsetPatternShort);
      Assert.AreEqual('NodaFormatInfo[en-US]', info.toString());
    },

    'TestDateTimeFormat': (args) {
      var format = DateTimeFormatInfo.InvariantInfo;
      var info = NodaFormatInfo.NewCultureInfoInitializeEagerly(enUs, true);
      Assert.AreNotEqual(format, info.DateTimeFormat);
    },

    'TestGetFormatInfo': (args) {
      NodaFormatInfo.ClearCache();
      var info1 = NodaFormatInfo.GetFormatInfo(enUs);
      Assert.NotNull(info1);

      var info2 = NodaFormatInfo.GetFormatInfo(enUs);
      Assert.AreSame(info1, info2);

      var info3 = NodaFormatInfo.GetFormatInfo(enGb);
      Assert.AreNotSame(info1, info3);
    },

    'TestGetInstance_CultureInfo': (args) {
      NodaFormatInfo.ClearCache();
      // Not ported: CultureSaver.SetCultures (the current culture can't be set).
      var actual = NodaFormatInfo.GetInstance(enGb);
      Assert.AreSame(enGb, actual.CultureInfo);
    },

    'TestGetInstance_UnusableType': (args) {
      NodaFormatInfo.ClearCache();
          // noda_dart: no NumberFormatInfo: another provider that's neither a culture nor a DateTimeFormatInfo.
      Assert.Throws<ArgumentError>(() => NodaFormatInfo.GetInstance(NumberFormatInfo()));
    },

    'TestGetInstance_DateTimeFormatInfo': (args) {
      NodaFormatInfo.ClearCache();
      // Not ported: CultureSaver.SetCultures(enUs, FailingCultureInfo.Instance) (as above).
      var info = NodaFormatInfo.GetInstance(enGb.DateTimeFormat);
      Assert.AreEqual(enGb.DateTimeFormat, info.DateTimeFormat);
      Assert.AreEqual(NodaCultureInfo.InvariantCulture, info.CultureInfo);
    },

    'TestOffsetPatternLong': (args) {
      const String pattern = 'This is a test';
      var info = NodaFormatInfo.NewCultureInfoInitializeEagerly(enUs, false);
      Assert.AreNotEqual(pattern, info.OffsetPatternLong);
    },

    'TestOffsetPatternMedium': (args) {
      const String pattern = 'This is a test';
      var info = NodaFormatInfo.NewCultureInfoInitializeEagerly(enUs, false);
      Assert.AreNotEqual(pattern, info.OffsetPatternMedium);
    },

    'TestOffsetPatternShort': (args) {
      const String pattern = 'This is a test';
      var info = NodaFormatInfo.NewCultureInfoInitializeEagerly(enUs, false);
      Assert.AreNotEqual(pattern, info.OffsetPatternShort);
    },

    'TestGetEraNames': (args) {
      var info = NodaFormatInfo.GetFormatInfo(enUs);
      List<String> names = info.GetEraNames(Era.BeforeCommon);
      CollectionAssert.AreEqual(['B.C.E.', 'B.C.', 'BCE', 'BC'], names);
    },

    'TestGetEraNames_NoSuchEra': (args) {
      var info = NodaFormatInfo.GetFormatInfo(enUs);
      Assert.AreEqual(0, info.GetEraNames(Era.NewNameResourceIdentifier('Ignored', 'NonExistentResource')).length);
    },

    'TestGetEraPrimaryName': (args) {
      var info = NodaFormatInfo.GetFormatInfo(enUs);
      Assert.AreEqual('B.C.', info.GetEraPrimaryName(Era.BeforeCommon));
    },

    'TestGetEraPrimaryName_NoSuchEra': (args) {
      var info = NodaFormatInfo.GetFormatInfo(enUs);
      Assert.AreEqual('', info.GetEraPrimaryName(Era.NewNameResourceIdentifier('Ignored', 'NonExistentResource')));
    },

    'TestIntegerGenitiveMonthNames': (args) {
      // Emulate behavior of Mono 3.0.6
      var invariant = NodaCultureInfo.InvariantCulture;
      var numbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];
      var culture = NodaCultureInfo.FromData(CultureData(
          Name: invariant.Name,
          DateTimeFormat:
              invariant.DateTimeFormat.CopyWith(MonthGenitiveNames: numbers, AbbreviatedMonthGenitiveNames: numbers)));
      var info = NodaFormatInfo.GetFormatInfo(culture);
      CollectionAssert.AreEqual(info.LongMonthGenitiveNames, info.LongMonthNames);
      CollectionAssert.AreEqual(info.ShortMonthGenitiveNames, info.ShortMonthNames);
    },
  }, skip: {
    'TestConstructor_null': SkipReasons.NullSafety,
    'TestGetFormatInfo_null': SkipReasons.NullSafety,
    'TestGetInstance_null': "Checks that a null provider means CultureInfo.CurrentCulture (set with CultureSaver); "
        'in noda_dart a null provider means the invariant culture',
    'TestEraGetNames_Null': SkipReasons.NullSafety,
    'TestEraGetEraPrimaryName_Null': SkipReasons.NullSafety,
  }, cultures: scenarioCultures);
}

/// noda_dart: C#'s `new CultureInfo(name)`: a new (not cached) culture with the same data.
NodaCultureInfo NewCultureInfo(String name) => NodaCultureInfo.FromData(scenarioCultures[name]!);

/// noda_dart: stands in for .NET's NumberFormatInfo, an IFormatProvider NodaTime can't use.
final class NumberFormatInfo implements IFormatProvider {}
