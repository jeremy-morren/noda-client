// noda_dart: new code. Port of noda-js's ts/test/golden/json.test.ts: NodaTime.Serialization.SystemTextJson's output,
// read with fromJson and written with toJson, in every calendar.

import 'dart:convert';

import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/testing.dart';
import 'package:noda_dart/tzdb_bundled.dart' as tzdb_bundled;
import 'package:noda_dart/windows.dart';
import 'package:test/test.dart';

import '../helpers/Assertions.dart';
import '../helpers/Decode.dart';
import 'types.dart';
import 'json/badi.generated.dart' as json_badi;
import 'json/coptic.generated.dart' as json_coptic;
import 'json/gregorian.generated.dart' as json_gregorian;
import 'json/hebrew-civil.generated.dart' as json_hebrew_civil;
import 'json/hebrew-scriptural.generated.dart' as json_hebrew_scriptural;
import 'json/hijri-astronomical-base15.generated.dart' as json_hijri_astronomical_base15;
import 'json/hijri-astronomical-base16.generated.dart' as json_hijri_astronomical_base16;
import 'json/hijri-astronomical-habashalhasib.generated.dart' as json_hijri_astronomical_habashalhasib;
import 'json/hijri-astronomical-indian.generated.dart' as json_hijri_astronomical_indian;
import 'json/hijri-civil-base15.generated.dart' as json_hijri_civil_base15;
import 'json/hijri-civil-base16.generated.dart' as json_hijri_civil_base16;
import 'json/hijri-civil-habashalhasib.generated.dart' as json_hijri_civil_habashalhasib;
import 'json/hijri-civil-indian.generated.dart' as json_hijri_civil_indian;
import 'json/iso.generated.dart' as json_iso;
import 'json/julian.generated.dart' as json_julian;
import 'json/persian-algorithmic.generated.dart' as json_persian_algorithmic;
import 'json/persian-arithmetic.generated.dart' as json_persian_arithmetic;
import 'json/persian-simple.generated.dart' as json_persian_simple;
import 'json/um-al-qura.generated.dart' as json_um_al_qura;

const List<JsonGolden> jsonGoldens = [
  json_badi.golden,
  json_coptic.golden,
  json_gregorian.golden,
  json_hebrew_civil.golden,
  json_hebrew_scriptural.golden,
  json_hijri_astronomical_base15.golden,
  json_hijri_astronomical_base16.golden,
  json_hijri_astronomical_habashalhasib.golden,
  json_hijri_astronomical_indian.golden,
  json_hijri_civil_base15.golden,
  json_hijri_civil_base16.golden,
  json_hijri_civil_habashalhasib.golden,
  json_hijri_civil_indian.golden,
  json_iso.golden,
  json_julian.golden,
  json_persian_algorithmic.golden,
  json_persian_arithmetic.golden,
  json_persian_simple.golden,
  json_um_al_qura.golden,
];

final Map<String, Object Function(Object? json, CalendarSystem calendar)> withCalendar = {
  'LocalDate': (json, calendar) => LocalDate.fromJson(json as String, calendar),
  'LocalDateTime': (json, calendar) => LocalDateTime.fromJson(json as String, calendar),
  'OffsetDate': (json, calendar) => OffsetDate.fromJson(json as String, calendar),
  'OffsetDateTime': (json, calendar) => OffsetDateTime.fromJson(json as String, calendar),
  'YearMonth': (json, calendar) => YearMonth.fromJson(json as String, calendar),
  'DateInterval': (json, calendar) => DateInterval.fromJson(json as Map<String, Object?>, calendar),
};

final Map<String, Object Function(Object? json)> fromJson = {
  'AnnualDate': (json) => AnnualDate.fromJson(json as String),
  'DateInterval': (json) => DateInterval.fromJson(json as Map<String, Object?>),
  'Duration': (json) => Duration.fromJson(json as String),
  'Instant': (json) => Instant.fromJson(json as String),
  'Interval': (json) => Interval.fromJson(json as Map<String, Object?>),
  'LocalDate': (json) => LocalDate.fromJson(json as String),
  'LocalDateTime': (json) => LocalDateTime.fromJson(json as String),
  'LocalTime': (json) => LocalTime.fromJson(json as String),
  'Offset': (json) => Offset.fromJson(json as String),
  'OffsetDate': (json) => OffsetDate.fromJson(json as String),
  'OffsetDateTime': (json) => OffsetDateTime.fromJson(json as String),
  'OffsetTime': (json) => OffsetTime.fromJson(json as String),
  'Period': (json) => Period.fromJson(json as String),
  'YearMonth': (json) => YearMonth.fromJson(json as String),
};

CalendarSystem calendarOf(Object value) => switch (value) {
      LocalDate v => v.Calendar,
      LocalDateTime v => v.Calendar,
      OffsetDate v => v.Calendar,
      OffsetDateTime v => v.Calendar,
      YearMonth v => v.Calendar,
      DateInterval v => v.Calendar,
      ZonedDateTime v => v.Calendar,
      _ => throw StateError('${value.runtimeType} has no calendar'),
    };

/// Property names lower-cased: Interval and DateInterval write camelCase, NodaTime PascalCase; both read either.
Object? caseInsensitive(Object? json) => json is Map<String, Object?>
    ? {for (final entry in json.entries) entry.key.toLowerCase(): caseInsensitive(entry.value)}
    : json;

void main() {
  test('covers every calendar system', () {
    expect(jsonGoldens.map((g) => g.calendar).toList()..sort(), CalendarSystem.Ids.toList()..sort());
  });

  for (final golden in jsonGoldens) {
    group('JSON [${golden.calendar}]', () {
      final calendar = CalendarSystem.ForId(golden.calendar);
      final isIso = identical(calendar, CalendarSystem.Iso);
      final json = jsonDecode(golden.json) as Map<String, Object?>;

      Object read(JsonGoldenProperty property, Object? value, CalendarSystem? calendar) {
        final IDateTimeZoneProvider provider = property.name.startsWith('Bcl') ? windowsProvider() : tzdbProvider;
        switch (property.type) {
          case 'ZonedDateTime':
            return ZonedDateTime.fromJson(value as String, provider, calendar);
          case 'DateTimeZone':
            return DateTimeZone.fromJson(value as String, provider);
        }
        if (calendar != null && withCalendar.containsKey(property.type)) {
          return withCalendar[property.type]!(value, calendar);
        }
        // ISO, or a type without a calendar: the one-argument fromJson.
        return fromJson[property.type]!(value);
      }

      test('has one property per value, in order', () {
        expect(json.keys.toList(), golden.properties.map((p) => p.name).toList());
      });

      for (final property in golden.properties) {
        final hasCalendar = withCalendar.containsKey(property.type) || property.type == 'ZonedDateTime';
        final how = hasCalendar ? (isIso ? ' with no calendar (ISO)' : ' with the ${golden.calendar} calendar') : '';
        test('${property.name}: ${property.type}.fromJson$how', () {
          final actual = read(property, json[property.name], isIso ? null : calendar);
          Assert.AreEqual(decode(property.value), actual);
          if (hasCalendar) {
            expect(identical(calendarOf(actual), calendar), isTrue, reason: '${calendarOf(actual)}');
          }
        });

        test('${property.name}: ${property.type}.toJson', () {
          final value = decode(property.value);
          final written = jsonDecode(jsonEncode(value));
          var expected = json[property.name];
          if (property.name.startsWith('Bcl')) {
            // windows.dart's zones keep their tzdb IDs (only lookup accepts the Windows form).
            final zone = value is ZonedDateTime ? value.Zone : value as DateTimeZone;
            final encoded = property.value as Map<String, Object?>;
            final windowsId = ((encoded['zone'] ?? encoded) as Map<String, Object?>)['id'] as String;
            expect(windowsProvider()[windowsId], same(zone));
            expected = (expected as String).replaceAll(windowsId, zone.Id);
          }
          if (property.type == 'Interval' || property.type == 'DateInterval') {
            expect(caseInsensitive(written), caseInsensitive(expected));
          } else {
            expect(written, expected);
          }
        });
      }
    });
  }

  group('JSON with the bundled tzdb provider (package:noda_dart/tzdb_bundled.dart)', () {
    final provider = tzdb_bundled.tzdb;
    final london = provider['Europe/London'];
    final value = Instant.FromUtc(2024, 3, 31, 14, 30, 15).PlusNanoseconds(123456789).InZone(london);

    test('ZonedDateTime round trip', () {
      expect(value.toJson(), '2024-03-31T15:30:15.123456789+01 Europe/London');
      final read = ZonedDateTime.fromJson(value.toJson(), provider);
      Assert.AreEqual(value, read);
      expect(identical(read.Zone, london), isTrue);
    });

    test('ZonedDateTime round trip in another calendar', () {
      final julian = value.WithCalendar(CalendarSystem.Julian);
      Assert.AreEqual(julian, ZonedDateTime.fromJson(julian.toJson(), provider, CalendarSystem.Julian));
    });

    test('DateTimeZone round trip', () {
      expect(jsonEncode(london), '"Europe/London"');
      expect(identical(DateTimeZone.fromJson(jsonDecode(jsonEncode(london)) as String, provider), london), isTrue);
    });

    test('fields of an object (as json_serializable and freezed write them)', () {
      final encoded = jsonEncode({'when': value, 'zone': london, 'instant': value.ToInstant()});
      final map = jsonDecode(encoded) as Map<String, Object?>;
      Assert.AreEqual(value, ZonedDateTime.fromJson(map['when'] as String, provider));
      expect(identical(DateTimeZone.fromJson(map['zone'] as String, provider), london), isTrue);
      Assert.AreEqual(value.ToInstant(), Instant.fromJson(map['instant'] as String));
    });

    test('an unknown zone ID', () {
      expect(() => ZonedDateTime.fromJson('2024-03-31T15:30:15+01 Europe/Nowhere', provider),
          throwsA(isA<UnparsableValueException>()));
      expect(() => DateTimeZone.fromJson('Europe/Nowhere', provider), throwsA(isA<DateTimeZoneNotFoundException>()));
    });

    test('an offset the zone doesn\'t have at that local time', () {
      expect(() => ZonedDateTime.fromJson('2024-03-31T15:30:15+02 Europe/London', provider),
          throwsA(isA<UnparsableValueException>()));
    });
  });

  group('JSON with the Windows zone ID provider (package:noda_dart/windows.dart)', () {
    final provider = WindowsIdDateTimeZoneProvider(tzdb_bundled.tzdb);

    test('ZonedDateTime and DateTimeZone round trip', () {
      final zone = provider['AUS Eastern Standard Time'];
      final value = Instant.FromUtc(2024, 3, 31, 14, 30, 15).InZone(zone);
      // The zones keep their tzdb IDs (only lookup accepts the Windows form), so they write those; both read back.
      expect(value.toJson(), '2024-04-01T01:30:15+11 Australia/Sydney');
      Assert.AreEqual(value, ZonedDateTime.fromJson(value.toJson(), provider));
      Assert.AreEqual(value, ZonedDateTime.fromJson('2024-04-01T01:30:15+11 AUS Eastern Standard Time', provider));
      expect(identical(DateTimeZone.fromJson(zone.toJson(), provider), zone), isTrue);
      expect(identical(DateTimeZone.fromJson('AUS Eastern Standard Time', provider), zone), isTrue);
    });

    test('an unknown Windows ID', () {
      expect(() => DateTimeZone.fromJson('Nowhere Standard Time', provider),
          throwsA(isA<DateTimeZoneNotFoundException>()));
      expect(() => ZonedDateTime.fromJson('2024-04-01T01:30:15+11 Nowhere Standard Time', provider),
          throwsA(isA<UnparsableValueException>()));
    });
  });

  group('JSON with a custom provider (DateTimeZoneCache over a FakeDateTimeZoneSource)', () {
    final transition = Instant.FromUtc(2000, 6, 1, 0, 0);
    final custom = SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(
        transition, Offset.FromHours(-3), Offset.FromHoursAndMinutes(4, 30), 'Test/Custom');
    final fixed = DateTimeZone.ForOffset(Offset.FromHours(2));
    final source = (FakeDateTimeZoneSourceBuilder()
          ..Add(custom)
          ..Add(fixed))
        .Build();
    final provider = DateTimeZoneCache(source);

    test('the provider gives the source\'s zones', () {
      expect(identical(provider['Test/Custom'], custom), isTrue);
      expect(provider.VersionId, 'TestZones');
    });

    test('ZonedDateTime round trip, either side of the transition', () {
      for (final (instant, text) in [
        (transition.MinusDuration(Duration.FromHours(1)), '2000-05-31T20:00:00-03 Test/Custom'),
        (transition.Plus(Duration.FromNanoseconds(1500)), '2000-06-01T04:30:00.0000015+04:30 Test/Custom'),
      ]) {
        final value = instant.InZone(provider['Test/Custom']);
        expect(value.toJson(), text);
        final read = ZonedDateTime.fromJson(text, provider);
        Assert.AreEqual(value, read);
        expect(identical(read.Zone, custom), isTrue);
      }
    });

    test('ZonedDateTime in a fixed-offset zone of the source', () {
      final value = transition.InZone(provider[fixed.Id]);
      expect(value.toJson(), '2000-06-01T02:00:00+02 UTC+02');
      Assert.AreEqual(value, ZonedDateTime.fromJson(value.toJson(), provider));
    });

    test('ZonedDateTime round trip in another calendar', () {
      final value = transition.InZone(custom, CalendarSystem.Coptic);
      Assert.AreEqual(value, ZonedDateTime.fromJson(value.toJson(), provider, CalendarSystem.Coptic));
    });

    test('DateTimeZone round trip', () {
      expect(jsonEncode([custom, fixed]), '["Test/Custom","UTC+02"]');
      expect(identical(DateTimeZone.fromJson('Test/Custom', provider), custom), isTrue);
    });

    test('IDs the source doesn\'t have', () {
      expect(() => ZonedDateTime.fromJson('2024-03-31T15:30:15+01 Europe/London', provider),
          throwsA(isA<UnparsableValueException>()));
      expect(() => DateTimeZone.fromJson('Europe/London', provider), throwsA(isA<DateTimeZoneNotFoundException>()));
      // And the other way round: the tzdb provider doesn't have the custom zone.
      expect(() => ZonedDateTime.fromJson('2000-05-31T20:00:00-03 Test/Custom', tzdb_bundled.tzdb),
          throwsA(isA<UnparsableValueException>()));
    });
  });
}
