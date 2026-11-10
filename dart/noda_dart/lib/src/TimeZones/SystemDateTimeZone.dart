// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/BclDateTimeZone.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: BclDateTimeZone, renamed as in noda-js. Without Windows' data, zones come from TZif files (FromTzif)
// or Intl (FromIntl).

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../DateTimeZone.dart';
import '../Instant.dart';
import '../LocalDate.dart';
import '../LocalDateTime.dart';
import '../LocalTime.dart';
import '../Offset.dart';
import '../System/DateTime.dart';
import '../System/IHostSystemTimeZones.dart';
import '../System/IntlTimeZone.dart';
import '../System/TimeZoneInfo.AdjustmentRule.dart';
import '../System/TimeZoneInfo.TransitionTime.dart';
import '../System/TimeZoneInfo.dart';
import '../System/TzifTimeZone.dart';
import '../Utility/BclConversions.dart';
import '../Utility/Int64.dart';
import '../Utility/TimeZoneEnvironment.dart';
import 'CachingZoneIntervalMap.dart';
import 'DateTimeZoneNotFoundException.dart';
import 'IZoneIntervalMap.dart';
import 'PartialZoneIntervalMap.dart';
import 'SingleZoneIntervalMap.dart';
import 'StandardDaylightAlternatingMap.dart';
import 'TimeZoneInfoInterceptor.dart';
import 'TransitionMode.generated.dart';
import 'ZoneInterval.dart';
import 'ZoneRecurrence.dart';
import 'ZoneYearOffset.dart';

// #region BCL conversions (NodaTime's extension methods)

/// TimeSpan.ToOffset(): a TimeSpan (ticks) as an Offset.
Offset _ToOffset(int timeSpanTicks) {
  return Offset.FromTicks(timeSpanTicks);
}

/// DateTime.ToLocalDateTime() / LocalDateTime.FromDateTime.
LocalDateTime _ToLocalDateTime(DateTime dateTime) {
  return LocalDate(dateTime.Year, dateTime.Month, dateTime.Day).At(LocalTime.FromTicksSinceMidnight(dateTime.TickOfDay));
}

// #endregion

/// This is used to cache the last result of a call to [SystemDateTimeZone.ForSystemDefault], but it doesn't
/// matter if it's out of date - we'll just create another wrapper if necessary. It's not *that* expensive to make
/// a few more wrappers than we need.
SystemDateTimeZone? _systemDefault;

/// Representation of a time zone converted from a [TimeZoneInfo] from the Base Class Library.
///
/// noda_dart: or from TZif files or Intl (no [OriginalZone]; see docs/Timezones.md for their limits).
///
/// Two instances of this class are deemed equal if and only if they refer to the exact same
/// [TimeZoneInfo] object.
///
/// This implementation does not always give the same results as `TimeZoneInfo`, in that it doesn't replicate
/// the bugs in the BCL interpretation of the data. These bugs are described in
/// [a blog post](https://codeblog.jonskeet.uk/2014/09/30/the-mysteries-of-bcl-time-zone-data/), but we're
/// not expecting them to be fixed any time soon. Being bug-for-bug compatible would not only be tricky, but would be painful
/// if the BCL were ever to be fixed. As far as we are aware, there are only discrepancies around new year where the zone
/// changes from observing one rule to observing another.
///
/// As of version 3.0, a new "incompatible but doing the right thing" category of differences has been implemented,
/// for time zones which have a transition at 24:00. The Windows time zone data represents this as a transition at 23:59:59.999,
/// and that's faithfully represented by TimeZoneInfo (and BclDateTimeZone in version 2.x). As of 3.0, this is spotted
/// and converted to a midnight-on-the-following-day transition.
///
/// This type is immutable reference type. See the thread safety section of the user guide for more information.
final class SystemDateTimeZone extends DateTimeZone {
  final IZoneIntervalMap _map;
  final TimeZoneInfo? _originalZone;
  final String? _displayName;

  /// Gets the original [TimeZoneInfo] from which this was created.
  ///
  /// noda_dart: null for a zone from the TZif files or Intl.
  TimeZoneInfo? get OriginalZone => _originalZone;

  /// Gets the display name associated with the time zone, as provided by the Base Class Library.
  ///
  /// noda_dart: for Intl, the host's English generic name (or the ID); for TZif, the ID.
  String get DisplayName => _originalZone != null ? _originalZone.DisplayName : (_displayName ?? Id);

  SystemDateTimeZone._(String id, bool isFixed, TimeZoneInfo? originalZone, String? displayName, IZoneIntervalMap map)
      : _originalZone = originalZone,
        _displayName = displayName,
        _map = map,
        super(id, isFixed, map.MinOffset, map.MaxOffset);

  /// Gets the zone interval for the given instant.
  @override
  ZoneInterval GetZoneInterval(Instant instant) {
    return _map.GetZoneInterval(instant);
  }

  /// Creates a new [SystemDateTimeZone] from a [TimeZoneInfo].
  ///
  /// [bclZone]: The original time zone to take information from.
  ///
  /// Returns a [SystemDateTimeZone] wrapping the given `TimeZoneInfo`.
  static SystemDateTimeZone FromTimeZoneInfo(TimeZoneInfo bclZone) {
    // Dart: null safety checks bclZone.
    final standardOffset = _ToOffset(bclZone.BaseUtcOffset);
    final rules = bclZone.GetAdjustmentRules();
    if (!bclZone.SupportsDaylightSavingTime || rules.isEmpty) {
      final fixedInterval = ZoneInterval.NewNameStartEndWallOffsetSavings(
          bclZone.StandardName, Instant.BeforeMinValue, Instant.AfterMaxValue, standardOffset, Offset.Zero);
      // (BclDateTimeZone's constructor passes SupportsDaylightSavingTime as DateTimeZone's isFixed.)
      return SystemDateTimeZone._(bclZone.Id, bclZone.SupportsDaylightSavingTime, bclZone, null,
          SingleZoneIntervalMap.NewInterval(fixedInterval));
    }

    // noda_dart: AreWindowsStyleRules is always true (Windows' data), so the Unix rule conversion isn't ported.
    final convertedRules =
        rules.map((rule) => SystemDateTimeZoneBclAdjustmentRule.FromWindowsAdjustmentRule(bclZone, rule)).toList();

    final uncachedMap = BuildMap(convertedRules, standardOffset, bclZone.StandardName);
    final cachedMap = CachingZoneIntervalMap.CacheMap(uncachedMap);

    return SystemDateTimeZone._(bclZone.Id, bclZone.SupportsDaylightSavingTime, bclZone, null, cachedMap);
  }

  /// noda_dart: a zone from the host's Intl zone [ianaId], with the given ID.
  ///
  /// Throws (a JavaScript RangeError) if the host doesn't support the IANA ID.
  @internal
  static SystemDateTimeZone FromIntl(String id, String ianaId) {
    final map = CachingZoneIntervalMap.CacheMap(CreateIntlZoneIntervalMap(ianaId));
    return SystemDateTimeZone._(id, false, null, GetIntlGenericName(ianaId), map);
  }

  /// noda_dart: a zone from the TZif data of an operating system's zone file.
  ///
  /// Throws a [FormatException] if the data is malformed.
  @internal
  static SystemDateTimeZone FromTzif(String id, Uint8List bytes) {
    final map = CreateTzifZoneIntervalMap(id, bytes);
    return SystemDateTimeZone._(id, map is SingleZoneIntervalMap, null, null, CachingZoneIntervalMap.CacheMap(map));
  }

  /// noda_dart: UTC ("Etc/UTC"), where the operating system has no zone file for it.
  @internal
  static SystemDateTimeZone FromTzifUtc(String id) {
    final interval =
        ZoneInterval.NewNameStartEndWallOffsetSavings('UTC', Instant.BeforeMinValue, Instant.AfterMaxValue, Offset.Zero, Offset.Zero);
    return SystemDateTimeZone._(id, true, null, null, SingleZoneIntervalMap.NewInterval(interval));
  }

  // Not ported: AreWindowsStyleRules, FixUnixTransitions (.NET on Unix).

  @internal
  static IZoneIntervalMap BuildMap(List<SystemDateTimeZoneBclAdjustmentRule> rules, Offset standardOffset, String standardName) {
    // Dart: null safety checks standardName.

    // First work out a naive list of partial maps. These will give the right offset at every instant, but not necessarily
    // correct intervals - we may we need to stitch intervals together.
    final maps = <PartialZoneIntervalMap>[];
    // Handle the start of time until the start of the first rule, if necessary.
    if (rules[0].Start.IsValid) {
      maps.add(PartialZoneIntervalMap.ForZoneInterval(standardName, Instant.BeforeMinValue, rules[0].Start, standardOffset, Offset.Zero));
    }
    for (var i = 0; i < rules.length - 1; i++) {
      final beforeRule = rules[i];
      final afterRule = rules[i + 1];
      maps.add(beforeRule.PartialMap);
      // If there's a gap between this rule and the next one, fill it with a fixed interval.
      if (beforeRule.End < afterRule.Start) {
        maps.add(PartialZoneIntervalMap.ForZoneInterval(standardName, beforeRule.End, afterRule.Start, standardOffset, Offset.Zero));
      }
    }

    final lastRule = rules[rules.length - 1];
    maps.add(lastRule.PartialMap);

    // Handle the end of the last rule until the end of time, if necessary.
    if (lastRule.End.IsValid) {
      maps.add(PartialZoneIntervalMap.ForZoneInterval(standardName, lastRule.End, Instant.AfterMaxValue, standardOffset, Offset.Zero));
    }
    return PartialZoneIntervalMap.ConvertToFullMap(maps);
  }

  /// Returns a time zone converted from the BCL representation of the system local time zone.
  ///
  /// This method is approximately equivalent to calling [IDateTimeZoneProvider.GetSystemDefault] with
  /// an implementation that wraps [SystemDateTimeZoneSource] (e.g.
  /// `SystemDateTimeZoneProvider`), with the exception that it will succeed even if the current local
  /// time zone was not one of the set of system time zones captured when the source was created (which, while
  /// highly unlikely, might occur either because the local time zone is not a system time zone, or because the
  /// system time zones have themselves changed).
  ///
  /// This method will retain a reference to the returned `SystemDateTimeZone`, and will attempt to return it if
  /// called repeatedly (assuming that the local time zone has not changed) rather than creating a new instance,
  /// though this behaviour is not guaranteed.
  ///
  /// noda_dart: the zone TZ names if set (as [SystemDateTimeZoneSource.GetSystemDefaultId] resolves it), else the
  /// host's (TimeZoneInfo.Local on Windows, /etc/localtime or Android's setting, or Intl's on the web).
  ///
  /// Throws [StateError] (InvalidOperationException) if the system does not provide a time zone, and
  /// [DateTimeZoneNotFoundException] if the TZ environment variable is set, but there's no zone for it (not even UTC).
  ///
  /// Returns a [SystemDateTimeZone] wrapping the "local" (system) time zone as returned by TimeZoneInfo.Local.
  static SystemDateTimeZone ForSystemDefault() {
    final shim = TimeZoneInfoInterceptor.Shim;
    if (shim == null) {
      final tz = GetTZEnvironmentVariable();
      // noda_dart: no TimeZoneInfo on this host: the TZif or Intl default zone (or TZ's).
      final hostDefault = HostSystemTimeZonesForHost().ForSystemDefault();
      if (hostDefault == null) {
        throw tz != null
            ? DateTimeZoneNotFoundException("The TZ environment variable ($tz) doesn't name a system time zone")
            : StateError('No system default time zone is available');
      }
      return hostDefault;
    }
    // noda_dart: TimeZoneInfo.Local honours TZ (System/LocalTimeZoneFromTZ.dart).
    final local = TimeZoneInfoInterceptor.Local;
    if (local == null) {
      throw StateError('No system default time zone is available');
    }
    var currentSystemDefault = _systemDefault;

    // Cached copy is out of date - wrap a new one.
    // If currentSystemDefault is null, we always enter this block (as local isn't null).
    if (!identical(currentSystemDefault?.OriginalZone, local)) {
      currentSystemDefault = FromTimeZoneInfo(local);
      _systemDefault = currentSystemDefault;
    }
    // Always return our local variable; the field may have changed again.
    return currentSystemDefault!;
  }

  /// Clears the cache of [ForSystemDefault] (for tests).
  @internal
  static void ResetSystemDefaultCache() {
    _systemDefault = null;
  }
}

/// Just a mapping of a TimeZoneInfo.AdjustmentRule into Noda Time types. Very little cleverness here.
/// (BclDateTimeZone.BclAdjustmentRule: Dart has no nested types.)
@internal
final class SystemDateTimeZoneBclAdjustmentRule {
  static final DateTime _MaxDate = DateTime.MaxValue.Date;

  /// Instant on which this rule starts.
  Instant get Start => PartialMap.Start;

  /// Instant on which this rule ends.
  Instant get End => PartialMap.End;

  /// Daylight savings, when applicable within this rule.
  final Offset Savings;

  /// The standard offset for the duration of this rule.
  final Offset StandardOffset;

  final PartialZoneIntervalMap PartialMap;

  // Visible for tests
  SystemDateTimeZoneBclAdjustmentRule.NewZoneInterval(ZoneInterval zoneInterval)
      : StandardOffset = zoneInterval.StandardOffset,
        Savings = zoneInterval.Savings,
        PartialMap = PartialZoneIntervalMap.ForZoneIntervalZoneInterval(zoneInterval);

  SystemDateTimeZoneBclAdjustmentRule._NewStandardOffsetSavingsPartialMap(
      this.StandardOffset, this.Savings, this.PartialMap);

  SystemDateTimeZoneBclAdjustmentRule WithStart(Instant newStart) =>
      SystemDateTimeZoneBclAdjustmentRule._NewStandardOffsetSavingsPartialMap(StandardOffset, Savings, PartialMap.WithStart(newStart));

  SystemDateTimeZoneBclAdjustmentRule WithEnd(Instant newEnd) =>
      SystemDateTimeZoneBclAdjustmentRule._NewStandardOffsetSavingsPartialMap(StandardOffset, Savings, PartialMap.WithEnd(newEnd));

  // Not ported: FromUnixAdjustmentRule and ConvertUnixRuleToBclAdjustmentRule (.NET on Unix; see FromTzif).

  static SystemDateTimeZoneBclAdjustmentRule FromWindowsAdjustmentRule(TimeZoneInfo zone, TimeZoneInfoAdjustmentRule rule) {
    // With .NET 4.6, adjustment rules can have their own standard offsets, allowing
    // a much more reasonable set of time zone data. Unfortunately, this isn't directly
    // exposed, but we can detect it by just finding the UTC offset for an arbitrary
    // time within the rule - the start, in this case - and then take account of the
    // possibility of that being in daylight saving time. Fortunately, we only need
    // to do this during the setup.
    var ruleStandardOffset = zone.GetUtcOffset(rule.DateStart);
    if (zone.IsDaylightSavingTime(rule.DateStart)) {
      ruleStandardOffset -= rule.DaylightDelta;
    }
    final standardOffset = _ToOffset(ruleStandardOffset);

    // Although the rule may have its own standard offset, the start/end is still determined
    // using the zone's standard offset.
    final zoneStandardOffset = _ToOffset(zone.BaseUtcOffset);

    // Note: this extends back from DateTime.MinValue to start of time, even though the BCL can represent
    // as far back as 1AD. This is in the *spirit* of a rule which goes back that far.
    final start = rule.DateStart.Equals(DateTime.MinValue)
        ? Instant.BeforeMinValue
        : _ToLocalDateTime(rule.DateStart).WithOffset(zoneStandardOffset).ToInstant();
    // The end instant (exclusive) is the end of the given date, so we need to add a day.
    final end = rule.DateEnd.Equals(_MaxDate)
        ? Instant.AfterMaxValue
        : _ToLocalDateTime(rule.DateEnd).PlusDays(1).WithOffset(zoneStandardOffset).ToInstant();
    final savings = _ToOffset(rule.DaylightDelta);

    PartialZoneIntervalMap partialMap;
    // Some rules have DST start/end of "January 1st", to indicate that they're just in standard time. This is important
    // for rules which have a standard offset which is different to the standard offset of the zone itself.
    if (_IsStandardOffsetOnlyRule(rule)) {
      partialMap = PartialZoneIntervalMap.ForZoneInterval(zone.StandardName, start, end, standardOffset, Offset.Zero);
    } else {
      final daylightRecurrence = ZoneRecurrence(
          zone.DaylightName, savings, _ConvertTransition(rule.DaylightTransitionStart), Int64.Int32MinValue, Int64.Int32MaxValue);
      final standardRecurrence = ZoneRecurrence(
          zone.StandardName, Offset.Zero, _ConvertTransition(rule.DaylightTransitionEnd), Int64.Int32MinValue, Int64.Int32MaxValue);
      IZoneIntervalMap recurringMap = StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(
          standardOffset, standardRecurrence, daylightRecurrence);
      // Fake 1 hour savings if the adjustment rule claims to be 0 savings. See DaylightFakingZoneIntervalMap documentation below for more details.
      if (savings == Offset.Zero) {
        recurringMap = _SystemDateTimeZoneBclAdjustmentRuleDaylightFakingZoneIntervalMap(recurringMap, zone.DaylightName);
      }
      partialMap = PartialZoneIntervalMap.NewStartEndMap(start, end, recurringMap);
    }
    return SystemDateTimeZoneBclAdjustmentRule._NewStandardOffsetSavingsPartialMap(standardOffset, savings, partialMap);
  }

  /// The BCL represents "standard-only" rules using two fixed date January 1st transitions.
  /// Currently the time-of-day used for the DST end transition is at one millisecond past midnight... we'll
  /// be slightly more lenient, accepting anything up to 12:01...
  static bool _IsStandardOffsetOnlyRule(TimeZoneInfoAdjustmentRule rule) {
    final daylight = rule.DaylightTransitionStart;
    final standard = rule.DaylightTransitionEnd;
    return daylight.IsFixedDateRule &&
        daylight.Day == 1 &&
        daylight.Month == 1 &&
        daylight.TimeOfDay.TimeOfDay < TimeSpanTicks.PerMinute &&
        standard.IsFixedDateRule &&
        standard.Day == 1 &&
        standard.Month == 1 &&
        standard.TimeOfDay.TimeOfDay < TimeSpanTicks.PerMinute;
  }

  static final LocalTime _OneMillisecondBeforeMidnight = LocalTime(23, 59, 59, 999);

  // Converts a TimeZoneInfo "TransitionTime" to a "ZoneYearOffset" - the two correspond pretty closely.
  static ZoneYearOffset _ConvertTransition(TimeZoneInfoTransitionTime transitionTime) {
    // Used for both fixed and non-fixed transitions.
    var timeOfDay = _ToLocalDateTime(transitionTime.TimeOfDay).TimeOfDay;

    // Transitions at midnight are represented in the Windows database by a transition one millisecond early.
    // See BclDateTimeZoneTest.TransitionAtMidnight for a concrete example.
    // We adjust to midnight to represent the correct data - it's clear this is just a data fudge.
    // It's probably done like this to allow the rule to represent "Saturday 24:00" instead of "Sunday 00:00".
    var addDay = false;
    if (timeOfDay == _OneMillisecondBeforeMidnight) {
      timeOfDay = LocalTime.Midnight;
      addDay = true;
    }

    // Easy case - fixed day of the month.
    if (transitionTime.IsFixedDateRule) {
      return ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(
          TransitionMode.Wall, transitionTime.Month, transitionTime.Day, 0, false, timeOfDay, addDay);
    }

    // Floating: 1st Sunday in March etc.
    final dayOfWeek = BclConversions.ToIsoDayOfWeek(transitionTime.DayOfWeek).value;
    int dayOfMonth;
    bool advance;
    // "Last"
    if (transitionTime.Week == 5) {
      advance = false;
      dayOfMonth = -1;
    } else {
      advance = true;
      // Week 1 corresponds to ">=1"
      // Week 2 corresponds to ">=8" etc
      dayOfMonth = (transitionTime.Week * 7) - 6;
    }
    return ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(
        TransitionMode.Wall, transitionTime.Month, dayOfMonth, dayOfWeek, advance, timeOfDay, addDay);
  }
}

/// An implementation of IZoneIntervalMap that delegates to an original map, except for where the result of a
/// ZoneInterval lookup has the given daylight name. In that case, a new ZoneInterval is built with the same
/// wall offset (and start/end instants etc), but with a savings of 1 hour. This is only used to work around TimeZoneInfo
/// adjustment rules with a daylight saving of 0 which are really trying to fake a more comprehensive solution.
/// (This is currently only seen on Mono on Linux...)
/// This addresses https://github.com/nodatime/nodatime/issues/746.
/// If TimeZoneInfo had sufficient flexibility to use different names for different periods of time, we'd have
/// another problem, as some "daylight names" don't always mean daylight - e.g. "BST" = British Summer Time and British Standard Time.
/// In this case, the limited nature of TimeZoneInfo works in our favour.
final class _SystemDateTimeZoneBclAdjustmentRuleDaylightFakingZoneIntervalMap implements IZoneIntervalMap {
  final IZoneIntervalMap _originalMap;
  final String _daylightName;

  @override
  Offset get MinOffset => _originalMap.MinOffset;
  @override
  Offset get MaxOffset => _originalMap.MaxOffset;

  _SystemDateTimeZoneBclAdjustmentRuleDaylightFakingZoneIntervalMap(this._originalMap, this._daylightName);

  @override
  ZoneInterval GetZoneInterval(Instant instant) {
    final interval = _originalMap.GetZoneInterval(instant);
    return interval.Name == _daylightName
        ? ZoneInterval.NewNameStartEndWallOffsetSavings(
            _daylightName, interval.RawStart, interval.RawEnd, interval.WallOffset, Offset.FromHours(1))
        : interval;
  }
}
