// noda_dart: new code (as noda-js's test/windows.test.ts). WindowsIdDateTimeZoneProvider.
@Tags(['system'])
library;

import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/tzdb_bundled.dart';
import 'package:noda_dart/windows.dart';
import 'package:test/test.dart';

void main() {
  group('WindowsIdDateTimeZoneProvider', () {
    late WindowsIdDateTimeZoneProvider provider;
    setUpAll(() {
      provider = WindowsIdDateTimeZoneProvider(tzdb);
    });

    test('maps a Windows ID to its CLDR primary tzdb zone, and keeps tzdb IDs working', () {
      expect(provider.GetZoneOrNull('AUS Eastern Standard Time'), same(tzdb['Australia/Sydney']));
      expect(provider['GMT Standard Time'], same(tzdb['Europe/London']));
      expect(provider['Europe/London'], same(tzdb['Europe/London']));
      expect(provider.GetZoneOrNull('Not A Zone'), isNull);
      expect(() => provider['Not A Zone'], throwsA(isA<DateTimeZoneNotFoundException>()));
    });

    test("advertises the Windows IDs it accepts as well as the wrapped provider's, in ordinal order", () {
      final ids = provider.Ids;
      expect(ids, contains('AUS Eastern Standard Time'));
      expect(ids, contains('Australia/Sydney'));
      for (final id in tzdb.Ids) {
        expect(ids, contains(id));
      }
      expect([...ids]..sort((a, b) => a.compareTo(b)), ids);
      expect(ids.toSet(), hasLength(ids.length));
      expect(provider.Ids, same(ids));
    });

    test('lets patterns parse a Windows zone ID (as written by .NET apps using BclDateTimeZone)', () {
      final value = ZonedDateTime.fromJson('2024-04-01T01:30:00+11 AUS Eastern Standard Time', provider);
      expect(value.Zone, same(tzdb['Australia/Sydney']));
      expect(value.toJson(), '2024-04-01T01:30:00+11 Australia/Sydney');
    });

    test('finds the Windows ID for a tzdb ID', () {
      expect(provider.WindowsIdForTzdbId('Australia/Sydney'), 'AUS Eastern Standard Time');
      expect(provider.WindowsIdForTzdbId('Not/A_Zone'), isNull);
    });
  });
}
