// Ported from NodaTime 6e024dde: src/NodaTime.Test/DateTimeZoneTest.cs (+ DateTimeZoneTest.GetZoneIntervals.cs,
// DateTimeZoneTest.Ids.cs, DateTimeZoneTest.LocalConversions.cs, DateTimeZoneTest.MapLocal.cs)
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/AmbiguousTimeException.dart';
import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/Interval.dart';
import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/SkippedTimeException.dart';
import 'package:noda_dart/src/Testing/TimeZones/MultiTransitionDateTimeZone.dart';
import 'package:noda_dart/src/Testing/TimeZones/SingleTransitionDateTimeZone.dart';
import 'package:noda_dart/src/Text/LocalDatePattern.dart';
import 'package:noda_dart/src/TimeZones/Resolvers.dart';
import 'package:noda_dart/src/TimeZones/ZoneEqualityComparer.Options.generated.dart';
import 'package:noda_dart/src/TimeZones/ZoneInterval.dart';
import 'package:noda_dart/src/TimeZones/ZoneLocalMapping.dart';
import 'package:noda_dart/src/ZonedDateTime.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../scenarios/DateTimeZoneTest.generated.dart' as scenarios;

// #region DateTimeZoneTest.GetZoneIntervals.cs
final SingleTransitionDateTimeZone TestZone = SingleTransitionDateTimeZone(Instant.FromUtc(2000, 1, 1, 0, 0), -3, 4);
// #endregion

// #region DateTimeZoneTest.LocalConversions.cs
// Sample time zones for DateTimeZone.AtStartOfDay etc. I didn't want to only test midnight transitions.
final DateTimeZone LosAngeles = DateTimeZoneProviders.Tzdb['America/Los_Angeles'];
final DateTimeZone NewZealand = DateTimeZoneProviders.Tzdb['Pacific/Auckland'];
final DateTimeZone Paris = DateTimeZoneProviders.Tzdb['Europe/Paris'];
final DateTimeZone NewYork = DateTimeZoneProviders.Tzdb['America/New_York'];
final DateTimeZone Pacific = DateTimeZoneProviders.Tzdb['America/Los_Angeles'];

/// Local midnight at the start of the transition (June 1st) becomes 1am.
final DateTimeZone TransitionForwardAtMidnightZone = SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(
    Instant.FromUtc(2000, 6, 1, 2, 0), Offset.FromHours(-2), Offset.FromHours(-1));

/// Local 1am at the start of the transition (June 1st) becomes midnight.
final DateTimeZone TransitionBackwardToMidnightZone = SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(
    Instant.FromUtc(2000, 6, 1, 3, 0), Offset.FromHours(-2), Offset.FromHours(-3));

/// Local 11.20pm at the start of the transition (May 30th) becomes 12.20am of June 1st.
final DateTimeZone TransitionForwardBeforeMidnightZone =
    SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(
        Instant.FromUtc(2000, 6, 1, 1, 20), Offset.FromHours(-2), Offset.FromHours(-1));

/// Local 12.20am at the start of the transition (June 1st) becomes 11.20pm of the previous day.
final DateTimeZone TransitionBackwardAfterMidnightZone =
    SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(
        Instant.FromUtc(2000, 6, 1, 2, 20), Offset.FromHours(-2), Offset.FromHours(-3));

final LocalDate TransitionDate = LocalDate(2000, 6, 1);
// #endregion

// #region DateTimeZoneTest.MapLocal.cs
final Instant Transition = Instant.FromUtc(2000, 1, 1, 0, 0);

final Offset Minus5 = Offset.FromHours(-5);
final Offset Plus10 = Offset.FromHours(10);

final LocalDateTime NearStartOfTime = LocalDateTime(-9998, 1, 5, 0, 0);
final LocalDateTime NearEndOfTime = LocalDateTime(9999, 12, 25, 0, 0);
final LocalDateTime TransitionMinus5 = Transition.WithOffset(Minus5).LocalDateTime;
final LocalDateTime TransitionPlus10 = Transition.WithOffset(Plus10).LocalDateTime;
final LocalDateTime MidTransition = Transition.WithOffset(Offset.Zero).LocalDateTime;

final LocalDateTime YearBeforeTransition = LocalDateTime(1999, 1, 1, 0, 0);
final LocalDateTime YearAfterTransition = LocalDateTime(2001, 1, 1, 0, 0);

final SingleTransitionDateTimeZone ZoneWithGap =
    SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(Transition, Minus5, Plus10);
final ZoneInterval IntervalBeforeGap = ZoneWithGap.EarlyInterval;
final ZoneInterval IntervalAfterGap = ZoneWithGap.LateInterval;

final SingleTransitionDateTimeZone ZoneWithAmbiguity =
    SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(Transition, Plus10, Minus5);
final ZoneInterval IntervalBeforeAmbiguity = ZoneWithAmbiguity.EarlyInterval;
final ZoneInterval IntervalAfterAmbiguity = ZoneWithAmbiguity.LateInterval;
// #endregion

void main() {
  port(scenarios.fixture, {
    // #region DateTimeZoneTest.cs
    // The current implementation caches every half hour, -12 to +15.
    'ForOffset_UncachedExample_NotOnHalfHour': (args) {
      var offset = Offset.FromSeconds(123);
      var zone1 = DateTimeZone.ForOffset(offset);
      var zone2 = DateTimeZone.ForOffset(offset);

      Assert.AreNotSame(zone1, zone2);
      Assert.IsTrue(zone1.IsFixed);
      Assert.AreEqual(offset, zone1.MaxOffset);
      Assert.AreEqual(offset, zone1.MinOffset);
    },

    'ForOffset_UncachedExample_OutsideCacheRange': (args) {
      var offset = Offset.FromHours(-14);
      var zone1 = DateTimeZone.ForOffset(offset);
      var zone2 = DateTimeZone.ForOffset(offset);

      Assert.AreNotSame(zone1, zone2);
      Assert.IsTrue(zone1.IsFixed);
      Assert.AreEqual(offset, zone1.MaxOffset);
      Assert.AreEqual(offset, zone1.MinOffset);
    },

    'ForOffset_CachedExample': (args) {
      var offset = Offset.FromHours(2);
      var zone1 = DateTimeZone.ForOffset(offset);
      var zone2 = DateTimeZone.ForOffset(offset);
      // Caching check...
      Assert.AreSame(zone1, zone2);

      Assert.IsTrue(zone1.IsFixed);
      Assert.AreEqual(offset, zone1.MaxOffset);
      Assert.AreEqual(offset, zone1.MinOffset);
    },

    'ForOffset_Zero_SameAsUtc': (args) {
      Assert.AreSame(DateTimeZone.Utc, DateTimeZone.ForOffset(Offset.Zero));
    },
    // #endregion

    // #region DateTimeZoneTest.GetZoneIntervals.cs
    'GetZoneIntervals_EndBeforeStart': (args) {
      Assert.Throws<RangeError>(
          () => DateTimeZone.Utc.GetZoneIntervals(Instant.FromUnixTimeTicks(100), Instant.FromUnixTimeTicks(99)));
    },

    'GetZoneIntervals_EndEqualToStart': (args) {
      CollectionAssert.IsEmpty(
          DateTimeZone.Utc.GetZoneIntervals(Instant.FromUnixTimeTicks(100), Instant.FromUnixTimeTicks(100)));
    },

    'GetZoneIntervals_InvalidOptions': (args) {
      var zone = DateTimeZone.Utc;
      var interval = Interval(Instant.FromUtc(2000, 1, 1, 0, 0), Instant.FromUtc(2001, 1, 1, 0, 0));
      Assert.Throws<RangeError>(
          () => zone.GetZoneIntervalsInterval(interval, ZoneEqualityComparerOptions(1234567)).toList());
    },

    'GetZoneIntervals_FixedZone': (args) {
      var zone = DateTimeZone.ForOffset(Offset.FromHours(3));
      var expected = [zone.GetZoneInterval(Instant.MinValue)];
      // Give a reasonably wide interval...
      var actual = zone.GetZoneIntervals(Instant.FromUtc(1900, 1, 1, 0, 0), Instant.FromUtc(2100, 1, 1, 0, 0));
      CollectionAssert.AreEqual(expected, actual.toList());
    },

    'GetZoneIntervals_SingleTransitionZone_IntervalCoversTransition': (args) {
      Instant start = TestZone.Transition.MinusDuration(Duration.FromDays(5));
      Instant end = TestZone.Transition + Duration.FromDays(5);
      var expected = [TestZone.EarlyInterval, TestZone.LateInterval];
      var actual = TestZone.GetZoneIntervals(start, end);
      CollectionAssert.AreEqual(expected, actual.toList());
    },

    'GetZoneIntervals_SingleTransitionZone_IntervalDoesNotCoverTransition': (args) {
      Instant start = TestZone.Transition.MinusDuration(Duration.FromDays(10));
      Instant end = TestZone.Transition.MinusDuration(Duration.FromDays(5));
      var expected = [TestZone.EarlyInterval];
      var actual = TestZone.GetZoneIntervals(start, end);
      CollectionAssert.AreEqual(expected, actual.toList());
    },

    'GetZoneIntervals_IncludesStart': (args) {
      Instant start = TestZone.Transition.MinusDuration(Duration.Epsilon);
      Instant end = TestZone.Transition + Duration.FromDays(5);
      var expected = [TestZone.EarlyInterval, TestZone.LateInterval];
      var actual = TestZone.GetZoneIntervals(start, end);
      CollectionAssert.AreEqual(expected, actual.toList());
    },

    'GetZoneIntervals_ExcludesEnd': (args) {
      Instant start = TestZone.Transition.MinusDuration(Duration.FromDays(10));
      Instant end = TestZone.Transition;
      var expected = [TestZone.EarlyInterval];
      var actual = TestZone.GetZoneIntervals(start, end);
      CollectionAssert.AreEqual(expected, actual.toList());
    },

    'GetZoneIntervals_Complex': (args) {
      var london = DateTimeZoneProviders.Tzdb['Europe/London'];
      // Transitions are always Spring/Autumn, so June and January should be clear.
      var expected = [
        london.GetZoneInterval(Instant.FromUtc(1999, 6, 1, 0, 0)),
        london.GetZoneInterval(Instant.FromUtc(2000, 1, 1, 0, 0)),
        london.GetZoneInterval(Instant.FromUtc(2000, 6, 1, 0, 0)),
        london.GetZoneInterval(Instant.FromUtc(2001, 1, 1, 0, 0)),
        london.GetZoneInterval(Instant.FromUtc(2001, 6, 1, 0, 0)),
        london.GetZoneInterval(Instant.FromUtc(2002, 1, 1, 0, 0)),
      ];
      // After the instant we used to fetch the expected zone interval, but that's fine:
      // it'll be the same one, as there's no transition within June.
      var start = Instant.FromUtc(1999, 6, 19, 0, 0);
      var end = Instant.FromUtc(2002, 2, 4, 0, 0);
      var actual = london.GetZoneIntervals(start, end);
      CollectionAssert.AreEqual(expected, actual.toList());
      // Just to exercise the other overload
      actual = london.GetZoneIntervalsInterval(Interval(start, end));
      CollectionAssert.AreEqual(expected, actual.toList());
    },

    'GetZoneIntervals_IntervalWithNoStart': (args) {
      var london = DateTimeZoneProviders.Tzdb['Europe/London'];
      // First transition is 1847-12-01T00:01:15Z; the next is in 1916.
      var expected = [
        london.GetZoneInterval(Instant.FromUtc(1847, 6, 1, 0, 0)),
        london.GetZoneInterval(Instant.FromUtc(1848, 1, 1, 0, 0)),
      ];
      var interval = Interval(null, Instant.FromUtc(1849, 3, 1, 0, 0));
      var actual = london.GetZoneIntervalsInterval(interval);
      CollectionAssert.AreEqual(expected, actual.toList());
    },

    'GetZoneIntervals_IntervalWithNoEnd': (args) {
      var london = DateTimeZoneProviders.Tzdb['Europe/London'];
      var expected = [
        london.GetZoneInterval(Instant.FromUtc(9998, 1, 1, 0, 0)),
        london.GetZoneInterval(Instant.FromUtc(9998, 6, 1, 0, 0)),
        london.GetZoneInterval(Instant.FromUtc(9999, 1, 1, 0, 0)),
        london.GetZoneInterval(Instant.FromUtc(9999, 6, 1, 0, 0)),
        london.GetZoneInterval(Instant.FromUtc(9999, 11, 1, 0, 0)),
      ];
      var interval = Interval(Instant.FromUtc(9998, 1, 1, 0, 0), null);
      var actual = london.GetZoneIntervalsInterval(interval);
      CollectionAssert.AreEqual(expected, actual.toList());
    },

    'GetZoneIntervals_WithOptions_NoCoalescing': (args) {
      // We'll ask for 1999-2003, so there are three transitions within that.
      var transition1 = Instant.FromUtc(2000, 1, 1, 0, 0);
      var transition2 = Instant.FromUtc(2001, 1, 1, 0, 0);
      var transition3 = Instant.FromUtc(2002, 1, 1, 0, 0);
      // And one transition afterwards.
      var transition4 = Instant.FromUtc(2004, 1, 1, 0, 0);
      var zone = (MultiTransitionDateTimeZoneBuilder(0, 0, '0+0')
            ..Add(transition1, 1, 1, '1+1')
            ..Add(transition2, 0, 2, '0+2')
            ..Add(transition3, 0, 1, '0+1')
            ..Add(transition4, 0, 0, '0+0'))
          .Build();
      var interval = Interval(Instant.FromUtc(1999, 1, 1, 0, 0), Instant.FromUtc(2003, 1, 1, 0, 0));
      // No coalescing required, as the names are different.
      var zoneIntervals = zone.GetZoneIntervalsInterval(interval, ZoneEqualityComparerOptions.MatchNames).toList();
      Assert.AreEqual(4, zoneIntervals.length);
      CollectionAssert.AreEqual([transition1, transition2, transition3, transition4], zoneIntervals.map((zi) => zi.End));
    },

    'GetZoneIntervals_WithOptions_Coalescing': (args) {
      // We'll ask for 1999-2003, so there are three transitions within that.
      var transition1 = Instant.FromUtc(2000, 1, 1, 0, 0);
      var transition2 = Instant.FromUtc(2001, 1, 1, 0, 0);
      var transition3 = Instant.FromUtc(2002, 1, 1, 0, 0);
      // And one transition afterwards.
      var transition4 = Instant.FromUtc(2004, 1, 1, 0, 0);
      var zone = (MultiTransitionDateTimeZoneBuilder(0, 0, '0+0')
            ..Add(transition1, 1, 1, '1+1')
            ..Add(transition2, 0, 2, '0+2')
            ..Add(transition3, 0, 1, '0+1')
            ..Add(transition4, 0, 0, '0+0'))
          .Build();
      var interval = Interval(Instant.FromUtc(1999, 1, 1, 0, 0), Instant.FromUtc(2003, 1, 1, 0, 0));
      // The zone intervals abutting at transition2 are coalesced,
      // because that only changes the name and standard/daylight split.
      var zoneIntervals =
          zone.GetZoneIntervalsInterval(interval, ZoneEqualityComparerOptions.OnlyMatchWallOffset).toList();
      Assert.AreEqual(3, zoneIntervals.length);
      CollectionAssert.AreEqual([transition1, transition3, transition4], zoneIntervals.map((zi) => zi.End));
      CollectionAssert.AreEqual(
          [Instant.BeforeMinValue, transition1, transition3], zoneIntervals.map((zi) => zi.RawStart));
      CollectionAssert.AreEqual(['0+0', '1+1', '0+1'], zoneIntervals.map((zi) => zi.Name));
    },
    // #endregion

    // #region DateTimeZoneTest.Ids.cs
    'UtcIsNotNull': (args) {
      Assert.IsNotNull(DateTimeZone.Utc);
    },
    // #endregion

    // #region DateTimeZoneTest.LocalConversions.cs
    'AmbiguousStartOfDay_TransitionAtMidnight': (args) {
      // Occurrence before transition
      var expected = ZonedDateTime.NewOffsetDateTimeZone(
          LocalDateTime(2000, 6, 1, 0, 0).WithOffset(Offset.FromHours(-2)), TransitionBackwardToMidnightZone);
      var actual = TransitionBackwardToMidnightZone.AtStartOfDay(TransitionDate);
      Assert.AreEqual(expected, actual);
      Assert.AreEqual(expected, TransitionDate.AtStartOfDayInZone(TransitionBackwardToMidnightZone));
    },

    'AmbiguousStartOfDay_TransitionAfterMidnight': (args) {
      // Occurrence before transition
      var expected = ZonedDateTime.NewOffsetDateTimeZone(
          LocalDateTime(2000, 6, 1, 0, 0).WithOffset(Offset.FromHours(-2)), TransitionBackwardAfterMidnightZone);
      var actual = TransitionBackwardAfterMidnightZone.AtStartOfDay(TransitionDate);
      Assert.AreEqual(expected, actual);
      Assert.AreEqual(expected, TransitionDate.AtStartOfDayInZone(TransitionBackwardAfterMidnightZone));
    },

    'SkippedStartOfDay_TransitionAtMidnight': (args) {
      // 1am because of the skip
      var expected = ZonedDateTime.NewOffsetDateTimeZone(
          LocalDateTime(2000, 6, 1, 1, 0).WithOffset(Offset.FromHours(-1)), TransitionForwardAtMidnightZone);
      var actual = TransitionForwardAtMidnightZone.AtStartOfDay(TransitionDate);
      Assert.AreEqual(expected, actual);
      Assert.AreEqual(expected, TransitionDate.AtStartOfDayInZone(TransitionForwardAtMidnightZone));
    },

    'SkippedStartOfDay_TransitionBeforeMidnight': (args) {
      // 12.20am because of the skip
      var expected = ZonedDateTime.NewOffsetDateTimeZone(
          LocalDateTime(2000, 6, 1, 0, 20).WithOffset(Offset.FromHours(-1)), TransitionForwardBeforeMidnightZone);
      var actual = TransitionForwardBeforeMidnightZone.AtStartOfDay(TransitionDate);
      Assert.AreEqual(expected, actual);
      Assert.AreEqual(expected, TransitionDate.AtStartOfDayInZone(TransitionForwardBeforeMidnightZone));
    },

    'UnambiguousStartOfDay': (args) {
      // Just a simple midnight in March.
      var expected = ZonedDateTime.NewOffsetDateTimeZone(
          LocalDateTime(2000, 3, 1, 0, 0).WithOffset(Offset.FromHours(-2)), TransitionForwardAtMidnightZone);
      var actual = TransitionForwardAtMidnightZone.AtStartOfDay(LocalDate(2000, 3, 1));
      Assert.AreEqual(expected, actual);
      Assert.AreEqual(expected, LocalDate(2000, 3, 1).AtStartOfDayInZone(TransitionForwardAtMidnightZone));
    },

    // Los Angeles goes from -7 to -8 on November 7th 2010 at 2am wall time
    'GetOffsetFromLocal_LosAngelesFallTransition': (args) {
      var before = LocalDateTime(2010, 11, 7, 0, 30);
      var atTransition = LocalDateTime(2010, 11, 7, 1, 0);
      var ambiguous = LocalDateTime(2010, 11, 7, 1, 30);
      var after = LocalDateTime(2010, 11, 7, 2, 30);
      AssertOffset(-7, before, LosAngeles);
      AssertAmbiguous(atTransition, LosAngeles);
      AssertAmbiguous(ambiguous, LosAngeles);
      AssertOffset(-8, after, LosAngeles);
    },

    'GetOffsetFromLocal_LosAngelesSpringTransition': (args) {
      var before = LocalDateTime(2010, 3, 14, 1, 30);
      var impossible = LocalDateTime(2010, 3, 14, 2, 30);
      var atTransition = LocalDateTime(2010, 3, 14, 3, 0);
      var after = LocalDateTime(2010, 3, 14, 3, 30);
      AssertOffset(-8, before, LosAngeles);
      AssertImpossible(impossible, LosAngeles);
      AssertOffset(-7, atTransition, LosAngeles);
      AssertOffset(-7, after, LosAngeles);
    },

    // New Zealand goes from +13 to +12 on April 4th 2010 at 3am wall time
    'GetOffsetFromLocal_NewZealandFallTransition': (args) {
      var before = LocalDateTime(2010, 4, 4, 1, 30);
      var atTransition = LocalDateTime(2010, 4, 4, 2, 0);
      var ambiguous = LocalDateTime(2010, 4, 4, 2, 30);
      var after = LocalDateTime(2010, 4, 4, 3, 30);
      AssertOffset(13, before, NewZealand);
      AssertAmbiguous(atTransition, NewZealand);
      AssertAmbiguous(ambiguous, NewZealand);
      AssertOffset(12, after, NewZealand);
    },

    // New Zealand goes from +12 to +13 on September 26th 2010 at 2am wall time
    'GetOffsetFromLocal_NewZealandSpringTransition': (args) {
      var before = LocalDateTime(2010, 9, 26, 1, 30);
      var impossible = LocalDateTime(2010, 9, 26, 2, 30);
      var atTransition = LocalDateTime(2010, 9, 26, 3, 0);
      var after = LocalDateTime(2010, 9, 26, 3, 30);
      AssertOffset(12, before, NewZealand);
      AssertImpossible(impossible, NewZealand);
      AssertOffset(13, atTransition, NewZealand);
      AssertOffset(13, after, NewZealand);
    },

    // Paris goes from +1 to +2 on March 28th 2010 at 2am wall time
    'GetOffsetFromLocal_ParisFallTransition': (args) {
      var before = LocalDateTime(2010, 10, 31, 1, 30);
      var atTransition = LocalDateTime(2010, 10, 31, 2, 0);
      var ambiguous = LocalDateTime(2010, 10, 31, 2, 30);
      var after = LocalDateTime(2010, 10, 31, 3, 30);
      AssertOffset(2, before, Paris);
      AssertAmbiguous(ambiguous, Paris);
      AssertAmbiguous(atTransition, Paris);
      AssertOffset(1, after, Paris);
    },

    'GetOffsetFromLocal_ParisSpringTransition': (args) {
      var before = LocalDateTime(2010, 3, 28, 1, 30);
      var impossible = LocalDateTime(2010, 3, 28, 2, 30);
      var atTransition = LocalDateTime(2010, 3, 28, 3, 0);
      var after = LocalDateTime(2010, 3, 28, 3, 30);
      AssertOffset(1, before, Paris);
      AssertImpossible(impossible, Paris);
      AssertOffset(2, atTransition, Paris);
      AssertOffset(2, after, Paris);
    },

    'MapLocalDateTime_UnambiguousDateReturnsUnambiguousMapping': (args) {
      //2011-11-09 01:30:00 - not ambiguous in America/New York timezone
      var unambiguousTime = LocalDateTime(2011, 11, 9, 1, 30);
      var mapping = NewYork.MapLocal(unambiguousTime);
      Assert.AreEqual(1, mapping.Count);
    },

    'MapLocalDateTime_AmbiguousDateReturnsAmbiguousMapping': (args) {
      //2011-11-06 01:30:00 - falls during DST - EST conversion in America/New York timezone
      var ambiguousTime = LocalDateTime(2011, 11, 6, 1, 30);
      var mapping = NewYork.MapLocal(ambiguousTime);
      Assert.AreEqual(2, mapping.Count);
    },

    'MapLocalDateTime_SkippedDateReturnsSkippedMapping': (args) {
      //2011-03-13 02:30:00 - falls during EST - DST conversion in America/New York timezone
      var skippedTime = LocalDateTime(2011, 3, 13, 2, 30);
      var mapping = NewYork.MapLocal(skippedTime);
      Assert.AreEqual(0, mapping.Count);
    },

    // Some zones skipped dates by changing from UTC-lots to UTC+lots. For example, Samoa (Pacific/Apia)
    // skipped December 30th 2011, going from  23:59:59 December 29th local time UTC-10
    // to 00:00:00 December 31st local time UTC+14
    'AtStartOfDay_DayDoesntExist': (args) {
      final [String zoneId, String localDate] = args;
      LocalDate badDate = LocalDatePattern.Iso.Parse(localDate).Value;
      DateTimeZone zone = DateTimeZoneProviders.Tzdb[zoneId];
      var exception = Assert.Throws<SkippedTimeException>(() => zone.AtStartOfDay(badDate));
      Assert.AreEqual(badDate.At(LocalTime.Midnight), exception.LocalDateTime);
    },

    'AtStrictly_InWinter': (args) {
      var when = Pacific.AtStrictly(LocalDateTime(2009, 12, 22, 21, 39, 30));

      Assert.AreEqual(2009, when.Year);
      Assert.AreEqual(12, when.Month);
      Assert.AreEqual(22, when.Day);
      Assert.AreEqual(IsoDayOfWeek.Tuesday, when.DayOfWeek);
      Assert.AreEqual(21, when.Hour);
      Assert.AreEqual(39, when.Minute);
      Assert.AreEqual(30, when.Second);
      Assert.AreEqual(Offset.FromHours(-8), when.Offset);
    },

    'AtStrictly_InSummer': (args) {
      var when = Pacific.AtStrictly(LocalDateTime(2009, 6, 22, 21, 39, 30));

      Assert.AreEqual(2009, when.Year);
      Assert.AreEqual(6, when.Month);
      Assert.AreEqual(22, when.Day);
      Assert.AreEqual(21, when.Hour);
      Assert.AreEqual(39, when.Minute);
      Assert.AreEqual(30, when.Second);
      Assert.AreEqual(Offset.FromHours(-7), when.Offset);
    },

    /// Pacific time changed from -7 to -8 at 2am wall time on November 2nd 2009,
    /// so 2am became 1am.
    'AtStrictly_ThrowsWhenAmbiguous': (args) {
      Assert.Throws<AmbiguousTimeException>(() => Pacific.AtStrictly(LocalDateTime(2009, 11, 1, 1, 30, 0)));
    },

    /// Pacific time changed from -8 to -7 at 2am wall time on March 8th 2009,
    /// so 2am became 3am. This means that 2.30am doesn't exist on that day.
    'AtStrictly_ThrowsWhenSkipped': (args) {
      Assert.Throws<SkippedTimeException>(() => Pacific.AtStrictly(LocalDateTime(2009, 3, 8, 2, 30, 0)));
    },

    /// Pacific time changed from -7 to -8 at 2am wall time on November 2nd 2009,
    /// so 2am became 1am. We'll return the earlier result, i.e. with the offset of -7
    'AtLeniently_AmbiguousTime_ReturnsEarlierMapping': (args) {
      var local = LocalDateTime(2009, 11, 1, 1, 30, 0);
      var zoned = Pacific.AtLeniently(local);
      Assert.AreEqual(local, zoned.LocalDateTime);
      Assert.AreEqual(Offset.FromHours(-7), zoned.Offset);
    },

    /// Pacific time changed from -8 to -7 at 2am wall time on March 8th 2009,
    /// so 2am became 3am. This means that 2:30am doesn't exist on that day.
    /// We'll return 3:30am, the forward-shifted value.
    'AtLeniently_ReturnsForwardShiftedValue': (args) {
      var local = LocalDateTime(2009, 3, 8, 2, 30, 0);
      var zoned = Pacific.AtLeniently(local);
      Assert.AreEqual(LocalDateTime(2009, 3, 8, 3, 30, 0), zoned.LocalDateTime);
      Assert.AreEqual(Offset.FromHours(-7), zoned.Offset);
    },

    'ResolveLocal': (args) {
      // Don't need much for this - it only delegates.
      var ambiguous = LocalDateTime(2009, 11, 1, 1, 30, 0);
      var skipped = LocalDateTime(2009, 3, 8, 2, 30, 0);
      Assert.AreEqual(Pacific.AtLeniently(ambiguous), Pacific.ResolveLocal(ambiguous, Resolvers.LenientResolver));
      Assert.AreEqual(Pacific.AtLeniently(skipped), Pacific.ResolveLocal(skipped, Resolvers.LenientResolver));
    },
    // #endregion

    // #region DateTimeZoneTest.MapLocal.cs
    // Time zone with an ambiguity
    'ZoneWithAmbiguity_NearStartOfTime': (args) {
      var mapping = ZoneWithAmbiguity.MapLocal(LocalDateTime(-9998, 1, 5, 0, 0));
      CheckMapping(mapping, IntervalBeforeAmbiguity, IntervalBeforeAmbiguity, 1);
    },

    'ZoneWithAmbiguity_NearEndOfTime': (args) {
      var mapping = ZoneWithAmbiguity.MapLocal(NearEndOfTime);
      CheckMapping(mapping, IntervalAfterAmbiguity, IntervalAfterAmbiguity, 1);
    },

    'ZoneWithAmbiguity_WellBeforeTransition': (args) {
      var mapping = ZoneWithAmbiguity.MapLocal(YearBeforeTransition);
      CheckMapping(mapping, IntervalBeforeAmbiguity, IntervalBeforeAmbiguity, 1);
    },

    'ZoneWithAmbiguity_WellAfterTransition': (args) {
      var mapping = ZoneWithAmbiguity.MapLocal(YearAfterTransition);
      CheckMapping(mapping, IntervalAfterAmbiguity, IntervalAfterAmbiguity, 1);
    },

    'ZoneWithAmbiguity_JustBeforeAmbiguity': (args) {
      var mapping = ZoneWithAmbiguity.MapLocal(TransitionMinus5.PlusNanoseconds(-1));
      CheckMapping(mapping, IntervalBeforeAmbiguity, IntervalBeforeAmbiguity, 1);
    },

    'ZoneWithAmbiguity_JustAfterTransition': (args) {
      var mapping = ZoneWithAmbiguity.MapLocal(TransitionPlus10.PlusNanoseconds(1));
      CheckMapping(mapping, IntervalAfterAmbiguity, IntervalAfterAmbiguity, 1);
    },

    'ZoneWithAmbiguity_StartOfTransition': (args) {
      var mapping = ZoneWithAmbiguity.MapLocal(TransitionMinus5);
      CheckMapping(mapping, IntervalBeforeAmbiguity, IntervalAfterAmbiguity, 2);
    },

    'ZoneWithAmbiguity_MidTransition': (args) {
      var mapping = ZoneWithAmbiguity.MapLocal(MidTransition);
      CheckMapping(mapping, IntervalBeforeAmbiguity, IntervalAfterAmbiguity, 2);
    },

    'ZoneWithAmbiguity_LastTickOfTransition': (args) {
      var mapping = ZoneWithAmbiguity.MapLocal(TransitionPlus10.PlusNanoseconds(-1));
      CheckMapping(mapping, IntervalBeforeAmbiguity, IntervalAfterAmbiguity, 2);
    },

    'ZoneWithAmbiguity_FirstTickAfterTransition': (args) {
      var mapping = ZoneWithAmbiguity.MapLocal(TransitionPlus10);
      CheckMapping(mapping, IntervalAfterAmbiguity, IntervalAfterAmbiguity, 1);
    },

    // Time zone with a gap
    'ZoneWithGap_NearStartOfTime': (args) {
      var mapping = ZoneWithGap.MapLocal(NearStartOfTime);
      CheckMapping(mapping, IntervalBeforeGap, IntervalBeforeGap, 1);
    },

    'ZoneWithGap_NearEndOfTime': (args) {
      var mapping = ZoneWithGap.MapLocal(NearEndOfTime);
      CheckMapping(mapping, IntervalAfterGap, IntervalAfterGap, 1);
    },

    'ZoneWithGap_WellBeforeTransition': (args) {
      var mapping = ZoneWithGap.MapLocal(YearBeforeTransition);
      CheckMapping(mapping, IntervalBeforeGap, IntervalBeforeGap, 1);
    },

    'ZoneWithGap_WellAfterTransition': (args) {
      var mapping = ZoneWithGap.MapLocal(YearAfterTransition);
      CheckMapping(mapping, IntervalAfterGap, IntervalAfterGap, 1);
    },

    'ZoneWithGap_JustBeforeGap': (args) {
      var mapping = ZoneWithGap.MapLocal(TransitionMinus5.PlusNanoseconds(-1));
      CheckMapping(mapping, IntervalBeforeGap, IntervalBeforeGap, 1);
    },

    'ZoneWithGap_JustAfterTransition': (args) {
      var mapping = ZoneWithGap.MapLocal(TransitionPlus10.PlusNanoseconds(1));
      CheckMapping(mapping, IntervalAfterGap, IntervalAfterGap, 1);
    },

    'ZoneWithGap_StartOfTransition': (args) {
      var mapping = ZoneWithGap.MapLocal(TransitionMinus5);
      CheckMapping(mapping, IntervalBeforeGap, IntervalAfterGap, 0);
    },

    'ZoneWithGap_MidTransition': (args) {
      var mapping = ZoneWithGap.MapLocal(MidTransition);
      CheckMapping(mapping, IntervalBeforeGap, IntervalAfterGap, 0);
    },

    'ZoneWithGap_LastTickOfTransition': (args) {
      var mapping = ZoneWithGap.MapLocal(TransitionPlus10.PlusNanoseconds(-1));
      CheckMapping(mapping, IntervalBeforeGap, IntervalAfterGap, 0);
    },

    'ZoneWithGap_FirstTickAfterTransition': (args) {
      var mapping = ZoneWithGap.MapLocal(TransitionPlus10);
      CheckMapping(mapping, IntervalAfterGap, IntervalAfterGap, 1);
    },

    /// Case added to cover everything: we want our initial guess to hit the
    /// *later* zone, which doesn't actually include the local instant. However,
    /// we want the *earlier* zone to include it. So, we want a zone with two
    /// positive offsets.
    'TrickyCase': (args) {
      // 1am occurs unambiguously in the early zone.
      var zone = SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(
          Transition, Offset.FromHours(3), Offset.FromHours(5));
      var mapping = zone.MapLocal(LocalDateTime(2000, 1, 1, 1, 0));
      CheckMapping(mapping, zone.EarlyInterval, zone.EarlyInterval, 1);
    },
    // #endregion
  });
}

// #region DateTimeZoneTest.LocalConversions.cs
void AssertImpossible(LocalDateTime localTime, DateTimeZone zone) {
  var mapping = zone.MapLocal(localTime);
  Assert.AreEqual(0, mapping.Count);
  var e = Assert.Throws<SkippedTimeException>(() => mapping.Single());
  Assert.AreEqual(localTime, e.LocalDateTime);
  Assert.AreEqual(zone, e.Zone);
  Assert.Null(e.name);
  StringAssert.Contains(zone.Id, e.message as String);

  e = Assert.Throws<SkippedTimeException>(() => mapping.First());
  Assert.AreEqual(localTime, e.LocalDateTime);
  Assert.AreEqual(zone, e.Zone);

  e = Assert.Throws<SkippedTimeException>(() => mapping.Last());
  Assert.AreEqual(localTime, e.LocalDateTime);
  Assert.AreEqual(zone, e.Zone);
}

void AssertAmbiguous(LocalDateTime localTime, DateTimeZone zone) {
  ZonedDateTime earlier = zone.MapLocal(localTime).First();
  ZonedDateTime later = zone.MapLocal(localTime).Last();
  Assert.AreEqual(localTime, earlier.LocalDateTime);
  Assert.AreEqual(localTime, later.LocalDateTime);
  Assert.That(earlier.ToInstant(), Is.LessThan(later.ToInstant()));

  var mapping = zone.MapLocal(localTime);
  Assert.AreEqual(2, mapping.Count);
  var e = Assert.Throws<AmbiguousTimeException>(() => mapping.Single());
  Assert.AreEqual(localTime, e.LocalDateTime);
  Assert.AreEqual(zone, e.Zone);
  Assert.AreEqual(earlier, e.EarlierMapping);
  Assert.AreEqual(later, e.LaterMapping);
  Assert.Null(e.name);
  StringAssert.Contains(zone.Id, e.message as String);

  Assert.AreEqual(earlier, mapping.First());
  Assert.AreEqual(later, mapping.Last());
}

void AssertOffset(int expectedHours, LocalDateTime localTime, DateTimeZone zone) {
  var mapping = zone.MapLocal(localTime);
  Assert.AreEqual(1, mapping.Count);
  var zoned = mapping.Single();
  Assert.AreEqual(zoned, mapping.First());
  Assert.AreEqual(zoned, mapping.Last());
  int actualHours = zoned.Offset.Milliseconds ~/ NodaConstants.MillisecondsPerHour;
  Assert.AreEqual(expectedHours, actualHours);
}
// #endregion

// #region DateTimeZoneTest.MapLocal.cs
void CheckMapping(ZoneLocalMapping mapping, ZoneInterval earlyInterval, ZoneInterval lateInterval, int count) {
  Assert.AreEqual(earlyInterval, mapping.EarlyInterval);
  Assert.AreEqual(lateInterval, mapping.LateInterval);
  Assert.AreEqual(count, mapping.Count);
}
// #endregion
