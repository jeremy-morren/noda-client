// noda_dart: port of dotnet/runtime's System/TimeZoneInfo.Win32.cs and TimeZoneInfo.cs's static members (Local, Utc,
// FindSystemTimeZoneById, GetSystemTimeZones), reading the registry through an IWindowsTimeZoneApi.
// Copyright (c) .NET Foundation and Contributors. Licensed under the MIT license (see NOTICE.txt).
//
// CachedData is an instance per API (so tests can use fakes). Not ported: invariant mode, GlobalizationMode,
// DateTime.Now's one-year local zone, serialization.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'DateTime.dart';
import 'InvalidTimeZoneException.dart';
import 'LocalTimeZoneFromTZ.dart';
import 'TimeZoneInfo.AdjustmentRule.dart';
import 'TimeZoneInfo.TransitionTime.dart';
import 'TimeZoneInfo.dart';
import 'TimeZoneNotFoundException.dart';
import 'Windows/IWindowsTimeZoneApi.dart';
import 'WindowsIdMapping.dart';

// registry constants for the 'Time Zones' hive
//
const String _TimeZonesRegistryHive = r'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones';
const String _DisplayValue = 'Display';
const String _DaylightValue = 'Dlt';
const String _StandardValue = 'Std';
const String _MuiDisplayValue = 'MUI_Display';
const String _MuiDaylightValue = 'MUI_Dlt';
const String _MuiStandardValue = 'MUI_Std';
const String _TimeZoneInfoValue = 'TZI';
const String _FirstEntryValue = 'FirstEntry';
const String _LastEntryValue = 'LastEntry';

const String _InvariantUtcStandardDisplayName = 'Coordinated Universal Time';

const String _UtcId = 'UTC';
const String _LocalId = 'Local';
const int _MaxKeyLength = 255;

/// sizeof(REG_TZI_FORMAT).
const int _RegTziFormatSize = 44;

/// Interop.Kernel32.REG_TZI_FORMAT: the "TZI" registry values.
class _RegTziFormat {
  final int Bias;
  final int StandardBias;
  final int DaylightBias;
  final WindowsSystemTime StandardDate;
  final WindowsSystemTime DaylightDate;

  _RegTziFormat(this.Bias, this.StandardBias, this.DaylightBias, this.StandardDate, this.DaylightDate);
}

/// Interop.Kernel32.TIME_ZONE_INFORMATION (the parts of DYNAMIC_TIME_ZONE_INFORMATION it copies).
final class _TimeZoneInformation extends _RegTziFormat {
  final String StandardName;
  final String DaylightName;

  _TimeZoneInformation(super.Bias, super.StandardBias, super.DaylightBias, super.StandardDate, super.DaylightDate,
      this.StandardName, this.DaylightName);
}

/// TimeZoneInfoResult (not ported: SecurityException).
enum _TimeZoneInfoResult {
  Success,
  TimeZoneNotFoundException,
  InvalidTimeZoneException,
}

/// What the Try* methods give: .NET's result, the out value, and the out exception.
typedef _TimeZoneInfoTryResult = ({_TimeZoneInfoResult Result, TimeZoneInfo? Value, Object? Error});

/// .NET's InvalidCastException, thrown where the C# cast of a registry value would throw it.
final class _InvalidCastException implements Exception {
  final String message;

  _InvalidCastException(this.message);

  @override
  String toString() => 'InvalidCastException: $message';
}

bool _SystemTimeEquals(WindowsSystemTime a, WindowsSystemTime b) {
  return a.Year == b.Year &&
      a.Month == b.Month &&
      a.DayOfWeek == b.DayOfWeek &&
      a.Day == b.Day &&
      a.Hour == b.Hour &&
      a.Minute == b.Minute &&
      a.Second == b.Second &&
      a.Milliseconds == b.Milliseconds;
}

_RegTziFormat _ReadRegTziFormat(Uint8List bytes) {
  final view = ByteData.sublistView(bytes);
  return _RegTziFormat(
    view.getInt32(0, Endian.little),
    view.getInt32(4, Endian.little),
    view.getInt32(8, Endian.little),
    WindowsSystemTime.Read(view, 12),
    WindowsSystemTime.Read(view, 28),
  );
}

/// new TIME_ZONE_INFORMATION(in TIME_DYNAMIC_ZONE_INFORMATION).
_TimeZoneInformation _TimeZoneInformationFromDynamic(WindowsDynamicTimeZoneInformation dtzi) {
  return _TimeZoneInformation(dtzi.Bias, dtzi.StandardBias, dtzi.DaylightBias, dtzi.StandardDate, dtzi.DaylightDate,
      dtzi.StandardName, dtzi.DaylightName);
}

/// CultureInfo.Parent, for the names .NET looks for tzres.dll.mui under: "en-GB" → "en" → "" (invariant).
String _ParentCultureName(String name) {
  final index = name.lastIndexOf('-');
  return index < 0 ? '' : name.substring(0, index);
}

/// One Windows machine's system zones: TimeZoneInfo's static members and their cache (CachedData).
@internal
final class TimeZoneInfoCachedData implements ISystemTimeZoneLookup {
  final IWindowsTimeZoneApi _api;
  TimeZoneInfo? _localTimeZone;
  TimeZoneInfo? _utcTimeZone;

  /// Keyed by the upper-cased ID (StringComparer.OrdinalIgnoreCase); insertion-ordered, as .NET's Dictionary is.
  Map<String, TimeZoneInfo>? _systemTimeZones;
  List<TimeZoneInfo>? _readOnlySystemTimeZones;
  Map<String, TimeZoneInfo>? _timeZonesUsingAlternativeIds;
  bool _allSystemTimeZonesRead = false;

  TimeZoneInfoCachedData(this._api);

  /// The API the data is read through.
  IWindowsTimeZoneApi get Api => _api;

  // #region TimeZoneInfo.cs (static members)

  /// TimeZoneInfo.Local: the local time zone (from GetDynamicTimeZoneInformation).
  TimeZoneInfo get Local => _localTimeZone ?? _CreateLocal();

  /// TimeZoneInfo.Utc.
  @override
  TimeZoneInfo get Utc => _utcTimeZone ??= _CreateUtcTimeZone();

  TimeZoneInfo _CreateLocal() {
    var timeZone = _localTimeZone;
    if (timeZone == null) {
      // noda_dart: the zone the TZ environment variable names, if it's set (see LocalTimeZoneFromTZ.dart).
      timeZone = GetLocalTimeZoneFromTZ(this) ?? _GetLocalTimeZone();

      // this step is to break the reference equality
      // between TimeZoneInfo.Local and a second time zone
      // such as "Pacific Standard Time"
      timeZone = TimeZoneInfo
          .NewIdBaseUtcOffsetDisplayNameStandardDisplayNameDaylightDisplayNameAdjustmentRulesDisableDaylightSavingTimeHasIanaId(
              timeZone.Id,
              timeZone.BaseUtcOffset,
              timeZone.DisplayName,
              timeZone.StandardName,
              timeZone.DaylightName,
              timeZone.AdjustmentRulesOrNull,
              false,
              timeZone.HasIanaId);

      _localTimeZone = timeZone;
    }
    return timeZone;
  }

  /// TimeZoneInfo.FindSystemTimeZoneById.
  ///
  /// Throws [TimeZoneNotFoundException] if the zone wasn't found, and [InvalidTimeZoneException] if the zone's data
  /// is invalid.
  @override
  TimeZoneInfo FindSystemTimeZoneById(String id) {
    final (Result: result, Value: value, Error: e) = _TryFindSystemTimeZoneById(id);
    switch (result) {
      case _TimeZoneInfoResult.Success:
        return value!;
      case _TimeZoneInfoResult.InvalidTimeZoneException:
        throw e ??
            InvalidTimeZoneException(
                "The time zone ID '$id' was found on the local computer, but the registry information was corrupt.");
      default:
        throw TimeZoneNotFoundException("The time zone ID '$id' was not found on the local computer.", e);
    }
  }

  _TimeZoneInfoTryResult _TryFindSystemTimeZoneById(String id) {
    // Special case for Utc as it will not exist in the dictionary with the rest
    // of the system time zones.  There is no need to do this check for Local.Id
    // since Local is a real time zone that exists in the dictionary cache
    if (id.toUpperCase() == _UtcId) {
      return (Result: _TimeZoneInfoResult.Success, Value: Utc, Error: null);
    }

    // Dart: null safety checks id.
    if (id.isEmpty || id.length > _MaxKeyLength || id.contains('\u0000')) {
      return (Result: _TimeZoneInfoResult.TimeZoneNotFoundException, Value: null, Error: null);
    }

    return _TryGetTimeZone(id, false, false);
  }

  /// TimeZoneInfo.GetSystemTimeZones(): every valid zone in the registry, sorted by base offset, then display name.
  @override
  List<TimeZoneInfo> GetSystemTimeZones() {
    var readOnlySystemTimeZones = _readOnlySystemTimeZones;
    if (readOnlySystemTimeZones == null) {
      if (!_allSystemTimeZonesRead) {
        _PopulateAllSystemTimeZones();
        _allSystemTimeZonesRead = true;
      }

      final systemTimeZones = _systemTimeZones;
      if (systemTimeZones != null) {
        // return a collection of the cached system time zones
        final array = systemTimeZones.values.toList();

        // sort and copy the TimeZoneInfo's into a ReadOnlyCollection for the user
        // (Array.Sort is unstable, but no two zones compare equal: their display names differ.)
        array.sort((x, y) {
          // sort by BaseUtcOffset first and by DisplayName second - this is similar to the Windows Date/Time control panel
          final comparison = x.BaseUtcOffset.compareTo(y.BaseUtcOffset);
          return comparison == 0 ? x.DisplayName.compareTo(y.DisplayName) : comparison;
        });
        readOnlySystemTimeZones = List.unmodifiable(array);
      } else {
        readOnlySystemTimeZones = const [];
      }
      _readOnlySystemTimeZones = readOnlySystemTimeZones;
    }
    return readOnlySystemTimeZones;
  }

  _TimeZoneInfoTryResult _TryGetTimeZone(String id, bool dstDisabled, bool alwaysFallbackToLocalMachine) {
    var found = _TryGetTimeZoneUsingId(id, dstDisabled, alwaysFallbackToLocalMachine);
    if (found.Result != _TimeZoneInfoResult.Success) {
      final alternativeId = _GetAlternativeId(id);
      if (alternativeId != null) {
        found = _TryGetTimeZoneUsingId(alternativeId, dstDisabled, alwaysFallbackToLocalMachine);
        if (found.Result == _TimeZoneInfoResult.Success) {
          final value = found.Value!;
          const idIsIana = true;
          TimeZoneInfo? zone;
          final equivalentZones = value.equivalentZones;
          if (equivalentZones == null) {
            zone = TimeZoneInfo
                .NewIdBaseUtcOffsetDisplayNameStandardDisplayNameDaylightDisplayNameAdjustmentRulesDisableDaylightSavingTimeHasIanaId(
                    id,
                    value.BaseUtcOffset,
                    value.DisplayName,
                    value.StandardName,
                    value.DaylightName,
                    value.AdjustmentRulesOrNull,
                    dstDisabled && value.SupportsDaylightSavingTime,
                    idIsIana);
            value.equivalentZones = [zone];
          } else {
            for (final tzi in equivalentZones) {
              if (tzi.Id == id) {
                zone = tzi;
                break;
              }
            }
            if (zone == null) {
              zone = TimeZoneInfo
                  .NewIdBaseUtcOffsetDisplayNameStandardDisplayNameDaylightDisplayNameAdjustmentRulesDisableDaylightSavingTimeHasIanaId(
                      id,
                      value.BaseUtcOffset,
                      value.DisplayName,
                      value.StandardName,
                      value.DaylightName,
                      value.AdjustmentRulesOrNull,
                      dstDisabled && value.SupportsDaylightSavingTime,
                      idIsIana);
              equivalentZones.add(zone);
            }
          }

          (_timeZonesUsingAlternativeIds ??= <String, TimeZoneInfo>{})[id.toUpperCase()] = zone;

          found = (Result: found.Result, Value: zone, Error: found.Error);
        }
      }
    }

    return found;
  }

  _TimeZoneInfoTryResult _TryGetTimeZoneUsingId(String id, bool dstDisabled, bool alwaysFallbackToLocalMachine) {
    // check the cache
    final systemTimeZones = _systemTimeZones;
    if (systemTimeZones != null) {
      var value = systemTimeZones[id.toUpperCase()];
      if (value != null) {
        if (dstDisabled && value.SupportsDaylightSavingTime) {
          // we found a cache hit but we want a time zone without DST and this one has DST data
          value = TimeZoneInfo.CreateCustomTimeZone(value.Id, value.BaseUtcOffset, value.DisplayName, value.StandardName);
        }

        return (Result: _TimeZoneInfoResult.Success, Value: value, Error: null);
      }
    }

    final timeZonesUsingAlternativeIds = _timeZonesUsingAlternativeIds;
    if (timeZonesUsingAlternativeIds != null) {
      var value = timeZonesUsingAlternativeIds[id.toUpperCase()];
      if (value != null) {
        if (dstDisabled && value.SupportsDaylightSavingTime) {
          // we found a cache hit but we want a time zone without DST and this one has DST data
          value = TimeZoneInfo.CreateCustomTimeZone(value.Id, value.BaseUtcOffset, value.DisplayName, value.StandardName);
        }

        return (Result: _TimeZoneInfoResult.Success, Value: value, Error: null);
      }
    }

    // Fall back to reading from the local machine when the cache is not fully populated.
    if (!_allSystemTimeZonesRead || alwaysFallbackToLocalMachine) {
      return _TryGetTimeZoneFromLocalMachineAndCache(id, dstDisabled);
    }
    return (Result: _TimeZoneInfoResult.TimeZoneNotFoundException, Value: null, Error: null);
  }

  _TimeZoneInfoTryResult _TryGetTimeZoneFromLocalMachineAndCache(String id, bool dstDisabled) {
    final found = _TryGetTimeZoneFromLocalMachine(id);
    var value = found.Value;

    if (found.Result == _TimeZoneInfoResult.Success) {
      final systemTimeZones = _systemTimeZones ??= <String, TimeZoneInfo>{_UtcId: Utc};

      // Avoid using multiple Utc objects to ensure consistency and correctness as we have some code
      // uses reference equality with the Utc object.
      if (id.toUpperCase() != _UtcId) {
        // (Dictionary.Add throws for a duplicate key; the cache was checked first.)
        systemTimeZones[id.toUpperCase()] = value!;
      }

      if (dstDisabled && value!.SupportsDaylightSavingTime) {
        // we found a cache hit but we want a time zone without DST and this one has DST data
        value = TimeZoneInfo.CreateCustomTimeZone(value.Id, value.BaseUtcOffset, value.DisplayName, value.StandardName);
      }
    }

    return (Result: found.Result, Value: value, Error: found.Error);
  }

  // Helper function to create the static UTC time zone instance
  TimeZoneInfo _CreateUtcTimeZone() {
    final standardDisplayName = _GetUtcStandardDisplayName();
    final displayName = _GetUtcFullDisplayName(_UtcId, standardDisplayName);
    return TimeZoneInfo.CreateCustomTimeZone(_UtcId, 0, displayName, standardDisplayName);
  }

  // #endregion

  // #region TimeZoneInfo.Win32.cs

  void _PopulateAllSystemTimeZones() {
    _systemTimeZones ??= <String, TimeZoneInfo>{_UtcId: Utc};

    final keyNames = _api.GetRegistrySubKeyNames(_TimeZonesRegistryHive);
    if (keyNames != null) {
      for (final keyName in keyNames) {
        _TryGetTimeZone(keyName, false, false); // populate the cache
      }
    }
  }

  String? _GetAlternativeId(String id) {
    return TryConvertIanaIdToWindowsId(id);
  }

  /// private TimeZoneInfo(in TIME_ZONE_INFORMATION zone, bool dstDisabled)
  static TimeZoneInfo _FromTimeZoneInformation(_TimeZoneInformation zone, bool dstDisabled) {
    final standardName = zone.StandardName;
    // the ID must contain at least 1 character - initialize _id to "Local"
    final id = standardName.isEmpty ? _LocalId : standardName;
    final baseUtcOffset = TimeSpanFromMinutes(-zone.Bias);

    List<TimeZoneInfoAdjustmentRule>? adjustmentRules;
    if (!dstDisabled) {
      // only create the adjustment rule if DST is enabled
      final _RegTziFormat regZone = zone;
      final rule = _CreateAdjustmentRuleFromTimeZoneInformation(
          regZone, DateTime.MinValue.Date, DateTime.MaxValue.Date, zone.Bias);
      if (rule != null) {
        adjustmentRules = [rule];
      }
    }

    // (.NET sets the fields directly, with _displayName = _standardDisplayName = standardName.)
    return TimeZoneInfo
        .NewIdBaseUtcOffsetDisplayNameStandardDisplayNameDaylightDisplayNameAdjustmentRulesDisableDaylightSavingTimeHasIanaId(
            id, baseUtcOffset, standardName, standardName, zone.DaylightName, adjustmentRules, false);
  }

  /// Helper function to check if the current TimeZoneInformation struct does not support DST.
  /// This check returns true when the DaylightDate == StandardDate.
  /// This check is only meant to be used for "Local".
  static bool _CheckDaylightSavingTimeNotSupported(_TimeZoneInformation timeZone) {
    return _SystemTimeEquals(timeZone.DaylightDate, timeZone.StandardDate);
  }

  /// Converts a REG_TZI_FORMAT struct to an AdjustmentRule.
  static TimeZoneInfoAdjustmentRule? _CreateAdjustmentRuleFromTimeZoneInformation(
      _RegTziFormat timeZoneInformation, DateTime startDate, DateTime endDate, int defaultBaseUtcOffset) {
    final supportsDst = timeZoneInformation.StandardDate.Month != 0;

    if (!supportsDst) {
      if (timeZoneInformation.Bias == defaultBaseUtcOffset) {
        // this rule will not contain any information to be used to adjust dates. just ignore it
        return null;
      }

      return TimeZoneInfoAdjustmentRule.CreateAdjustmentRule(
          startDate,
          endDate,
          0, // no daylight saving transition
          TimeZoneInfoTransitionTime.CreateFixedDateRule(DateTime.MinValue, 1, 1),
          TimeZoneInfoTransitionTime.CreateFixedDateRule(DateTime.MinValue.AddMilliseconds(1), 1, 1),
          TimeSpanFromMinutes(defaultBaseUtcOffset - timeZoneInformation.Bias)); // Bias delta is all what we need from this rule
    }

    //
    // Create an AdjustmentRule with TransitionTime objects
    //
    final daylightTransitionStart = _TransitionTimeFromTimeZoneInformation(timeZoneInformation, true);
    if (daylightTransitionStart == null) {
      return null;
    }

    final daylightTransitionEnd = _TransitionTimeFromTimeZoneInformation(timeZoneInformation, false);
    if (daylightTransitionEnd == null) {
      return null;
    }

    if (daylightTransitionStart.Equals(daylightTransitionEnd)) {
      // this happens when the time zone does support DST but the OS has DST disabled
      return null;
    }

    return TimeZoneInfoAdjustmentRule.CreateAdjustmentRule(
        startDate,
        endDate,
        TimeSpanFromMinutes(-timeZoneInformation.DaylightBias),
        daylightTransitionStart,
        daylightTransitionEnd,
        TimeSpanFromMinutes(defaultBaseUtcOffset - timeZoneInformation.Bias));
  }

  /// Helper function that searches the registry for a time zone entry
  /// that matches the TimeZoneInformation struct.
  ({String? Id, bool DstDisabled}) _FindIdFromTimeZoneInformation(_TimeZoneInformation timeZone) {
    var dstDisabled = false;

    final keyNames = _api.GetRegistrySubKeyNames(_TimeZonesRegistryHive);
    if (keyNames == null) {
      return (Id: null, DstDisabled: dstDisabled);
    }

    for (final keyName in keyNames) {
      final compared = _TryCompareTimeZoneInformationToRegistry(timeZone, keyName);
      dstDisabled = compared.DstDisabled;
      if (compared.Result) {
        return (Id: keyName, DstDisabled: dstDisabled);
      }
    }

    return (Id: null, DstDisabled: dstDisabled);
  }

  /// Helper function for retrieving the local system time zone.
  TimeZoneInfo _GetLocalTimeZone() {
    //
    // Try using the "kernel32!GetDynamicTimeZoneInformation" API to get the "id"
    //

    // call kernel32!GetDynamicTimeZoneInformation...
    final dynamicTimeZoneInformation = _api.GetDynamicTimeZoneInformation();
    if (dynamicTimeZoneInformation == null) {
      // return a dummy entry
      return TimeZoneInfo.CreateCustomTimeZone(_LocalId, 0, _LocalId, _LocalId);
    }

    // check to see if we can use the key name returned from the API call
    final dynamicTimeZoneKeyName = dynamicTimeZoneInformation.TimeZoneKeyName;
    if (dynamicTimeZoneKeyName.isNotEmpty) {
      final found =
          _TryGetTimeZone(dynamicTimeZoneKeyName, dynamicTimeZoneInformation.DynamicDaylightTimeDisabled, false);
      if (found.Result == _TimeZoneInfoResult.Success) {
        // successfully loaded the time zone from the registry
        return found.Value!;
      }
    }

    final timeZoneInformation = _TimeZoneInformationFromDynamic(dynamicTimeZoneInformation);

    // the key name was not returned or it pointed to a bogus entry - search for the entry ourselves
    final (Id: id, DstDisabled: dstDisabled) = _FindIdFromTimeZoneInformation(timeZoneInformation);

    if (id != null) {
      final found = _TryGetTimeZone(id, dstDisabled, false);
      if (found.Result == _TimeZoneInfoResult.Success) {
        // successfully loaded the time zone from the registry
        return found.Value!;
      }
    }

    // We could not find the data in the registry.  Fall back to using
    // the data from the Win32 API
    return _GetLocalTimeZoneFromWin32Data(timeZoneInformation, dstDisabled);
  }

  /// Helper function used by 'GetLocalTimeZone()' - this function wraps a bunch of
  /// try/catch logic for handling the TimeZoneInfo private constructor that takes
  /// a TIME_ZONE_INFORMATION structure.
  static TimeZoneInfo _GetLocalTimeZoneFromWin32Data(_TimeZoneInformation timeZoneInformation, bool dstDisabled) {
    // first try to create the TimeZoneInfo with the original 'dstDisabled' flag
    try {
      return _FromTimeZoneInformation(timeZoneInformation, dstDisabled);
    } on ArgumentError {
      // (ArgumentException, and ArgumentOutOfRangeException: RangeError extends ArgumentError.)
    } on InvalidTimeZoneException {
      //
    }

    // if 'dstDisabled' was false then try passing in 'true' as a last ditch effort
    if (!dstDisabled) {
      try {
        return _FromTimeZoneInformation(timeZoneInformation, true);
      } on ArgumentError {
        //
      } on InvalidTimeZoneException {
        //
      }
    }

    // the data returned from Windows is completely bogus; return a dummy entry
    return TimeZoneInfo.CreateCustomTimeZone(_LocalId, 0, _LocalId, _LocalId);
  }

  /// Converts a REG_TZI_FORMAT struct to a TransitionTime
  /// - When the argument 'readStart' is true the corresponding daylightTransitionTimeStart field is read
  /// - When the argument 'readStart' is false the corresponding dayightTransitionTimeEnd field is read
  ///
  /// Returns the transition time, or null (.NET's false).
  static TimeZoneInfoTransitionTime? _TransitionTimeFromTimeZoneInformation(
      _RegTziFormat timeZoneInformation, bool readStartDate) {
    //
    // SYSTEMTIME -
    //
    // If the time zone does not support daylight saving time or if the caller needs
    // to disable daylight saving time, the wMonth member in the SYSTEMTIME structure
    // must be zero. If this date is specified, the DaylightDate value in the
    // TIME_ZONE_INFORMATION structure must also be specified. Otherwise, the system
    // assumes the time zone data is invalid and no changes will be applied.
    //
    final supportsDst = timeZoneInformation.StandardDate.Month != 0;

    if (!supportsDst) {
      return null;
    }

    //
    // SYSTEMTIME -
    //
    // * FixedDateRule -
    //   If the Year member is not zero, the transition date is absolute; it will only occur one time
    //
    // * FloatingDateRule -
    //   To select the correct day in the month, set the Year member to zero, the Hour and Minute
    //   members to the transition time, the DayOfWeek member to the appropriate weekday, and the
    //   Day member to indicate the occurrence of the day of the week within the month (first through fifth).
    //
    //   Using this notation, specify the 2:00a.m. on the first Sunday in April as follows:
    //   Hour      = 2,
    //   Month     = 4,
    //   DayOfWeek = 0,
    //   Day       = 1.
    //
    //   Specify 2:00a.m. on the last Thursday in October as follows:
    //   Hour      = 2,
    //   Month     = 10,
    //   DayOfWeek = 4,
    //   Day       = 5.
    //
    // (The "daylightTransitionStart" is read from DaylightDate, the "daylightTransitionEnd" from StandardDate.)
    final date = readStartDate ? timeZoneInformation.DaylightDate : timeZoneInformation.StandardDate;
    final timeOfDay = DateTime.Create(
        1 /* year */, 1 /* month */, 1 /* day */, date.Hour, date.Minute, date.Second, date.Milliseconds);
    if (date.Year == 0) {
      return TimeZoneInfoTransitionTime.CreateFloatingDateRule(
          timeOfDay, date.Month, date.Day /* Week 1-5 */, date.DayOfWeek);
    } else {
      return TimeZoneInfoTransitionTime.CreateFixedDateRule(timeOfDay, date.Month, date.Day);
    }
  }

  /// Helper function that takes:
  ///  1. A string representing a time_zone_name registry key name.
  ///  2. A REG_TZI_FORMAT struct containing the default rule.
  ///  3. An AdjustmentRule[] out-parameter.
  ({bool Success, List<TimeZoneInfoAdjustmentRule>? Rules, Object? Error}) _TryCreateAdjustmentRules(
      String id, _RegTziFormat defaultTimeZoneInformation, int defaultBaseUtcOffset) {
    List<TimeZoneInfoAdjustmentRule>? rules;

    try {
      // Optional, Dynamic Time Zone Registry Data
      // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      //
      // HKLM
      //     Software
      //         Microsoft
      //             Windows NT
      //                 CurrentVersion
      //                     Time Zones
      //                         <time_zone_name>
      //                             Dynamic DST
      // * "FirstEntry" REG_DWORD "1980"
      //                           First year in the table. If the current year is less than this value,
      //                           this entry will be used for DST boundaries
      // * "LastEntry"  REG_DWORD "2038"
      //                           Last year in the table. If the current year is greater than this value,
      //                           this entry will be used for DST boundaries"
      // * "<year1>"    REG_BINARY REG_TZI_FORMAT
      // * "<year2>"    REG_BINARY REG_TZI_FORMAT
      // * "<year3>"    REG_BINARY REG_TZI_FORMAT
      //
      final dynamicKey = '$_TimeZonesRegistryHive\\$id\\Dynamic DST';
      if (!_api.RegistryKeyExists(dynamicKey)) {
        final rule = _CreateAdjustmentRuleFromTimeZoneInformation(
            defaultTimeZoneInformation, DateTime.MinValue.Date, DateTime.MaxValue.Date, defaultBaseUtcOffset);
        if (rule != null) {
          rules = [rule];
        }
        return (Success: true, Rules: rules, Error: null);
      }

      //
      // loop over all of the "<time_zone_name>\Dynamic DST" hive entries
      //
      // read FirstEntry  {MinValue      - (year1, 12, 31)}
      // read MiddleEntry {(yearN, 1, 1) - (yearN, 12, 31)}
      // read LastEntry   {(yearN, 1, 1) - MaxValue       }

      // read the FirstEntry and LastEntry key values (ex: "1980", "2038")
      final first = _GetIntValue(dynamicKey, _FirstEntryValue, -1);
      final last = _GetIntValue(dynamicKey, _LastEntryValue, -1);

      if (first == -1 || last == -1 || first > last) {
        return (Success: false, Rules: null, Error: null);
      }

      // read the first year entry

      var dtzi = _TryGetTimeZoneEntryFromRegistry(dynamicKey, first.toString());
      if (dtzi == null) {
        return (Success: false, Rules: null, Error: null);
      }

      if (first == last) {
        // there is just 1 dynamic rule for this time zone.
        final rule = _CreateAdjustmentRuleFromTimeZoneInformation(
            dtzi, DateTime.MinValue.Date, DateTime.MaxValue.Date, defaultBaseUtcOffset);
        if (rule != null) {
          rules = [rule];
        }
        return (Success: true, Rules: rules, Error: null);
      }

      final rulesList = <TimeZoneInfoAdjustmentRule>[];

      // there are more than 1 dynamic rules for this time zone.
      final firstRule = _CreateAdjustmentRuleFromTimeZoneInformation(
          dtzi,
          DateTime.MinValue.Date, // MinValue
          DateTime.Create(first, 12, 31), // December 31, <FirstYear>
          defaultBaseUtcOffset);

      if (firstRule != null) {
        rulesList.add(firstRule);
      }

      // read the middle year entries
      for (var i = first + 1; i < last; i++) {
        dtzi = _TryGetTimeZoneEntryFromRegistry(dynamicKey, i.toString());
        if (dtzi == null) {
          return (Success: false, Rules: null, Error: null);
        }
        final middleRule = _CreateAdjustmentRuleFromTimeZoneInformation(
            dtzi,
            DateTime.Create(i, 1, 1), // January  01, <Year>
            DateTime.Create(i, 12, 31), // December 31, <Year>
            defaultBaseUtcOffset);

        if (middleRule != null) {
          rulesList.add(middleRule);
        }
      }

      // read the last year entry
      dtzi = _TryGetTimeZoneEntryFromRegistry(dynamicKey, last.toString());
      if (dtzi == null) {
        return (Success: false, Rules: null, Error: null);
      }
      final lastRule = _CreateAdjustmentRuleFromTimeZoneInformation(
          dtzi,
          DateTime.Create(last, 1, 1), // January  01, <LastYear>
          DateTime.MaxValue.Date, // MaxValue
          defaultBaseUtcOffset);

      if (lastRule != null) {
        rulesList.add(lastRule);
      }

      // convert the List to an AdjustmentRule array
      if (rulesList.isNotEmpty) {
        rules = rulesList;
      }
    } on _InvalidCastException catch (ex) {
      // one of the RegistryKey.GetValue calls could not be cast to an expected value type
      return (Success: false, Rules: null, Error: ex);
    } on ArgumentError catch (ex) {
      // the data is out of range (ArgumentOutOfRangeException, ArgumentException: RangeError extends ArgumentError)
      return (Success: false, Rules: null, Error: ex);
    }
    return (Success: true, Rules: rules, Error: null);
  }

  /// (int)key.GetValue(name, defaultValue): a REG_DWORD, or the default if the value is missing.
  int _GetIntValue(String keyPath, String name, int defaultValue) {
    final value = _api.GetRegistryValue(keyPath, name);
    if (value == null) {
      return defaultValue;
    }
    if (value is! int) {
      // The C# cast fails; TryCreateAdjustmentRules catches it.
      throw _InvalidCastException('Unable to cast the registry value to System.Int32.');
    }
    return value.toSigned(32);
  }

  _RegTziFormat? _TryGetTimeZoneEntryFromRegistry(String keyPath, String name) {
    final regValue = _api.GetRegistryValue(keyPath, name);
    if (regValue is! Uint8List || regValue.length != _RegTziFormatSize) {
      return null;
    }
    return _ReadRegTziFormat(regValue);
  }

  /// Helper function that compares the StandardBias and StandardDate portion a
  /// TimeZoneInformation struct to a time zone registry entry.
  static bool _TryCompareStandardDate(_TimeZoneInformation timeZone, _RegTziFormat registryTimeZoneInfo) {
    return timeZone.Bias == registryTimeZoneInfo.Bias &&
        timeZone.StandardBias == registryTimeZoneInfo.StandardBias &&
        _SystemTimeEquals(timeZone.StandardDate, registryTimeZoneInfo.StandardDate);
  }

  /// Helper function that compares a TimeZoneInformation struct to a time zone registry entry.
  ({bool Result, bool DstDisabled}) _TryCompareTimeZoneInformationToRegistry(_TimeZoneInformation timeZone, String id) {
    const dstDisabled = false;

    final keyPath = '$_TimeZonesRegistryHive\\$id';
    if (!_api.RegistryKeyExists(keyPath)) {
      return (Result: false, DstDisabled: dstDisabled);
    }

    final registryTimeZoneInfo = _TryGetTimeZoneEntryFromRegistry(keyPath, _TimeZoneInfoValue);
    if (registryTimeZoneInfo == null) {
      return (Result: false, DstDisabled: dstDisabled);
    }

    //
    // first compare the bias and standard date information between the data from the Win32 API
    // and the data from the registry...
    //
    var result = _TryCompareStandardDate(timeZone, registryTimeZoneInfo);

    if (!result) {
      return (Result: false, DstDisabled: dstDisabled);
    }

    result = dstDisabled ||
        _CheckDaylightSavingTimeNotSupported(timeZone) ||
        //
        // since Daylight Saving Time is not "disabled", do a straight comparison between
        // the Win32 API data and the registry data ...
        //
        (timeZone.DaylightBias == registryTimeZoneInfo.DaylightBias &&
            _SystemTimeEquals(timeZone.DaylightDate, registryTimeZoneInfo.DaylightDate));

    // Finally compare the "StandardName" string value...
    //
    // we do not compare "DaylightName" as this TimeZoneInformation field may contain
    // either "StandardName" or "DaylightName" depending on the time of year and current machine settings
    //
    if (result) {
      final registryStandardName = _GetStringValue(keyPath, _StandardValue);
      result = registryStandardName == timeZone.StandardName;
    }
    return (Result: result, DstDisabled: dstDisabled);
  }

  /// key.GetValue(name, string.Empty) as string: null if the value isn't a string.
  String? _GetStringValue(String keyPath, String name) {
    final value = _api.GetRegistryValue(keyPath, name);
    return value == null ? '' : (value is String ? value : null);
  }

  static final RegExp _IntegerPattern = RegExp(r'^[+-]?[0-9]+$');

  /// Try to find the time zone resources Dll matching the CurrentUICulture or one of its parent cultures.
  /// We try to check of such resource module e.g. %windir%\system32\[UI Culture Name]\tzres.dll.mui exist.
  /// If a localized resource file exists, we LoadString resource with the id specified inside resource input
  /// string and and return it to our caller.
  String _GetLocalizedNameByMuiNativeResource(String resource) {
    if (resource.isEmpty) {
      return '';
    }

    // parse "@tzres.dll, -100"
    //
    // filePath   = "C:\Windows\System32\tzres.dll"
    // resourceId = -100
    //
    final resources = resource.split(',');
    if (resources.length != 2) {
      return '';
    }

    // Get the resource ID (int.TryParse with NumberStyles.Integer: optional whitespace and sign)
    final idText = resources[1].replaceAll(RegExp(r'^[\t\n\v\f\r ]+|[\t\n\v\f\r ]+$'), '');
    if (!_IntegerPattern.hasMatch(idText)) {
      return '';
    }
    final parsed = BigInt.parse(idText.startsWith('+') ? idText.substring(1) : idText);
    if (parsed.abs() > BigInt.from(0x7fffffff)) {
      return '';
    }
    final resourceId = -parsed.toInt();

    // Use the current UI culture when culture not specified
    var cultureName = _GetCurrentUICultureName();

    // get the path to Windows\System32
    final system32 = _api.GetSystemDirectory();

    // trim the string "@tzres.dll" to "tzres.dll" and append the "mui" file extension to it.
    final tzresDll = '${resources[0].replaceFirst(RegExp(r'^@+'), '')}.mui';

    while (cultureName.isNotEmpty) {
      final filePath = _JoinPath(_JoinPath(system32, cultureName), tzresDll);
      if (_api.FileExists(filePath)) {
        // Finally, get the resource from the resource path
        return _api.LoadString(filePath, resourceId);
      }

      cultureName = _ParentCultureName(cultureName);
    }

    return '';
  }

  /// CultureInfo.CurrentUICulture.Name on Windows: the user's first preferred UI language ("" if none).
  String _GetCurrentUICultureName() {
    final languages = _api.GetUserPreferredUILanguages();
    return languages.isEmpty ? '' : languages[0];
  }

  /// Helper function for retrieving the DisplayName, StandardName, and DaylightName from the registry
  ///
  /// The function first checks the MUI_ key-values, and if they exist, it loads the strings from the MUI
  /// resource dll(s).  When the keys do not exist, the function falls back to reading from the standard
  /// key-values
  ({String? DisplayName, String? StandardName, String? DaylightName}) _GetLocalizedNamesByRegistryKey(String keyPath) {
    String? displayName = '';
    String? standardName = '';
    String? daylightName = '';

    // read the MUI_ registry keys
    final displayNameMuiResource = _GetStringValue(keyPath, _MuiDisplayValue);
    final standardNameMuiResource = _GetStringValue(keyPath, _MuiStandardValue);
    final daylightNameMuiResource = _GetStringValue(keyPath, _MuiDaylightValue);

    // try to load the strings from the native resource DLL(s)
    if (displayNameMuiResource != null && displayNameMuiResource.isNotEmpty) {
      displayName = _GetLocalizedNameByMuiNativeResource(displayNameMuiResource);
    }

    if (standardNameMuiResource != null && standardNameMuiResource.isNotEmpty) {
      standardName = _GetLocalizedNameByMuiNativeResource(standardNameMuiResource);
    }

    if (daylightNameMuiResource != null && daylightNameMuiResource.isNotEmpty) {
      daylightName = _GetLocalizedNameByMuiNativeResource(daylightNameMuiResource);
    }

    // fallback to using the standard registry keys
    if (displayName.isEmpty) {
      displayName = _GetStringValue(keyPath, _DisplayValue);
    }
    if (standardName.isEmpty) {
      standardName = _GetStringValue(keyPath, _StandardValue);
    }
    if (daylightName.isEmpty) {
      daylightName = _GetStringValue(keyPath, _DaylightValue);
    }
    return (DisplayName: displayName, StandardName: standardName, DaylightName: daylightName);
  }

  /// Helper function that takes a string representing a time_zone_name registry key name
  /// and returns a TimeZoneInfo instance.
  _TimeZoneInfoTryResult _TryGetTimeZoneFromLocalMachine(String id) {
    // Standard Time Zone Registry Data
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // HKLM
    //     Software
    //         Microsoft
    //             Windows NT
    //                 CurrentVersion
    //                     Time Zones
    //                         <time_zone_name>
    // * STD,         REG_SZ "Standard Time Name"
    //                       (For OS installed zones, this will always be English)
    // * MUI_STD,     REG_SZ "@tzres.dll,-1234"
    //                       Indirect string to localized resource for Standard Time,
    //                       add "%windir%\system32\" after "@"
    // * DLT,         REG_SZ "Daylight Time Name"
    //                       (For OS installed zones, this will always be English)
    // * MUI_DLT,     REG_SZ "@tzres.dll,-1234"
    //                       Indirect string to localized resource for Daylight Time,
    //                       add "%windir%\system32\" after "@"
    // * Display,     REG_SZ "Display Name like (GMT-8:00) Pacific Time..."
    // * MUI_Display, REG_SZ "@tzres.dll,-1234"
    //                       Indirect string to localized resource for the Display,
    //                       add "%windir%\system32\" after "@"
    // * TZI,         REG_BINARY REG_TZI_FORMAT
    //
    final keyPath = '$_TimeZonesRegistryHive\\$id';
    if (!_api.RegistryKeyExists(keyPath)) {
      return (Result: _TimeZoneInfoResult.TimeZoneNotFoundException, Value: null, Error: null);
    }

    final defaultTimeZoneInformation = _TryGetTimeZoneEntryFromRegistry(keyPath, _TimeZoneInfoValue);
    if (defaultTimeZoneInformation == null) {
      // the registry value could not be cast to a byte array
      return (Result: _TimeZoneInfoResult.InvalidTimeZoneException, Value: null, Error: null);
    }

    final created = _TryCreateAdjustmentRules(id, defaultTimeZoneInformation, defaultTimeZoneInformation.Bias);
    if (!created.Success) {
      return (
        Result: _TimeZoneInfoResult.InvalidTimeZoneException,
        Value: null,
        Error: InvalidTimeZoneException(
            "The time zone ID '$id' was found on the local computer, but the registry information was corrupt.",
            created.Error),
      );
    }

    final (DisplayName: displayName, StandardName: standardName, DaylightName: daylightName) =
        _GetLocalizedNamesByRegistryKey(keyPath);

    try {
      final value = TimeZoneInfo
          .NewIdBaseUtcOffsetDisplayNameStandardDisplayNameDaylightDisplayNameAdjustmentRulesDisableDaylightSavingTimeHasIanaId(
              id,
              TimeSpanFromMinutes(-defaultTimeZoneInformation.Bias),
              displayName ?? '',
              standardName ?? '',
              daylightName ?? '',
              created.Rules,
              false);

      return (Result: _TimeZoneInfoResult.Success, Value: value, Error: null);
    } on ArgumentError catch (ex) {
      // TimeZoneInfo constructor can throw ArgumentException and InvalidTimeZoneException
      return (Result: _TimeZoneInfoResult.InvalidTimeZoneException, Value: null, Error: ex);
    } on InvalidTimeZoneException catch (ex) {
      return (Result: _TimeZoneInfoResult.InvalidTimeZoneException, Value: null, Error: ex);
    }
  }

  // Helper function to get the standard display name for the UTC static time zone instance
  String _GetUtcStandardDisplayName() {
    // Don't bother looking up the name for invariant or English cultures
    final uiCultureName = _GetCurrentUICultureName();
    if (uiCultureName.isEmpty || uiCultureName.split('-')[0].toLowerCase() == 'en') {
      return _InvariantUtcStandardDisplayName;
    }

    // Try to get a localized version of "Coordinated Universal Time" from the globalization data
    String? standardDisplayName;
    const keyPath = '$_TimeZonesRegistryHive\\$_UtcId';
    if (_api.RegistryKeyExists(keyPath)) {
      // read the MUI_ registry key
      final standardNameMuiResource = _GetStringValue(keyPath, _MuiStandardValue);

      // try to load the string from the native resource DLL(s)
      if (standardNameMuiResource != null && standardNameMuiResource.isNotEmpty) {
        standardDisplayName = _GetLocalizedNameByMuiNativeResource(standardNameMuiResource);
      }

      // fallback to using the standard registry key
      if (standardDisplayName == null || standardDisplayName.isEmpty) {
        standardDisplayName = _GetStringValue(keyPath, _StandardValue);
      }
    }

    // Final safety check.  Don't allow null or abbreviations
    if (standardDisplayName == null || standardDisplayName == 'GMT' || standardDisplayName == 'UTC') {
      standardDisplayName = _InvariantUtcStandardDisplayName;
    }

    return standardDisplayName;
  }

  // Helper function to get the full display name for the UTC static time zone instance
  static String _GetUtcFullDisplayName(String timeZoneId, String standardDisplayName) {
    return '(UTC) $standardDisplayName';
  }

  // #endregion
}

/// Path.Join for two Windows path segments.
String _JoinPath(String a, String b) {
  if (a.isEmpty) {
    return b;
  }
  if (b.isEmpty) {
    return a;
  }
  final separator = a.endsWith(r'\') || a.endsWith('/') || b.startsWith(r'\') || b.startsWith('/') ? '' : r'\';
  return a + separator + b;
}
