// noda_dart: port of the parts of dotnet/runtime's System/TimeZoneInfo.cs that BclDateTimeZone uses (the Windows
// statics are in TimeZoneInfo.Win32.dart).
// Copyright (c) .NET Foundation and Contributors. Licensed under the MIT license (see NOTICE.txt).

import 'package:meta/meta.dart';

import 'DateTime.dart';
import 'InvalidTimeZoneException.dart';
import 'TimeZoneInfo.AdjustmentRule.dart';
import 'TimeZoneInfo.TransitionTime.dart';

const String _UtcId = 'UTC';
const int _MaxOffset = 14 * TimeSpanTicks.PerHour;
const int _MinOffset = -14 * TimeSpanTicks.PerHour;

/// DaylightTime for a year: when daylight saving time starts and ends, as local times, and its delta.
typedef _DaylightTimeStruct = ({DateTime Start, DateTime End, int Delta});

/// .NET's `System.TimeZoneInfo`: names, a base UTC offset and adjustment rules, read from Windows as .NET does.
final class TimeZoneInfo {
  // Dart has no nested types: TimeZoneInfoAdjustmentRule and TimeZoneInfoTransitionTime.

  final String _id;

  /// TimeSpan ticks.
  final int _baseUtcOffset;
  final String? _displayName;
  final String? _standardDisplayName;
  final String? _daylightDisplayName;
  final bool _supportsDaylightSavingTime;
  final List<TimeZoneInfoAdjustmentRule>? _adjustmentRules;
  final bool _hasIanaId;

  /// The zones created for this one's alternative (IANA) IDs (.NET's _equivalentZones, used by TimeZoneInfo.Win32.dart).
  @internal
  List<TimeZoneInfo>? equivalentZones;

  /// .NET's private TimeZoneInfo constructor.
  @internal
  factory TimeZoneInfo.NewIdBaseUtcOffsetDisplayNameStandardDisplayNameDaylightDisplayNameAdjustmentRulesDisableDaylightSavingTimeHasIanaId(
      String id,
      int baseUtcOffset,
      String? displayName,
      String? standardDisplayName,
      String? daylightDisplayName,
      List<TimeZoneInfoAdjustmentRule>? adjustmentRules,
      bool disableDaylightSavingTime,
      [bool hasIanaId = false]) {
    final adjustmentRulesSupportDst = _ValidateTimeZoneInfo(id, baseUtcOffset, adjustmentRules);
    return TimeZoneInfo._(id, baseUtcOffset, displayName, standardDisplayName, daylightDisplayName, adjustmentRules,
        disableDaylightSavingTime, hasIanaId, adjustmentRulesSupportDst);
  }

  TimeZoneInfo._(
      String id,
      int baseUtcOffset,
      String? displayName,
      String? standardDisplayName,
      String? daylightDisplayName,
      List<TimeZoneInfoAdjustmentRule>? adjustmentRules,
      bool disableDaylightSavingTime,
      bool hasIanaId,
      bool adjustmentRulesSupportDst)
      : _id = id,
        _baseUtcOffset = baseUtcOffset,
        _displayName = displayName,
        _standardDisplayName = standardDisplayName,
        _daylightDisplayName = disableDaylightSavingTime ? null : daylightDisplayName,
        _supportsDaylightSavingTime = adjustmentRulesSupportDst && !disableDaylightSavingTime,
        _adjustmentRules = adjustmentRules,
        _hasIanaId = hasIanaId || id.toUpperCase() == _UtcId;

  /// The time zone's identifier: on Windows, the registry key name (e.g. "AUS Eastern Standard Time").
  String get Id => _id;

  /// Whether [Id] is an IANA ID (e.g. a zone found by an IANA ID on Windows).
  bool get HasIanaId => _hasIanaId;

  /// The display name, e.g. "(UTC+10:00) Canberra, Melbourne, Sydney".
  String get DisplayName => _displayName ?? '';

  /// The name of the zone's standard time, e.g. "AUS Eastern Standard Time".
  String get StandardName => _standardDisplayName ?? '';

  /// The name of the zone's daylight saving time, e.g. "AUS Eastern Summer Time".
  String get DaylightName => _daylightDisplayName ?? '';

  /// The base UTC offset, as TimeSpan ticks.
  @internal
  int get BaseUtcOffset => _baseUtcOffset;

  /// Whether the zone has any daylight saving time rules.
  bool get SupportsDaylightSavingTime => _supportsDaylightSavingTime;

  /// Returns a copy of the adjustment rules.
  @internal
  List<TimeZoneInfoAdjustmentRule> GetAdjustmentRules() {
    return _adjustmentRules == null ? <TimeZoneInfoAdjustmentRule>[] : _adjustmentRules.toList();
  }

  /// The rules themselves (for the Windows code, which shares them between zones as .NET does).
  @internal
  List<TimeZoneInfoAdjustmentRule>? get AdjustmentRulesOrNull => _adjustmentRules;

  /// Returns the Universal Coordinated Time (UTC) Offset for a local time (DateTimeKind.Unspecified) in this zone, as
  /// TimeSpan ticks. (Not ported: the Local and Utc kinds, which convert the time first.)
  @internal
  int GetUtcOffset(DateTime dateTime) {
    return _GetUtcOffsetForZone(dateTime, this);
  }

  /// Returns true if a local time (DateTimeKind.Unspecified) in this zone is during daylight saving time. (Not ported:
  /// the Local and Utc kinds.)
  @internal
  bool IsDaylightSavingTime(DateTime dateTime) {
    //
    //    dateTime.Kind is UTC, then time will be converted from UTC
    //        into current instance's timezone
    //    dateTime.Kind is Local, then time will be converted from Local
    //        into current instance's timezone
    //    dateTime.Kind is UnSpecified, then time is already in
    //        current instance's timezone
    //
    // Our DateTime handles ambiguous times, (one is in the daylight and
    // one is in standard.) If a new DateTime is constructed during ambiguous
    // time, it is defaulted to "Standard" (i.e. this will return false).
    // For Invalid times, we will return false

    if (!_supportsDaylightSavingTime || _adjustmentRules == null) {
      return false;
    }

    final adjustedTime = dateTime;

    //
    // handle the normal cases...
    //
    final rule = _GetAdjustmentRuleForTime(adjustedTime);
    if (rule != null && rule.HasDaylightSaving) {
      final daylightTime = _GetDaylightTime(adjustedTime.Year, rule);
      return _GetIsDaylightSavings(adjustedTime, rule, daylightTime);
    } else {
      return false;
    }
  }

  /// Returns the [DisplayName].
  @override
  String toString() => DisplayName;

  /// TimeZoneInfo.CreateCustomTimeZone: without [daylightDisplayName] and [adjustmentRules], a zone with no DST.
  @internal
  static TimeZoneInfo CreateCustomTimeZone(String id, int baseUtcOffset, String? displayName, String? standardDisplayName,
      [String? daylightDisplayName,
      List<TimeZoneInfoAdjustmentRule>? adjustmentRules,
      bool disableDaylightSavingTime = false]) {
    if (daylightDisplayName == null && adjustmentRules == null) {
      // Not ported: hasIanaId from TryConvertIanaIdToWindowsId (it only affects HasIanaId).
      standardDisplayName ??= '';
      return TimeZoneInfo
          .NewIdBaseUtcOffsetDisplayNameStandardDisplayNameDaylightDisplayNameAdjustmentRulesDisableDaylightSavingTimeHasIanaId(
              id, baseUtcOffset, displayName ?? '', standardDisplayName, standardDisplayName, null, false);
    }
    // Not ported: the copy of the rules (they're immutable here).
    return TimeZoneInfo
        .NewIdBaseUtcOffsetDisplayNameStandardDisplayNameDaylightDisplayNameAdjustmentRulesDisableDaylightSavingTimeHasIanaId(
            id,
            baseUtcOffset,
            displayName ?? '',
            standardDisplayName ?? '',
            daylightDisplayName ?? '',
            adjustmentRules != null && adjustmentRules.isNotEmpty ? adjustmentRules.toList() : null,
            disableDaylightSavingTime);
  }

  TimeZoneInfoAdjustmentRule? _GetAdjustmentRuleForTime(DateTime dateTime) {
    final adjustmentRules = _adjustmentRules;
    if (adjustmentRules == null || adjustmentRules.isEmpty) {
      return null;
    }

    // Only check the whole-date portion of the dateTime for DateTimeKind.Unspecified rules -
    // This is because the AdjustmentRule DateStart & DateEnd are stored as
    // Date-only values {4/2/2006 - 10/28/2006} but actually represent the
    // time span {4/2/2006@00:00:00.00000 - 10/28/2006@23:59:59.99999}
    final date = dateTime.Date;

    var low = 0;
    var high = adjustmentRules.length - 1;

    while (low <= high) {
      final median = low + ((high - low) >> 1);

      final rule = adjustmentRules[median];

      final compareResult = _CompareAdjustmentRuleToDateTime(rule, date);
      if (compareResult == 0) {
        return rule;
      } else if (compareResult < 0) {
        low = median + 1;
      } else {
        high = median - 1;
      }
    }

    return null;
  }

  /// Determines if 'rule' is the correct AdjustmentRule for the given dateTime.
  ///
  /// Returns a value less than zero if rule is for times before dateTime. Zero if rule is correct for dateTime. A value
  /// greater than zero if rule is for times after dateTime.
  static int _CompareAdjustmentRuleToDateTime(TimeZoneInfoAdjustmentRule rule, DateTime dateOnly) {
    // if the rule's DateStart is Unspecified, then use the whole-date portion
    final isAfterStart = dateOnly.CompareTo(rule.DateStart) >= 0;

    if (!isAfterStart) {
      return 1;
    }

    // if the rule's DateEnd is Unspecified, then use the whole-date portion
    final isBeforeEnd = dateOnly.CompareTo(rule.DateEnd) <= 0;

    return isBeforeEnd ? 0 : -1;
  }

  /// Helper function that returns a DaylightTime from a year and AdjustmentRule.
  _DaylightTimeStruct _GetDaylightTime(int year, TimeZoneInfoAdjustmentRule rule) {
    final delta = rule.DaylightDelta;
    // Not ported: NoDaylightTransitions rules (Unix only).
    final startTime = TransitionTimeToDateTime(year, rule.DaylightTransitionStart);
    final endTime = TransitionTimeToDateTime(year, rule.DaylightTransitionEnd);
    return (Start: startTime, End: endTime, Delta: delta);
  }

  /// Helper function that checks if a given dateTime is in Daylight Saving Time (DST).
  /// This function assumes the dateTime and AdjustmentRule are both in the same time zone.
  static bool _GetIsDaylightSavings(
      DateTime time, TimeZoneInfoAdjustmentRule? rule, _DaylightTimeStruct daylightTime) {
    if (rule == null) {
      return false;
    }

    // Not ported: DateTimeKind.Local.

    // startTime and endTime represent the period from either the start of DST to the end and
    // ***does not include*** the potentially overlapped times
    //
    //         -=-=-=-=-=- Pacific Standard Time -=-=-=-=-=-=-
    //    April 2, 2006                            October 29, 2006
    // 2AM            3AM                        1AM              2AM
    // |      +1 hr     |                        |       -1 hr      |
    // | <invalid time> |                        | <ambiguous time> |
    //                  [========== DST ========>)
    //
    //        -=-=-=-=-=- Some Weird Time Zone -=-=-=-=-=-=-
    //    April 2, 2006                          October 29, 2006
    // 1AM              2AM                    2AM              3AM
    // |      -1 hr       |                      |       +1 hr      |
    // | <ambiguous time> |                      |  <invalid time>  |
    //                    [======== DST ========>)
    //
    final invalidAtStart = rule.DaylightDelta > 0;

    final startTime = rule.IsStartDateMarkerForBeginningOfYear()
        ? DateTime.Create(daylightTime.Start.Year, 1, 1)
        : daylightTime.Start.AddTicks(invalidAtStart ? rule.DaylightDelta : 0); /* FUTURE: - rule.StandardDelta; */

    final endTime = rule.IsEndDateMarkerForEndOfYear()
        ? DateTime.Create(daylightTime.End.Year + 1, 1, 1).AddTicks(-1)
        : daylightTime.End.AddTicks(invalidAtStart ? -rule.DaylightDelta : 0);

    return _CheckIsDst(startTime, time, endTime, false, rule);
  }

  static bool _CheckIsDst(
      DateTime startTime, DateTime time, DateTime endTime, bool ignoreYearAdjustment, TimeZoneInfoAdjustmentRule rule) {
    // NoDaylightTransitions AdjustmentRules should never get their year adjusted since they adjust the offset for the
    // entire time period - which may be for multiple years
    if (!ignoreYearAdjustment && !rule.NoDaylightTransitions) {
      final startTimeYear = startTime.Year;
      final endTimeYear = endTime.Year;

      if (startTimeYear != endTimeYear) {
        endTime = endTime.AddYears(startTimeYear - endTimeYear);
      }

      final timeYear = time.Year;

      if (startTimeYear != timeYear) {
        time = time.AddYears(startTimeYear - timeYear);
      }
    }

    if (startTime.CompareTo(endTime) > 0) {
      // In southern hemisphere, the daylight saving time starts later in the year, and ends in the beginning of next year.
      // Note, the summer in the southern hemisphere begins late in the year.
      return time.CompareTo(endTime) < 0 || time.CompareTo(startTime) >= 0;
    } else {
      // Not ported: NoDaylightTransitions (inclusive end).
      // In northern hemisphere, the daylight saving time starts in the middle of the year.
      return time.CompareTo(startTime) >= 0 && time.CompareTo(endTime) < 0;
    }
  }

  /// Helper function that calculates the UTC offset for a dateTime in a timeZone.
  /// This function assumes that the dateTime is already converted into the timeZone.
  static int _GetUtcOffsetForZone(DateTime time, TimeZoneInfo zone) {
    var baseOffset = zone.BaseUtcOffset;
    final rule = zone._GetAdjustmentRuleForTime(time);

    if (rule != null) {
      baseOffset += rule.BaseUtcOffsetDelta;
      if (rule.HasDaylightSaving) {
        final daylightTime = zone._GetDaylightTime(time.Year, rule);
        final isDaylightSavings = _GetIsDaylightSavings(time, rule, daylightTime);
        baseOffset += isDaylightSavings ? rule.DaylightDelta : 0; /* FUTURE: rule.StandardDelta */
      }
    }

    return baseOffset;
  }

  /// Helper function that converts a year and TransitionTime into a DateTime.
  @internal
  static DateTime TransitionTimeToDateTime(int year, TimeZoneInfoTransitionTime transitionTime) {
    DateTime value;
    final timeOfDay = transitionTime.TimeOfDay.TimeOfDay;

    if (transitionTime.IsFixedDateRule) {
      // create a DateTime from the passed in year and the properties on the transitionTime

      var day = transitionTime.Day;
      // if the day is out of range for the month then use the last day of the month
      if (day > 28) {
        final daysInMonth = DateTime.DaysInMonth(year, transitionTime.Month);
        if (day > daysInMonth) {
          day = daysInMonth;
        }
      }

      value = DateTime.Create(year, transitionTime.Month, day).AddTicks(timeOfDay);
    } else {
      if (transitionTime.Week <= 4) {
        //
        // Get the (transitionTime.Week)th Sunday.
        //
        value = DateTime.Create(year, transitionTime.Month, 1).AddTicks(timeOfDay);

        final dayOfWeek = value.DayOfWeek;
        var delta = transitionTime.DayOfWeek - dayOfWeek;
        if (delta < 0) {
          delta += 7;
        }
        delta += 7 * (transitionTime.Week - 1);

        if (delta > 0) {
          value = value.AddDays(delta);
        }
      } else {
        //
        // If TransitionWeek is greater than 4, we will get the last week.
        //
        final daysInMonth = DateTime.DaysInMonth(year, transitionTime.Month);
        value = DateTime.Create(year, transitionTime.Month, daysInMonth).AddTicks(timeOfDay);

        // This is the day of week for the last day of the month.
        final dayOfWeek = value.DayOfWeek;
        var delta = dayOfWeek - transitionTime.DayOfWeek;
        if (delta < 0) {
          delta += 7;
        }

        if (delta > 0) {
          value = value.AddDays(-delta);
        }
      }
    }
    return value;
  }

  /// Helper function that performs all of the validation checks for the factory methods and deserialization callback.
  ///
  /// Returns adjustmentRulesSupportDst.
  static bool _ValidateTimeZoneInfo(String id, int baseUtcOffset, List<TimeZoneInfoAdjustmentRule>? adjustmentRules) {
    if (id.isEmpty) {
      throw ArgumentError('The value cannot be an empty string.', 'id');
    }

    if (_UtcOffsetOutOfRange(baseUtcOffset)) {
      throw RangeError.value(
          baseUtcOffset, 'baseUtcOffset', 'The TimeSpan parameter must be within plus or minus 14.0 hours.');
    }

    if (baseUtcOffset.remainder(TimeSpanTicks.PerMinute) != 0) {
      throw ArgumentError(
          'The TimeSpan parameter cannot be specified more precisely than whole minutes.', 'baseUtcOffset');
    }

    var adjustmentRulesSupportDst = false;

    //
    // "adjustmentRules" can either be null or a valid array of AdjustmentRule objects.
    // A valid array is one that does not contain any null elements and all elements
    // are sorted in chronological order
    //

    if (adjustmentRules != null && adjustmentRules.isNotEmpty) {
      adjustmentRulesSupportDst = true;
      TimeZoneInfoAdjustmentRule? current;
      for (var i = 0; i < adjustmentRules.length; i++) {
        final prev = current;
        current = adjustmentRules[i];

        if (!_IsValidAdjustmentRuleOffset(baseUtcOffset, current)) {
          throw InvalidTimeZoneException(
              'The sum of the BaseUtcOffset and DaylightDelta properties must within plus or minus 14.0 hours.');
        }

        if (prev != null && current.DateStart.CompareTo(prev.DateEnd) <= 0) {
          // verify the rules are in chronological order and the DateStart/DateEnd do not overlap
          throw InvalidTimeZoneException(
              'The elements of the AdjustmentRule array must be in chronological order and must not overlap.');
        }
      }
    }
    return adjustmentRulesSupportDst;
  }

  /// Helper function that validates the TimeSpan is within +/- 14.0 hours
  static bool _UtcOffsetOutOfRange(int offset) {
    return offset < _MinOffset || offset > _MaxOffset;
  }

  static int _GetUtcOffsetForRule(int baseUtcOffset, TimeZoneInfoAdjustmentRule adjustmentRule) {
    return baseUtcOffset +
        adjustmentRule.BaseUtcOffsetDelta +
        (adjustmentRule.HasDaylightSaving ? adjustmentRule.DaylightDelta : 0);
  }

  /// Helper function that performs adjustment rule validation
  static bool _IsValidAdjustmentRuleOffset(int baseUtcOffset, TimeZoneInfoAdjustmentRule adjustmentRule) {
    final utcOffset = _GetUtcOffsetForRule(baseUtcOffset, adjustmentRule);
    return !_UtcOffsetOutOfRange(utcOffset);
  }
}
