// noda_dart: new code. Decodes the scenarios' encoded values (port of noda-js's ts/test/helpers/decode.ts).

import 'package:noda_dart/src/Bcl/CldrWindowsZones.dart';
import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/Era.dart';
import 'package:noda_dart/src/Calendars/IslamicEpoch.generated.dart';
import 'package:noda_dart/src/Calendars/IslamicLeapYearPattern.generated.dart';
import 'package:noda_dart/src/Calendars/YearMonthDayCalculator.dart';
import 'package:noda_dart/src/DateInterval.dart';
import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/AnnualDate.dart';
import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:noda_dart/src/IDateTimeZoneProvider.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/Interval.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/PeriodBuilder.dart';
import 'package:noda_dart/src/Text/DurationPattern.dart';
import 'package:noda_dart/src/Text/InstantPattern.dart';
import 'package:noda_dart/src/Text/LocalDatePattern.dart';
import 'package:noda_dart/src/Text/LocalDateTimePattern.dart';
import 'package:noda_dart/src/Text/LocalTimePattern.dart';
import 'package:noda_dart/src/Text/OffsetDatePattern.dart';
import 'package:noda_dart/src/Text/OffsetDateTimePattern.dart';
import 'package:noda_dart/src/Text/OffsetTimePattern.dart';
import 'package:noda_dart/src/Text/PeriodPattern.dart';
import 'package:noda_dart/src/Text/ZonedDateTimePattern.dart';
import 'package:noda_dart/src/TimeZones/Delegates.dart';
import 'package:noda_dart/src/TimeZones/PrecalculatedDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/Resolvers.dart';
import 'package:noda_dart/src/TimeZones/ZoneInterval.dart';
import 'package:noda_dart/src/YearMonth.dart';
import 'package:noda_dart/src/ZonedDateTime.dart';

import '../scenarios/types.dart';
import 'NamedWrapper.dart';

/// A value noda_dart can't represent; the harness skips the case.
final class UnsupportedValue implements Exception {
  final String message;

  UnsupportedValue(this.message);

  @override
  String toString() => 'UnsupportedValue: $message';
}

/// Test-assembly statics ("ZonedDateTimePatternTest.TestProvider"), registered by ported tests before `port()`.
final Map<String, Object? Function()> testStatics = {};

/// Zones defined by test classes, by ID (zone equality is by reference).
final Map<String, DateTimeZone> testZones = {};
final Map<String, DateTimeZone> _customZoneCache = {};

IDateTimeZoneProvider get tzdbProvider => DateTimeZoneProviders.Tzdb;

WindowsIdDateTimeZoneProvider? _windowsIdProvider;

/// For `provider: bcl` zones: Windows IDs mapped to tzdb by CLDR.
WindowsIdDateTimeZoneProvider windowsProvider() => _windowsIdProvider ??= WindowsIdDateTimeZoneProvider(tzdbProvider);

final Map<String, NodaCultureInfo> _cultureCache = {};

/// Set by `port(..., cultures: scenarioCultures)`; only fixtures that need it import that (large) file.
Map<String, CultureData>? scenarioCultureData;

NodaCultureInfo scenarioCulture(String key) {
  var culture = _cultureCache[key];
  if (culture == null) {
    if (key == 'Cultures.Invariant' || key == '') {
      culture = NodaCultureInfo.InvariantCulture;
    } else {
      final cultures = scenarioCultureData;
      if (cultures == null) {
        throw StateError('The culture $key needs the scenario culture data: import '
            "'../scenarios/cultures.generated.dart' (with the right number of ../) and pass "
            '`cultures: scenarioCultures` to port()');
      }
      final data = cultures[key];
      if (data == null) {
        throw UnsupportedValue('No data for culture $key');
      }
      culture = NodaCultureInfo.FromData(data);
    }
    _cultureCache[key] = culture;
  }
  return culture;
}

Object? decode(EncodedValue value) {
  if (value is List<Object?>) {
    return value.map(decode).toList();
  }
  if (value is Map<String, Object?>) {
    return _decodeObject(value);
  }
  return value;
}

Object? decodeExpected(EncodedValue value) => decode(value);

int _int(Object? value) => value as int;

Object? _decodeObject(EncodedObject v) {
  final tag = v[r'$'] as String;
  switch (tag) {
    case 'LocalDate':
      return _date(v);
    case 'LocalTime':
      return _time(v);
    case 'LocalDateTime':
      return _date(v).At(_time(v));
    case 'Instant':
      return _instant(v);
    case 'Duration':
      return _duration(_int(v['days']), _int(v['nanoOfDay']));
    case 'Offset':
      return Offset.FromSeconds(_int(v['seconds']));
    case 'OffsetDateTime':
      return _date(v).At(_time(v)).WithOffset(Offset.FromSeconds(_int(v['offsetSeconds'])));
    case 'OffsetDate':
      return _date(v).WithOffset(Offset.FromSeconds(_int(v['offsetSeconds'])));
    case 'OffsetTime':
      return _time(v).WithOffset(Offset.FromSeconds(_int(v['offsetSeconds'])));
    case 'ZonedDateTime':
      final local = _date(v).At(_time(v));
      // InZone gives the ISO calendar, so pass the value's own.
      return local
          .WithOffset(Offset.FromSeconds(_int(v['offsetSeconds'])))
          .ToInstant()
          .InZone(_zone(v['zone'] as EncodedObject), local.Calendar);
    case 'YearMonth':
      return YearMonth(_int(v['year']), _int(v['month']), _calendar(v['calendar'] as String?));
    case 'AnnualDate':
      return AnnualDate(_int(v['month']), _int(v['day']));
    case 'Period':
      final builder = PeriodBuilder();
      int? unit(String name) => v.containsKey(name) ? decode(v[name]) as int : null;
      builder.Years = unit('years') ?? 0;
      builder.Months = unit('months') ?? 0;
      builder.Weeks = unit('weeks') ?? 0;
      builder.Days = unit('days') ?? 0;
      builder.Hours = unit('hours') ?? 0;
      builder.Minutes = unit('minutes') ?? 0;
      builder.Seconds = unit('seconds') ?? 0;
      builder.Milliseconds = unit('milliseconds') ?? 0;
      builder.Ticks = unit('ticks') ?? 0;
      builder.Nanoseconds = unit('nanoseconds') ?? 0;
      return builder.Build();
    case 'Interval':
      return Interval(
        v['start'] == null ? null : _instant(v['start'] as EncodedObject),
        v['end'] == null ? null : _instant(v['end'] as EncodedObject),
      );
    case 'DateInterval':
      return DateInterval(decode(v['start']) as LocalDate, decode(v['end']) as LocalDate);
    case 'CalendarSystem':
      return _calendar(v['id'] as String?);
    case 'Era':
      return _era(v['name'] as String);
    case 'DateTimeZone':
      return _zone(v);
    case 'ZoneInterval':
      return _zoneInterval(v);
    case 'CultureInfo':
      return scenarioCulture((v['key'] ?? v['name']) as String);
    case 'enum':
      return v['value'];
    case 'Type':
      return v['name'];
    case 'Tuple':
      return (v['items'] as List<Object?>).map(decode).toList();
    case 'KeyValuePair':
      return MapEntry<Object?, Object?>(decode(v['key']), decode(v['value']));
    case 'Static':
      return _staticReference(v['ref'] as String);
    case 'Pattern':
      return _pattern(v);
    case 'NamedWrapper':
      return _namedWrapper(v);
    case 'Delegate' when v['method'] == 'Resolvers.CreateMappingResolver':
      final args = (v['args']! as List<Object?>).map(decode).toList();
      return Resolvers.CreateMappingResolver(args[0]! as AmbiguousTimeResolver, args[1]! as SkippedTimeResolver);
    case 'Bcl':
    case 'Delegate':
    case 'decimal':
    case 'Unsupported':
      final type = v['type'] ?? v['method'];
      throw UnsupportedValue('$tag value${type != null ? ' ($type)' : ''} isn\'t supported by noda_dart');
    default:
      return <String, Object?>{
        for (final entry in v.entries) entry.key: entry.key == r'$' ? entry.value : decode(entry.value),
      };
  }
}

NamedWrapper<Object?> _namedWrapper(EncodedObject v) {
  final name = v['name'] as String;
  final value = v['value'];
  if (value is Map<String, Object?>) {
    // By property name: "AM" is both AnnoMartyrum and AnnoMundi.
    if (value[r'$'] == 'Era') {
      final era = _erasByProperty[name];
      if (era == null || era.Name != value['name']) {
        throw UnsupportedValue('Era $name isn\'t available in noda_dart');
      }
      return NamedWrapper<Era>(era, name);
    }
    // Calculators are internal (encoded as Unsupported): the name identifies the calendar.
    if (value[r'$'] == 'Unsupported' &&
        RegExp(r'^NodaTime\.Calendars\.\w+YearMonthDayCalculator(\+\w+)?$').hasMatch(value['type'] as String)) {
      return NamedWrapper<YearMonthDayCalculator>(_calculatorCalendar(name).YearMonthDayCalculator, name);
    }
  }
  return NamedWrapper<Object?>(decode(value), name);
}

final Map<String, Era> _erasByProperty = {
  'Common': Era.Common,
  'BeforeCommon': Era.BeforeCommon,
  'AnnoMartyrum': Era.AnnoMartyrum,
  'AnnoHegirae': Era.AnnoHegirae,
  'AnnoMundi': Era.AnnoMundi,
  'AnnoPersico': Era.AnnoPersico,
  'Bahai': Era.Bahai,
};

/// "Gregorian", a CalendarSystem property name, or `Islamic;<epoch>;<leap year pattern>`.
CalendarSystem _calculatorCalendar(String name) {
  final islamic = RegExp(r'^Islamic;(\w+);(\w+)$').firstMatch(name);
  if (islamic != null) {
    final epoch = switch (islamic[1]) {
      'Astronomical' => IslamicEpoch.Astronomical,
      'Civil' => IslamicEpoch.Civil,
      _ => throw UnsupportedValue('Unknown Islamic epoch in $name'),
    };
    final pattern = switch (islamic[2]) {
      'Base15' => IslamicLeapYearPattern.Base15,
      'Base16' => IslamicLeapYearPattern.Base16,
      'Indian' => IslamicLeapYearPattern.Indian,
      'HabashAlHasib' => IslamicLeapYearPattern.HabashAlHasib,
      _ => throw UnsupportedValue('Unknown Islamic leap year pattern in $name'),
    };
    return CalendarSystem.GetIslamicCalendar(pattern, epoch);
  }
  return switch (name.replaceAll(RegExp(r'\)$'), '')) {
    'Gregorian' || 'Iso' => CalendarSystem.Iso,
    'Julian' => CalendarSystem.Julian,
    'Coptic' => CalendarSystem.Coptic,
    'Badi' => CalendarSystem.Badi,
    'IslamicBcl' => CalendarSystem.IslamicBcl,
    'PersianSimple' => CalendarSystem.PersianSimple,
    'PersianArithmetic' => CalendarSystem.PersianArithmetic,
    'PersianAstronomical' => CalendarSystem.PersianAstronomical,
    'HebrewCivil' => CalendarSystem.HebrewCivil,
    'HebrewScriptural' => CalendarSystem.HebrewScriptural,
    'UmAlQura' => CalendarSystem.UmAlQura,
    _ => throw UnsupportedValue('No calendar system for the calculator $name'),
  };
}

CalendarSystem _calendar(String? id) {
  if (id == null) {
    return CalendarSystem.Iso;
  }
  if (!CalendarSystem.Ids.contains(id)) {
    throw UnsupportedValue('Calendar $id isn\'t supported by noda_dart');
  }
  return CalendarSystem.ForId(id);
}

LocalDate _date(EncodedObject v) =>
    LocalDate(_int(v['year']), _int(v['month']), _int(v['day']), _calendar(v['calendar'] as String?));

LocalTime _time(EncodedObject v) => LocalTime.FromHourMinuteSecondNanosecond(
    _int(v['hour']), _int(v['minute']), _int(v['second']), _int(v['nanosecond']));

Era _era(String name) {
  switch (name) {
    case 'CE':
      return Era.Common;
    case 'BCE':
      return Era.BeforeCommon;
    default:
      throw UnsupportedValue(
          'Era $name can\'t be decoded from its name alone (only CE and BCE; other eras are decoded from NamedWrapper<Era>)');
  }
}

Duration _duration(int days, int nanoOfDay) => Duration.FromDays(days).Plus(Duration.FromNanoseconds(nanoOfDay));

Instant _instant(EncodedObject v) {
  if (v['iso'] == 'StartOfTime') {
    return Instant.BeforeMinValue;
  }
  if (v['iso'] == 'EndOfTime') {
    return Instant.AfterMaxValue;
  }
  return NodaConstants.UnixEpoch.Plus(_duration(_int(v['days']), _int(v['nanoOfDay'])));
}

ZoneInterval _zoneInterval(EncodedObject v) => ZoneInterval(
      v['name'] as String,
      v['start'] == null ? null : _instant(v['start'] as EncodedObject),
      v['end'] == null ? null : _instant(v['end'] as EncodedObject),
      Offset.FromSeconds(_int(v['wallOffsetSeconds'])),
      Offset.FromSeconds(_int(v['savingsSeconds'])),
    );

DateTimeZone _zone(EncodedObject v) {
  final id = v['id'] as String;
  switch (v['provider']) {
    case 'fixed':
      return id == 'UTC' ? DateTimeZone.Utc : DateTimeZone.ForOffset(Offset.FromSeconds(_int(v['offsetSeconds'])));
    case 'tzdb':
      return tzdbProvider.GetZoneOrNull(id) ?? (throw UnsupportedValue('Unknown tzdb zone $id'));
    case 'bcl':
      return windowsProvider().GetZoneOrNull(id) ?? (throw UnsupportedValue('No tzdb zone for Windows zone $id'));
    default:
      final registered = testZones[id];
      if (registered != null) {
        return registered;
      }
      // Same encoding → same instance (zone equality is by reference).
      final key = _render(v);
      return _customZoneCache[key] ??= PrecalculatedDateTimeZone.NewIdIntervalsTailZone(
          id, (v['intervals'] as List<Object?>).map((i) => _zoneInterval(i as EncodedObject)).toList(), null);
  }
}

/// NodaTime statics the scenarios refer to (no reflection in Dart).
final Map<String, Object? Function()> _nodaStatics = {
  'DateTimeZoneProviders.Tzdb': () => tzdbProvider,
  'Resolvers.StrictResolver': () => Resolvers.StrictResolver,
  'Resolvers.LenientResolver': () => Resolvers.LenientResolver,
  'Resolvers.ReturnEarlier': () => Resolvers.ReturnEarlier,
  'Resolvers.ReturnLater': () => Resolvers.ReturnLater,
  'Resolvers.ThrowWhenAmbiguous': () => Resolvers.ThrowWhenAmbiguous,
  'Resolvers.ReturnEndOfIntervalBefore': () => Resolvers.ReturnEndOfIntervalBefore,
  'Resolvers.ReturnStartOfIntervalAfter': () => Resolvers.ReturnStartOfIntervalAfter,
  'Resolvers.ReturnForwardShifted': () => Resolvers.ReturnForwardShifted,
  'Resolvers.ThrowWhenSkipped': () => Resolvers.ThrowWhenSkipped,
  'PeriodPattern.Roundtrip': () => PeriodPattern.Roundtrip,
  'PeriodPattern.NormalizingIso': () => PeriodPattern.NormalizingIso,
  'DurationPattern.Roundtrip': () => DurationPattern.Roundtrip,
  'DurationPattern.JsonRoundtrip': () => DurationPattern.JsonRoundtrip,
  'InstantPattern.General': () => InstantPattern.General,
  'InstantPattern.ExtendedIso': () => InstantPattern.ExtendedIso,
  'LocalDatePattern.Iso': () => LocalDatePattern.Iso,
  'LocalDatePattern.FullRoundtrip': () => LocalDatePattern.FullRoundtrip,
  'LocalTimePattern.ExtendedIso': () => LocalTimePattern.ExtendedIso,
  'LocalTimePattern.LongExtendedIso': () => LocalTimePattern.LongExtendedIso,
  'LocalTimePattern.GeneralIso': () => LocalTimePattern.GeneralIso,
  'LocalDateTimePattern.GeneralIso': () => LocalDateTimePattern.GeneralIso,
  'LocalDateTimePattern.ExtendedIso': () => LocalDateTimePattern.ExtendedIso,
  'LocalDateTimePattern.BclRoundtrip': () => LocalDateTimePattern.BclRoundtrip,
  'LocalDateTimePattern.FullRoundtripWithoutCalendar': () => LocalDateTimePattern.FullRoundtripWithoutCalendar,
  'LocalDateTimePattern.FullRoundtrip': () => LocalDateTimePattern.FullRoundtrip,
  'OffsetDatePattern.GeneralIso': () => OffsetDatePattern.GeneralIso,
  'OffsetDatePattern.FullRoundtrip': () => OffsetDatePattern.FullRoundtrip,
  'OffsetTimePattern.GeneralIso': () => OffsetTimePattern.GeneralIso,
  'OffsetTimePattern.ExtendedIso': () => OffsetTimePattern.ExtendedIso,
  'OffsetTimePattern.Rfc3339': () => OffsetTimePattern.Rfc3339,
  'OffsetDateTimePattern.GeneralIso': () => OffsetDateTimePattern.GeneralIso,
  'OffsetDateTimePattern.ExtendedIso': () => OffsetDateTimePattern.ExtendedIso,
  'OffsetDateTimePattern.Rfc3339': () => OffsetDateTimePattern.Rfc3339,
  'OffsetDateTimePattern.FullRoundtrip': () => OffsetDateTimePattern.FullRoundtrip,
  'ZonedDateTimePattern.GeneralFormatOnlyIso': () => ZonedDateTimePattern.GeneralFormatOnlyIso,
  'ZonedDateTimePattern.ExtendedFormatOnlyIso': () => ZonedDateTimePattern.ExtendedFormatOnlyIso,
};

Object? _staticReference(String ref) {
  final registered = testStatics[ref] ?? _nodaStatics[ref];
  if (registered == null) {
    throw UnsupportedValue('Static reference $ref isn\'t available in noda_dart'
        '${ref.startsWith('BclCalendars.') ? ' (a BCL calendar)' : ' (register it in testStatics, or add it to Decode.dart)'}');
  }
  return registered();
}

Object? _pattern(EncodedObject v) {
  final culture = v['culture'] == null ? NodaCultureInfo.InvariantCulture : decode(v['culture']) as NodaCultureInfo;
  switch (v['type']) {
    case 'ZonedDateTimePattern':
      return ZonedDateTimePattern.Create(
        v['patternText'] as String,
        culture,
        decode(v['resolver']) as ZoneLocalMappingResolver?,
        decode(v['zoneProvider']) as IDateTimeZoneProvider?,
        decode(v['templateValue']) as ZonedDateTime,
      );
    default:
      throw UnsupportedValue('Pattern type ${v['type']} isn\'t decoded yet (add it to Decode.dart)');
  }
}

/// A short JSON-like text for a value (test names, cache keys), as noda-js names its cases.
String render(EncodedValue value) => _render(value, short: true);

String _render(Object? value, {bool short = false}) {
  if (value == null) {
    return 'null';
  }
  if (value is String) {
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n')}"';
  }
  if (value is BigInt) {
    return '${value}n';
  }
  if (value is List<Object?>) {
    return '[${value.map((v) => _render(v, short: short)).join(',')}]';
  }
  if (value is Map<Object?, Object?>) {
    final tag = value[r'$'];
    if (short) {
      switch (tag) {
        case 'enum':
          return '${value['type']}.${value['name']}';
        case 'CultureInfo':
          return '${value['key']}';
        case 'LocalDate' when value.length <= 5:
          return '${value['year']}-${value['month']}-${value['day']}${value['calendar'] != null ? ' ${value['calendar']}' : ''}';
        case 'DateTimeZone':
          return '${value['id']}';
        case String _ when tag.endsWith('.Data'):
          return '$tag{${value.entries.where((e) => e.key != r'$' && e.key != 'template' && !(e.key == 'culture' && (e.value as Map<Object?, Object?>)['key'] == 'Cultures.Invariant')).map((e) => '${e.key}:${_render(e.value, short: short)}').join(',')}}';
      }
    }
    return '{${value.entries.map((e) => '"${e.key}":${_render(e.value, short: short)}').join(',')}}';
  }
  return '$value';
}
