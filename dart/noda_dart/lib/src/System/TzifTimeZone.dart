// noda_dart: new code. Zones from TZif files (RFC 8536) and their POSIX TZ footers, after time_machine2's tzif.dart.
// Pure Dart; TzifSystemTimeZones.dart reads the files. TZif records only whether a type is DST, so savings are
// inferred (see CreateTzifZoneIntervalMap), and names are abbreviations (see docs/Timezones.md).

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../Instant.dart';
import '../Offset.dart';
import '../TimeZones/IZoneIntervalMap.dart';
import '../TimeZones/PrecalculatedDateTimeZone.dart';
import '../TimeZones/SingleZoneIntervalMap.dart';
import '../TimeZones/ZoneInterval.dart';

/// A local time type ("ttinfo") in a TZif file.
@internal
final class TzifLocalTimeType {
  /// The UT offset in seconds (east of Greenwich is positive).
  final int UtOffset;
  final bool IsDst;
  final String Abbreviation;

  const TzifLocalTimeType(this.UtOffset, this.IsDst, this.Abbreviation);

  @override
  String toString() => '$Abbreviation $UtOffset${IsDst ? ' (DST)' : ''}';
}

/// The parts of a TZif file needed for conversion (leap seconds and indicators are skipped).
@internal
final class TzifData {
  /// The format version: 1, 2, 3 or 4.
  final int Version;

  /// Transition times in seconds since the Unix epoch, ascending.
  final List<int> TransitionTimes;

  /// For each transition, the index into [LocalTimeTypes] of the type that applies from it.
  final List<int> TransitionTypes;

  final List<TzifLocalTimeType> LocalTimeTypes;

  /// The POSIX TZ footer for instants after the last transition (version 2+), or null; empty means unspecified.
  final String? Footer;

  const TzifData(this.Version, this.TransitionTimes, this.TransitionTypes, this.LocalTimeTypes, this.Footer);
}

/// Whether [bytes] start with the TZif magic number ("TZif").
@internal
bool HasTzifMagic(List<int> bytes) =>
    bytes.length >= 4 && bytes[0] == 0x54 && bytes[1] == 0x5A && bytes[2] == 0x69 && bytes[3] == 0x66;

/// Parses TZif data (versions 1 to 4). For version 2 and later, the 64-bit data block and the footer are used.
///
/// Throws a [FormatException] if the data is malformed.
@internal
TzifData ParseTzif(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (!HasTzifMagic(bytes) || bytes.length < 44) {
    throw const FormatException('Not TZif data');
  }
  final versionByte = bytes[4];
  final version = versionByte == 0 ? 1 : versionByte - 0x30;
  if (version < 1 || version > 9) {
    throw FormatException('Unknown TZif version $versionByte');
  }

  var header = _TzifHeader(data, 0);
  var position = 44;
  if (version >= 2) {
    // Skip the version 1 block; the version 2+ block has 64-bit times.
    position += header.BlockSize(4);
    if (position + 44 > bytes.length) {
      throw const FormatException('Truncated TZif data');
    }
    header = _TzifHeader(data, position);
    position += 44;
    return _ReadBlock(bytes, data, header, position, 8, version);
  }
  return _ReadBlock(bytes, data, header, position, 4, version);
}

final class _TzifHeader {
  final int IsUtCount;
  final int IsStdCount;
  final int LeapCount;
  final int TimeCount;
  final int TypeCount;
  final int CharCount;

  _TzifHeader(ByteData data, int offset)
      : IsUtCount = data.getUint32(offset + 20),
        IsStdCount = data.getUint32(offset + 24),
        LeapCount = data.getUint32(offset + 28),
        TimeCount = data.getUint32(offset + 32),
        TypeCount = data.getUint32(offset + 36),
        CharCount = data.getUint32(offset + 40);

  int BlockSize(int timeSize) =>
      TimeCount * timeSize +
      TimeCount +
      TypeCount * 6 +
      CharCount +
      LeapCount * (timeSize + 4) +
      IsStdCount +
      IsUtCount;
}

TzifData _ReadBlock(Uint8List bytes, ByteData data, _TzifHeader header, int position, int timeSize, int version) {
  if (position + header.BlockSize(timeSize) > bytes.length) {
    throw const FormatException('Truncated TZif data');
  }
  if (header.TypeCount == 0) {
    throw const FormatException('TZif data has no local time types');
  }
  final times = <int>[];
  for (var i = 0; i < header.TimeCount; i++) {
    times.add(timeSize == 8 ? _GetInt64(data, position + i * 8) : data.getInt32(position + i * 4));
  }
  position += header.TimeCount * timeSize;
  final types = <int>[];
  for (var i = 0; i < header.TimeCount; i++) {
    final type = bytes[position + i];
    if (type >= header.TypeCount) {
      throw FormatException('Bad TZif transition type $type');
    }
    types.add(type);
  }
  position += header.TimeCount;

  final typeRecords = <(int, bool, int)>[];
  for (var i = 0; i < header.TypeCount; i++) {
    final offset = position + i * 6;
    typeRecords.add((data.getInt32(offset), bytes[offset + 4] != 0, bytes[offset + 5]));
  }
  position += header.TypeCount * 6;
  final chars = Uint8List.sublistView(bytes, position, position + header.CharCount);
  position += header.CharCount;
  final localTimeTypes = [
    for (final (utOffset, isDst, index) in typeRecords) TzifLocalTimeType(utOffset, isDst, _Abbreviation(chars, index)),
  ];

  position += header.LeapCount * (timeSize + 4) + header.IsStdCount + header.IsUtCount;

  String? footer;
  if (version >= 2 && position < bytes.length && bytes[position] == 0x0A) {
    final end = bytes.indexOf(0x0A, position + 1);
    if (end > position) {
      footer = ascii.decode(Uint8List.sublistView(bytes, position + 1, end), allowInvalid: true);
    }
  }
  return TzifData(version, times, types, localTimeTypes, footer);
}

int _GetInt64(ByteData data, int offset) {
  // noda_dart: arithmetic, as dart2js lacks getInt64 and truncates bitwise operators to 32 bits.
  final high = data.getInt32(offset);
  final low = data.getUint32(offset + 4);
  return high * 0x100000000 + low;
}

String _Abbreviation(Uint8List chars, int index) {
  if (index >= chars.length) {
    return '';
  }
  var end = chars.indexOf(0, index);
  if (end < 0) {
    end = chars.length;
  }
  return ascii.decode(Uint8List.sublistView(chars, index, end), allowInvalid: true);
}

/// The first and last seconds of NodaTime's Instant range.
int get _MinInstantSeconds => Instant.MinValue.ToUnixTimeSeconds();
int get _MaxInstantSeconds => Instant.MaxValue.ToUnixTimeSeconds();

/// The zone interval map of the zone [id] from TZif data, named by abbreviation; the footer applies after the last
/// transition, and DST savings are inferred (see below). Throws a [FormatException] if the data is malformed or
/// can't be represented.
@internal
IZoneIntervalMap CreateTzifZoneIntervalMap(String id, Uint8List bytes) {
  final data = ParseTzif(bytes);
  _PosixTimeZone? tail;
  final footer = data.Footer;
  if (footer != null && footer.isNotEmpty) {
    tail = _PosixTimeZone.Parse(footer);
    if (tail == null) {
      throw FormatException('Bad TZif footer', footer);
    }
  }

  // Transitions outside Instant's range are ignored (zic may emit one at -2**59 for the "big bang").
  final minTransitionSeconds = _MinInstantSeconds + 86400;
  final maxTransitionSeconds = _MaxInstantSeconds - 86400;

  // The time type before the first (usable) transition is type 0.
  var initialType = 0;
  final times = <int>[];
  final types = <int>[];
  for (var i = 0; i < data.TransitionTimes.length; i++) {
    final time = data.TransitionTimes[i];
    if (time < minTransitionSeconds) {
      initialType = data.TransitionTypes[i];
      continue;
    }
    if (time > maxTransitionSeconds) {
      break;
    }
    if (times.isNotEmpty && time <= times.last) {
      throw const FormatException('TZif transitions are not in order');
    }
    times.add(time);
    types.add(data.TransitionTypes[i]);
  }

  if (times.isEmpty && tail != null) {
    // No transitions: the TZ string applies to all of time.
    return tail.ToZoneIntervalMap();
  }

  final typeSequence = [initialType, ...types];
  final localTimeTypes = data.LocalTimeTypes;

  // The next standard offset after typeSequence[index] (or failing that the footer's), or null.
  int? nextStandardFrom(int index) {
    for (var j = index + 1; j < typeSequence.length; j++) {
      final type = localTimeTypes[typeSequence[j]];
      if (!type.IsDst) {
        return type.UtOffset;
      }
    }
    return tail?.StandardOffset;
  }

  // Savings: zero for standard time; for DST, the offset minus the most recent (else next) standard offset. If that's
  // zero or beyond ±3 hours (Argentina 1999, Pacific/Apia 2011), the next standard offset, else one hour (as
  // BclDateTimeZone's DaylightFakingZoneIntervalMap assumes).
  bool plausible(int savings) => savings != 0 && savings.abs() <= 3 * 3600;
  final savingsList = <int>[];
  int? lastStandard;
  for (var i = 0; i < typeSequence.length; i++) {
    final type = localTimeTypes[typeSequence[i]];
    if (!type.IsDst) {
      lastStandard = type.UtOffset;
      savingsList.add(0);
      continue;
    }
    final candidates = [lastStandard, nextStandardFrom(i)];
    var savings = 3600;
    for (final standard in candidates) {
      if (standard != null && plausible(type.UtOffset - standard)) {
        savings = type.UtOffset - standard;
        break;
      }
    }
    savingsList.add(savings);
  }

  // Build the intervals. With a tail, the last transition starts the tail.
  final intervalCount = tail != null ? times.length : times.length + 1;
  final periods = <ZoneInterval>[];
  for (var i = 0; i < intervalCount; i++) {
    final type = localTimeTypes[typeSequence[i]];
    final start = i == 0 ? Instant.BeforeMinValue : Instant.FromUnixTimeSeconds(times[i - 1]);
    final end = i < times.length ? Instant.FromUnixTimeSeconds(times[i]) : Instant.AfterMaxValue;
    final wallOffset = _Offset(type.UtOffset);
    final savings = _Offset(savingsList[i]);
    if (periods.isNotEmpty) {
      final previous = periods.last;
      if (previous.Name == type.Abbreviation && previous.WallOffset == wallOffset && previous.Savings == savings) {
        // Not a real transition: extend the previous interval.
        periods[periods.length - 1] = previous.WithEnd(end);
        continue;
      }
    }
    periods.add(ZoneInterval.NewNameStartEndWallOffsetSavings(type.Abbreviation, start, end, wallOffset, savings));
  }

  // Drop trailing intervals that the TZ string describes identically, so the tail starts at the last real transition.
  // "Fat" TZif files (e.g. Ubuntu's) end with a no-op transition at 2038-01-19T03:14:07Z for 32-bit readers.
  final tailMap = tail?.ToZoneIntervalMap();
  if (tailMap != null) {
    while (periods.length > 1) {
      final last = periods.last;
      final fromTail = tailMap.GetZoneInterval(last.RawStart);
      // Only if the TZ string gives the same interval for all of it.
      if (fromTail.Name != last.Name ||
          fromTail.WallOffset != last.WallOffset ||
          fromTail.Savings != last.Savings ||
          fromTail.RawEnd < last.RawEnd) {
        break;
      }
      periods.removeLast();
    }
  }

  if (tailMap == null && periods.length == 1) {
    return SingleZoneIntervalMap.NewInterval(periods.single);
  }
  // noda_dart: @visibleForTesting (internal in NodaTime).
  return PrecalculatedDateTimeZone.NewIdIntervalsTailZone(id, periods, tailMap);
}

Offset _Offset(int seconds) {
  if (seconds < Offset.MinValue.Seconds || seconds > Offset.MaxValue.Seconds) {
    throw FormatException('Offset out of range: $seconds seconds');
  }
  return Offset.FromSeconds(seconds);
}

// #region POSIX TZ strings

/// The kinds of date in a POSIX TZ rule.
enum _PosixDateKind {
  /// `Jn`: day n (1-365) of the year, never counting February 29th.
  Julian,

  /// `n`: zero-based day n (0-365) of the year, counting February 29th.
  ZeroBased,

  /// `Mm.w.d`: day d (0 = Sunday) of week w (1-5, 5 = last) of month m.
  MonthWeekDay,
}

/// A transition date and time in a POSIX TZ rule.
final class _PosixTransition {
  final _PosixDateKind Kind;

  /// The day for [_PosixDateKind.Julian] and [_PosixDateKind.ZeroBased].
  final int Day;
  final int Month;
  final int Week;
  final int DayOfWeek;

  /// The local time of day, in seconds (-167 to 167 hours in version 3).
  final int TimeOfDay;

  const _PosixTransition.Julian(this.Day, this.TimeOfDay)
      : Kind = _PosixDateKind.Julian,
        Month = 0,
        Week = 0,
        DayOfWeek = 0;

  const _PosixTransition.ZeroBased(this.Day, this.TimeOfDay)
      : Kind = _PosixDateKind.ZeroBased,
        Month = 0,
        Week = 0,
        DayOfWeek = 0;

  const _PosixTransition.MonthWeekDay(this.Month, this.Week, this.DayOfWeek, this.TimeOfDay)
      : Kind = _PosixDateKind.MonthWeekDay,
        Day = 0;

  /// The local date and time of this transition in [year], in seconds since the epoch as if local time were UTC.
  int LocalSecondsInYear(int year) {
    int epochDay;
    switch (Kind) {
      case _PosixDateKind.Julian:
        var dayOfYear = Day;
        if (_IsLeapYear(year) && Day >= 60) {
          dayOfYear++;
        }
        epochDay = _DaysFromCivil(year, 1, 1) + dayOfYear - 1;
        break;
      case _PosixDateKind.ZeroBased:
        epochDay = _DaysFromCivil(year, 1, 1) + Day;
        break;
      case _PosixDateKind.MonthWeekDay:
        final first = _DaysFromCivil(year, Month, 1);
        // 1970-01-01 was a Thursday (4).
        final firstDayOfWeek = (first + 4) % 7;
        epochDay = first + (DayOfWeek - firstDayOfWeek + 7) % 7 + (Week - 1) * 7;
        final nextMonth = Month == 12 ? _DaysFromCivil(year + 1, 1, 1) : _DaysFromCivil(year, Month + 1, 1);
        while (epochDay >= nextMonth) {
          epochDay -= 7;
        }
        break;
    }
    return epochDay * 86400 + TimeOfDay;
  }
}

/// A POSIX TZ string (`EST5EDT,M3.2.0,M11.1.0`) with tzfile(5)'s extensions (`<+0330>-3:30`, times to ±167 hours).
/// Offsets are UT offsets (east positive), the negation of POSIX's.
final class _PosixTimeZone {
  final String StandardName;

  /// The standard time UT offset in seconds.
  final int StandardOffset;

  /// Null if there's no daylight saving time.
  final String? DaylightName;

  /// The daylight time UT offset in seconds; null without DST.
  final int? DaylightOffset;

  /// When daylight saving time starts (local standard time); null without DST.
  final _PosixTransition? Start;

  /// When daylight saving time ends (local daylight time); null without DST.
  final _PosixTransition? End;

  const _PosixTimeZone(this.StandardName, this.StandardOffset,
      [this.DaylightName, this.DaylightOffset, this.Start, this.End]);

  bool get HasDaylightSavingTime => DaylightName != null;

  /// Parses a POSIX TZ string, returning null if it's not valid.
  static _PosixTimeZone? Parse(String text) => _PosixParser(text).Parse();

  /// The UTC instant (seconds) at which DST starts in [year].
  int StartSeconds(int year) => Start!.LocalSecondsInYear(year) - StandardOffset;

  /// The UTC instant (seconds) at which DST ends in [year].
  int EndSeconds(int year) => End!.LocalSecondsInYear(year) - DaylightOffset!;

  /// A map for all of time following this rule.
  IZoneIntervalMap ToZoneIntervalMap() {
    if (!HasDaylightSavingTime) {
      return _FixedMap(false);
    }
    // tzfile(5): DST is in effect all year if it starts January 1 at 00:00 and ends December 31 at 24:00 plus the DST
    // difference; that is, if DST ends exactly when it starts the following year. Check a leap and a non-leap year.
    if (EndSeconds(2023) == StartSeconds(2024) && EndSeconds(2024) == StartSeconds(2025)) {
      return _FixedMap(true);
    }
    if (StartSeconds(2023) == EndSeconds(2023) && StartSeconds(2024) == EndSeconds(2024)) {
      return _FixedMap(false);
    }
    return _PosixRuleMap(this);
  }

  IZoneIntervalMap _FixedMap(bool daylight) {
    final interval = daylight
        ? ZoneInterval.NewNameStartEndWallOffsetSavings(DaylightName!, Instant.BeforeMinValue, Instant.AfterMaxValue,
            _Offset(DaylightOffset!), _Offset(DaylightOffset! - StandardOffset))
        : ZoneInterval.NewNameStartEndWallOffsetSavings(
            StandardName, Instant.BeforeMinValue, Instant.AfterMaxValue, _Offset(StandardOffset), Offset.Zero);
    return SingleZoneIntervalMap.NewInterval(interval);
  }
}

/// Alternating standard and daylight time by a POSIX TZ rule. Not a [StandardDaylightAlternatingMap], as
/// [ZoneYearOffset] can't represent zero-based days or version 3 times outside 00:00-24:00 (`M3.4.4/26`).
final class _PosixRuleMap implements IZoneIntervalMap {
  // The years of Instant; transitions outside its range are ignored.
  static const int _MinYear = -9998;
  static const int _MaxYear = 9999;

  final _PosixTimeZone _zone;
  final Offset _standardOffset;
  final Offset _daylightOffset;
  final Offset _savings;

  _PosixRuleMap(this._zone)
      : _standardOffset = _Offset(_zone.StandardOffset),
        _daylightOffset = _Offset(_zone.DaylightOffset!),
        _savings = _Offset(_zone.DaylightOffset! - _zone.StandardOffset);

  @override
  Offset get MinOffset => Offset.Min(_standardOffset, _daylightOffset);

  @override
  Offset get MaxOffset => Offset.Max(_standardOffset, _daylightOffset);

  @override
  ZoneInterval GetZoneInterval(Instant instant) {
    final minSeconds = _MinInstantSeconds;
    final maxSeconds = _MaxInstantSeconds;
    final year = _YearFromEpochDay(_FloorDiv(instant.ToUnixTimeSeconds(), 86400));
    for (var radius = 1; radius <= 3; radius++) {
      final transitions = <(Instant, bool)>[];
      for (var y = year - radius; y <= year + radius; y++) {
        if (y < _MinYear || y > _MaxYear) {
          continue;
        }
        for (final (seconds, daylight) in [(_zone.StartSeconds(y), true), (_zone.EndSeconds(y), false)]) {
          if (seconds >= minSeconds && seconds <= maxSeconds) {
            transitions.add((Instant.FromUnixTimeSeconds(seconds), daylight));
          }
        }
      }
      transitions.sort((a, b) => a.$1.compareTo(b.$1));

      // The last transition at or before the instant decides the state.
      var previousIndex = -1;
      for (var i = 0; i < transitions.length; i++) {
        if (transitions[i].$1 <= instant) {
          previousIndex = i;
        }
      }
      bool daylight;
      Instant? start;
      if (previousIndex >= 0) {
        daylight = transitions[previousIndex].$2;
        start = transitions[previousIndex].$1;
        // Skip back over transitions that don't change the state.
        for (var i = previousIndex - 1; i >= 0; i--) {
          if (transitions[i].$2 != daylight) {
            break;
          }
          start = transitions[i].$1;
        }
      } else if (transitions.isNotEmpty) {
        daylight = !transitions.first.$2;
      } else {
        daylight = false;
      }
      Instant? end;
      for (var i = previousIndex + 1; i < transitions.length; i++) {
        if (transitions[i].$2 != daylight) {
          end = transitions[i].$1;
          break;
        }
      }
      final atStartOfYears = year - radius <= _MinYear;
      final atEndOfYears = year + radius >= _MaxYear;
      if ((start != null || atStartOfYears) && (end != null || atEndOfYears)) {
        return daylight
            ? ZoneInterval.NewNameStartEndWallOffsetSavings(_zone.DaylightName!, start ?? Instant.BeforeMinValue,
                end ?? Instant.AfterMaxValue, _daylightOffset, _savings)
            : ZoneInterval.NewNameStartEndWallOffsetSavings(_zone.StandardName, start ?? Instant.BeforeMinValue,
                end ?? Instant.AfterMaxValue, _standardOffset, Offset.Zero);
      }
    }
    throw StateError('No transitions found for ${_zone.StandardName}');
  }
}

final class _PosixParser {
  final String _text;
  int _position = 0;

  _PosixParser(this._text);

  bool get _AtEnd => _position >= _text.length;

  String get _Current => _text[_position];

  _PosixTimeZone? Parse() {
    try {
      final standardName = _Name();
      final standardOffset = _OffsetValue();
      if (standardName == null || standardOffset == null) {
        return null;
      }
      if (_AtEnd) {
        return _PosixTimeZone(standardName, -standardOffset);
      }

      final daylightName = _Name();
      if (daylightName == null) {
        return null;
      }
      var daylightOffset = standardOffset - 3600;
      if (!_AtEnd && _Current != ',') {
        final parsed = _OffsetValue();
        if (parsed == null) {
          return null;
        }
        daylightOffset = parsed;
      }

      _PosixTransition? start;
      _PosixTransition? end;
      if (_AtEnd) {
        // tzfile(5): the default rule is the US one.
        start = const _PosixTransition.MonthWeekDay(3, 2, 0, 7200);
        end = const _PosixTransition.MonthWeekDay(11, 1, 0, 7200);
      } else {
        if (!_Consume(',')) {
          return null;
        }
        start = _Transition();
        if (start == null || !_Consume(',')) {
          return null;
        }
        end = _Transition();
        if (end == null || !_AtEnd) {
          return null;
        }
      }
      return _PosixTimeZone(standardName, -standardOffset, daylightName, -daylightOffset, start, end);
    } on FormatException {
      return null;
    }
  }

  bool _Consume(String char) {
    if (!_AtEnd && _Current == char) {
      _position++;
      return true;
    }
    return false;
  }

  String? _Name() {
    if (_Consume('<')) {
      final end = _text.indexOf('>', _position);
      if (end < 0) {
        return null;
      }
      final name = _text.substring(_position, end);
      _position = end + 1;
      return name.isEmpty ? null : name;
    }
    final start = _position;
    while (!_AtEnd && _IsAlpha(_Current.codeUnitAt(0))) {
      _position++;
    }
    return _position - start >= 1 ? _text.substring(start, _position) : null;
  }

  /// [+-]hh[:mm[:ss]] in seconds, or null.
  int? _OffsetValue() => _SignedHms(24);

  /// A transition time, [+-]hhh[:mm[:ss]] in seconds (-167 to 167 hours).
  int? _Time() => _SignedHms(167);

  int? _SignedHms(int maxHours) {
    var sign = 1;
    if (_Consume('-')) {
      sign = -1;
    } else {
      _Consume('+');
    }
    final hours = _Number(3);
    if (hours == null || hours > maxHours) {
      return null;
    }
    var seconds = hours * 3600;
    if (_Consume(':')) {
      final minutes = _Number(2);
      if (minutes == null || minutes > 59) {
        return null;
      }
      seconds += minutes * 60;
      if (_Consume(':')) {
        final secs = _Number(2);
        if (secs == null || secs > 59) {
          return null;
        }
        seconds += secs;
      }
    }
    return sign * seconds;
  }

  int? _Number(int maxDigits) {
    final start = _position;
    while (!_AtEnd && _position - start < maxDigits && _IsDigit(_Current.codeUnitAt(0))) {
      _position++;
    }
    if (_position == start) {
      return null;
    }
    return int.parse(_text.substring(start, _position));
  }

  _PosixTransition? _Transition() {
    var time = 7200;
    _PosixTransition Function(int time) make;
    if (_Consume('J')) {
      final day = _Number(3);
      if (day == null || day < 1 || day > 365) {
        return null;
      }
      make = (time) => _PosixTransition.Julian(day, time);
    } else if (_Consume('M')) {
      final month = _Number(2);
      if (month == null || month < 1 || month > 12 || !_Consume('.')) {
        return null;
      }
      final week = _Number(1);
      if (week == null || week < 1 || week > 5 || !_Consume('.')) {
        return null;
      }
      final dayOfWeek = _Number(1);
      if (dayOfWeek == null || dayOfWeek > 6) {
        return null;
      }
      make = (time) => _PosixTransition.MonthWeekDay(month, week, dayOfWeek, time);
    } else {
      final day = _Number(3);
      if (day == null || day > 365) {
        return null;
      }
      make = (time) => _PosixTransition.ZeroBased(day, time);
    }
    if (_Consume('/')) {
      final parsed = _Time();
      if (parsed == null) {
        return null;
      }
      time = parsed;
    }
    return make(time);
  }

  static bool _IsAlpha(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122);

  static bool _IsDigit(int c) => c >= 48 && c <= 57;
}

// #endregion

// #region Proleptic Gregorian calendar arithmetic (Howard Hinnant's algorithms), valid for any year

int _FloorDiv(int a, int b) => (a - a % b) ~/ b;

bool _IsLeapYear(int year) => year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

int _DaysFromCivil(int year, int month, int day) {
  final y = month <= 2 ? year - 1 : year;
  final era = _FloorDiv(y, 400);
  final yearOfEra = y - era * 400;
  final dayOfYear = (153 * (month > 2 ? month - 3 : month + 9) + 2) ~/ 5 + day - 1;
  final dayOfEra = yearOfEra * 365 + yearOfEra ~/ 4 - yearOfEra ~/ 100 + dayOfYear;
  return era * 146097 + dayOfEra - 719468;
}

int _YearFromEpochDay(int epochDay) {
  final z = epochDay + 719468;
  final era = _FloorDiv(z, 146097);
  final dayOfEra = z - era * 146097;
  final yearOfEra = (dayOfEra - dayOfEra ~/ 1460 + dayOfEra ~/ 36524 - dayOfEra ~/ 146096) ~/ 365;
  final dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra ~/ 4 - yearOfEra ~/ 100);
  final mp = (5 * dayOfYear + 2) ~/ 153;
  final month = mp < 10 ? mp + 3 : mp - 9;
  return yearOfEra + era * 400 + (month <= 2 ? 1 : 0);
}

// #endregion
