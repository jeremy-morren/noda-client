// noda_dart: new code (noda-js's IntlTimeZone.ts). Zones from the host's Intl (on the web), recovered by probing
// Intl.DateTimeFormat's offsets; plus Intl ID helpers. Native platforms have no Intl.

import 'dart:core';
import 'dart:core' as core show DateTime;

import 'package:meta/meta.dart';

import '../Instant.dart';
import '../Offset.dart';
import '../TimeZones/IZoneIntervalMap.dart';
import '../TimeZones/ZoneInterval.dart';
import 'Host.dart' as host;

// Transitions are found by sampling each UTC year every ProbeStepDays and binary-searching each change to the
// millisecond. Limitations (see docs/Timezones.md): transitions closer than ProbeStepDays that return to the same
// offset, and abbreviation-only changes, are missed; before MinProbeYear the offset is MinProbeYear's; from
// FinalRuleYear one final rule is assumed; the standard offset is the smallest in the interval's UTC year.

const int _MillisecondsPerDay = 86400000;

/// The first UTC year that is probed.
const int _MinProbeYear = 1800;

/// From this year on, the zone is assumed to follow its final rule.
const int _FinalRuleYear = 2040;

/// The last year that can be probed (the last year of NodaTime's Instant range).
const int _MaxProbeYear = 9999;

/// The interval between offset samples.
const int _ProbeStepMilliseconds = 7 * _MillisecondsPerDay;

/// The years sampled (at the start of each quarter) to estimate the minimum and maximum offsets.
const List<int> _OffsetRangeSampleMonths = [0, 3, 6, 9];

/// The largest daylight saving the standard-offset heuristic will infer (the largest in tzdb is 2 hours).
const int _MaxSavingsSeconds = 2 * 3600;

/// A part of Intl.DateTimeFormat's formatToParts result.
@internal
typedef IntlDateTimeFormatPart = ({String Type, String Value});

/// An Intl.DateTimeFormat, as the host gives it (System/Host_web.dart).
@internal
abstract interface class IntlDateTimeFormat {
  /// format(milliseconds).
  String Format(int milliseconds);

  /// formatToParts(milliseconds).
  List<IntlDateTimeFormatPart> FormatToParts(int milliseconds);

  /// resolvedOptions().timeZone.
  String? get ResolvedTimeZone;

  /// resolvedOptions().timeZoneName.
  String? get ResolvedTimeZoneName;
}

/// Milliseconds since the Unix epoch at the start of the given UTC year.
int _UtcYearStart(int year) {
  return core.DateTime.utc(year, 1, 1).millisecondsSinceEpoch;
}

int _UtcMonthStart(int year, int month) {
  return core.DateTime.utc(year, month + 1, 1).millisecondsSinceEpoch;
}

int _UtcYear(int ms) {
  return core.DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).year;
}

/// A transition found by probing: the first millisecond of a new offset.
typedef _ProbedTransition = ({int Milliseconds, int OffsetSeconds});

/// The transitions within one UTC year, [start of year, start of next year).
final class _YearData {
  /// The offset in force just before the start of the year.
  final int StartOffsetSeconds;
  final List<_ProbedTransition> Transitions;

  _YearData(this.StartOffsetSeconds, this.Transitions);
}

/// Reads offsets and abbreviations for one time zone from Intl.
final class _IntlZoneProbe {
  final String Id;

  /// Formatter whose output ends with a "GMT+hh:mm[:ss]" offset, or null if the host doesn't support "longOffset".
  final IntlDateTimeFormat? _offsetFormat;

  /// Fallback: formatter for the wall-clock fields, used to work out the offset if "longOffset" isn't available.
  IntlDateTimeFormat? _wallFormat;
  IntlDateTimeFormat? _nameFormat;

  /// Throws (a JavaScript RangeError) if the host doesn't support the given time zone ID.
  _IntlZoneProbe(this.Id) : _offsetFormat = _CreateOffsetFormat(Id);

  static IntlDateTimeFormat? _CreateOffsetFormat(String id) {
    host.NewIntlDateTimeFormat('en-US', {'timeZone': id});
    IntlDateTimeFormat? offsetFormat;
    try {
      final format =
          host.NewIntlDateTimeFormat('en-US', {'timeZone': id, 'timeZoneName': 'longOffset', 'hour': 'numeric'});
      if (format.ResolvedTimeZoneName == 'longOffset' && _ParseLongOffset(format.Format(0)) != null) {
        offsetFormat = format;
      }
    } catch (_) {
      // Older engines throw a RangeError for timeZoneName: "longOffset".
    }
    return offsetFormat;
  }

  /// The UTC offset in force at the given time, in seconds.
  int OffsetSecondsAt(int ms) {
    final offsetFormat = _offsetFormat;
    if (offsetFormat != null) {
      final seconds = _ParseLongOffset(offsetFormat.Format(ms));
      if (seconds != null) {
        return seconds;
      }
    }
    return _OffsetSecondsFromWallFields(ms);
  }

  /// The host's English abbreviation for the zone at the given time (e.g. "AEST", or "GMT+5:30").
  String NameAt(int ms) {
    final nameFormat = _nameFormat ??=
        host.NewIntlDateTimeFormat('en-US', {'timeZone': Id, 'timeZoneName': 'short', 'hour': 'numeric'});
    for (final part in nameFormat.FormatToParts(ms)) {
      if (part.Type == 'timeZoneName') {
        return part.Value;
      }
    }
    return Id;
  }

  static final RegExp _LongOffsetPattern = RegExp(r'^([+\-−])(\d{1,2})(?::(\d{2}))?(?::(\d{2}))?$');

  /// Parses the offset at the end of text such as "2 AM GMT+05:30", "2 AM GMT-03:00:00" or "2 AM GMT".
  static int? _ParseLongOffset(String text) {
    final index = text.lastIndexOf('GMT');
    if (index < 0) {
      return null;
    }
    final rest = text.substring(index + 3).trim();
    if (rest == '') {
      return 0;
    }
    // "-" or "−" (U+2212): some locales' CLDR data writes negative offsets with U+2212.
    final match = _LongOffsetPattern.firstMatch(rest);
    if (match == null) {
      return null;
    }
    final sign = match.group(1) == '+' ? 1 : -1;
    return sign *
        (int.parse(match.group(2)!) * 3600 +
            int.parse(match.group(3) ?? '0') * 60 +
            int.parse(match.group(4) ?? '0'));
  }

  int _OffsetSecondsFromWallFields(int ms) {
    final wallFormat = _wallFormat ??= host.NewIntlDateTimeFormat('en-US', {
      'timeZone': Id,
      // noda-js: hour12, not hourCycle (ignored before ES2020); some engines then give 24 at midnight (see below).
      'hour12': false,
      'era': 'short',
      'year': 'numeric',
      'month': 'numeric',
      'day': 'numeric',
      'hour': 'numeric',
      'minute': 'numeric',
      'second': 'numeric',
    });
    var year = 0;
    var month = 1;
    var day = 1;
    var hour = 0;
    var minute = 0;
    var second = 0;
    var beforeCommonEra = false;
    for (final part in wallFormat.FormatToParts(ms)) {
      switch (part.Type) {
        case 'era':
          beforeCommonEra = part.Value.startsWith('B');
          break;
        case 'year':
          year = int.parse(part.Value);
          break;
        case 'month':
          month = int.parse(part.Value);
          break;
        case 'day':
          day = int.parse(part.Value);
          break;
        case 'hour':
          // Some engines report midnight as 24 even with hourCycle h23.
          hour = int.parse(part.Value) % 24;
          break;
        case 'minute':
          minute = int.parse(part.Value);
          break;
        case 'second':
          second = int.parse(part.Value);
          break;
      }
    }
    if (beforeCommonEra) {
      year = 1 - year;
    }
    final local = core.DateTime.utc(year, month, day, hour, minute, second).millisecondsSinceEpoch;
    // The formatted wall time is truncated to the second.
    final wholeSecondMs = ms - ms % 1000;
    return ((local - wholeSecondMs) / 1000).round();
  }
}

/// The zone interval map of a time zone from Intl: zone intervals recovered by probing.
final class _IntlZoneIntervalMap implements IZoneIntervalMap {
  final _IntlZoneProbe _probe;
  final Map<int, _YearData> _years = {};
  @override
  final Offset MinOffset;
  @override
  final Offset MaxOffset;

  factory _IntlZoneIntervalMap(_IntlZoneProbe probe) {
    // Estimate the offset range from quarterly samples (exactly would need every transition in history).
    var min = probe.OffsetSecondsAt(_UtcYearStart(_MinProbeYear) - 1);
    var max = min;
    for (var year = _MinProbeYear; year <= _FinalRuleYear; year++) {
      for (final month in _OffsetRangeSampleMonths) {
        final offset = probe.OffsetSecondsAt(_UtcMonthStart(year, month));
        min = offset < min ? offset : min;
        max = offset > max ? offset : max;
      }
    }
    return _IntlZoneIntervalMap._(probe, Offset.FromSeconds(min), Offset.FromSeconds(max));
  }

  _IntlZoneIntervalMap._(this._probe, this.MinOffset, this.MaxOffset);

  @override
  ZoneInterval GetZoneInterval(Instant instant) {
    final ms = instant.ToUnixTimeMilliseconds();
    final year = _ClampYear(_UtcYear(ms));
    final data = _GetYearData(year);
    final transitions = data.Transitions;
    // The last transition at or before the instant (if any in this year).
    var index = -1;
    while (index + 1 < transitions.length && transitions[index + 1].Milliseconds <= ms) {
      index++;
    }
    final wallOffsetSeconds = index >= 0 ? transitions[index].OffsetSeconds : data.StartOffsetSeconds;
    final startMs = index >= 0 ? transitions[index].Milliseconds : _FindPreviousTransition(year - 1);
    final endMs = index + 1 < transitions.length ? transitions[index + 1].Milliseconds : _FindNextTransition(year + 1);

    // Standard offset heuristic: the smallest offset in force during the UTC year in which the interval starts,
    // ignoring offsets more than MaxSavingsSeconds below this one (such as a jump across the date line).
    final startYearData = _GetYearData(startMs == null ? _MinProbeYear : _ClampYear(_UtcYear(startMs)));
    var standardOffsetSeconds = wallOffsetSeconds;
    for (final offsetSeconds in [
      startYearData.StartOffsetSeconds,
      ...startYearData.Transitions.map((t) => t.OffsetSeconds),
    ]) {
      if (offsetSeconds < standardOffsetSeconds && wallOffsetSeconds - offsetSeconds <= _MaxSavingsSeconds) {
        standardOffsetSeconds = offsetSeconds;
      }
    }

    final name = _probe.NameAt(startMs ?? _UtcYearStart(_MinProbeYear) - 1);
    return ZoneInterval.NewNameStartEndWallOffsetSavings(
      name,
      startMs == null ? Instant.BeforeMinValue : Instant.FromUnixTimeMilliseconds(startMs),
      endMs == null ? Instant.AfterMaxValue : Instant.FromUnixTimeMilliseconds(endMs),
      Offset.FromSeconds(wallOffsetSeconds),
      Offset.FromSeconds(wallOffsetSeconds - standardOffsetSeconds),
    );
  }

  static int _ClampYear(int year) => year < _MinProbeYear ? _MinProbeYear : (year > _MaxProbeYear ? _MaxProbeYear : year);

  /// The last transition in or before the given year, or null if there isn't one.
  int? _FindPreviousTransition(int fromYear) {
    for (var year = fromYear < _MaxProbeYear ? fromYear : _MaxProbeYear; year >= _MinProbeYear; year--) {
      if (year > _FinalRuleYear && _IsFixedAfterFinalRuleYear()) {
        // No transitions between FinalRuleYear and this year.
        year = _FinalRuleYear + 1;
        continue;
      }
      final transitions = _GetYearData(year).Transitions;
      if (transitions.isNotEmpty) {
        return transitions[transitions.length - 1].Milliseconds;
      }
    }
    return null;
  }

  /// The first transition in or after the given year, or null if there isn't one.
  int? _FindNextTransition(int fromYear) {
    for (var year = fromYear > _MinProbeYear ? fromYear : _MinProbeYear; year <= _MaxProbeYear; year++) {
      if (year > _FinalRuleYear && _IsFixedAfterFinalRuleYear()) {
        return null;
      }
      final transitions = _GetYearData(year).Transitions;
      if (transitions.isNotEmpty) {
        return transitions[0].Milliseconds;
      }
    }
    return null;
  }

  bool _IsFixedAfterFinalRuleYear() {
    return _GetYearData(_FinalRuleYear).Transitions.isEmpty;
  }

  _YearData _GetYearData(int year) {
    var data = _years[year];
    if (data == null) {
      data = _ComputeYearData(year);
      _years[year] = data;
    }
    return data;
  }

  _YearData _ComputeYearData(int year) {
    if (year > _FinalRuleYear) {
      final finalYear = _GetYearData(_FinalRuleYear);
      if (finalYear.Transitions.isEmpty) {
        return finalYear;
      }
    }
    final probe = _probe;
    final end = _UtcYearStart(year + 1);
    final transitions = <_ProbedTransition>[];
    // Sample (start - 1, ..., end - 1], so that a transition exactly at the start of the year belongs to this year.
    var previousMs = _UtcYearStart(year) - 1;
    var previousOffset = probe.OffsetSecondsAt(previousMs);
    final startOffsetSeconds = previousOffset;
    while (previousMs < end - 1) {
      final nextMs = previousMs + _ProbeStepMilliseconds < end - 1 ? previousMs + _ProbeStepMilliseconds : end - 1;
      final nextOffset = probe.OffsetSecondsAt(nextMs);
      var lo = previousMs;
      var loOffset = previousOffset;
      while (loOffset != nextOffset) {
        // Binary search (lo, nextMs] for the first millisecond whose offset differs from loOffset.
        var hi = nextMs;
        var hiOffset = nextOffset;
        while (hi - lo > 1) {
          final mid = lo + (hi - lo) ~/ 2;
          final midOffset = probe.OffsetSecondsAt(mid);
          if (midOffset == loOffset) {
            lo = mid;
          } else {
            hi = mid;
            hiOffset = midOffset;
          }
        }
        transitions.add((Milliseconds: hi, OffsetSeconds: hiOffset));
        lo = hi;
        loOffset = hiOffset;
      }
      previousMs = nextMs;
      previousOffset = nextOffset;
    }
    return _YearData(startOffsetSeconds, transitions);
  }
}

/// The (uncached) zone interval map of the host's Intl zone [id]. Throws a JavaScript RangeError if unsupported.
@internal
IZoneIntervalMap CreateIntlZoneIntervalMap(String id) {
  return _IntlZoneIntervalMap(_IntlZoneProbe(id));
}

/// Whether the host has Intl.DateTimeFormat (time zone support is checked when a zone is created).
@internal
bool IsIntlAvailable() {
  return host.IntlIsAvailable();
}

/// Intl.supportedValuesOf("timeZone"), or [] where the host doesn't have it.
@internal
List<String> GetIntlSupportedTimeZones() {
  return host.IntlSupportedTimeZones() ?? const [];
}

/// The host's default time zone ID (Intl.DateTimeFormat().resolvedOptions().timeZone), or null.
@internal
String? GetIntlLocalId() {
  try {
    return IsIntlAvailable() ? host.NewIntlDateTimeFormat(null, const {}).ResolvedTimeZone : null;
  } catch (_) {
    return null;
  }
}

/// The ID as the host canonicalizes it ("Asia/Kolkata" → "Asia/Calcutta"), or null if it doesn't accept it.
/// noda_dart: on native platforms, Windows' own ICU canonicalizes it; elsewhere, null.
@internal
String? IntlCanonicalTimeZoneId(String id) {
  if (!IsIntlAvailable()) {
    return host.IcuCanonicalTimeZoneId(id);
  }
  try {
    return host.NewIntlDateTimeFormat('en-US', {'timeZone': id}).ResolvedTimeZone;
  } catch (_) {
    return null;
  }
}

/// Whether the host's Intl accepts the time zone ID.
@internal
bool IsIntlTimeZoneId(String id) {
  return IntlCanonicalTimeZoneId(id) != null;
}

/// The host's time zone data version, where it exposes one (Node's process.versions.tz), or "unknown".
@internal
String GetIntlTimeZoneVersion() {
  return host.GetProcessTzVersion() ?? 'unknown';
}

/// The host's English generic zone name (Intl's "longGeneric", e.g. "Australian Eastern Time"), or null.
@internal
String? GetIntlGenericName(String id) {
  try {
    final format = host.NewIntlDateTimeFormat('en-US', {'timeZone': id, 'timeZoneName': 'longGeneric'});
    for (final part in format.FormatToParts(0)) {
      if (part.Type == 'timeZoneName') {
        return part.Value;
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}
