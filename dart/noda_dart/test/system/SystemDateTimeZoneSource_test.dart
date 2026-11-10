// noda_dart: new code (as noda-js's SystemDateTimeZoneSource.test.ts). The system source over a fake Windows, so these
// run on every platform.
@Tags(['system'])
library;

import 'dart:typed_data';

import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/src/System/Host.dart' as host;
import 'package:noda_dart/src/System/IntlSystemTimeZones.dart';
import 'package:noda_dart/src/System/LocalTimeZoneFromTZ.dart';
import 'package:noda_dart/src/System/TimeZoneInfo.dart';
import 'package:noda_dart/src/System/TimeZoneNotFoundException.dart';
import 'package:noda_dart/src/System/InvalidTimeZoneException.dart';
import 'package:noda_dart/src/System/Windows/WindowsTimeZoneApi.dart';
import 'package:noda_dart/src/TimeZones/HostTimeZone.dart';
import 'package:noda_dart/src/TimeZones/SystemDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/SystemDateTimeZoneSource.dart';
import 'package:noda_dart/src/TimeZones/TimeZoneInfoInterceptor.dart';
import 'package:noda_dart/src/TimeZones/TzdbBundledData.generated.dart' show nzdBytes;
import 'package:noda_dart/src/Utility/TimeZoneEnvironment.dart';
import 'package:noda_dart/tzdb_bundled.dart';
import 'package:test/test.dart';

import '../helpers/FakeWindowsTimeZoneApi.dart';

T WithWindows<T>(List<FakeZone> zones, FakeWindowsOptions options,
    T Function(SystemDateTimeZoneSource source, FakeWindowsTimeZoneApi api) body) {
  final api = FakeWindowsTimeZoneApi(zones, options);
  return WithShim(api.CreateShim(), () => body(SystemDateTimeZoneSource(), api));
}

T WithShim<T>(TimeZoneInfoInterceptorITimeZoneInfoShim? shim, T Function() body) {
  final original = TimeZoneInfoInterceptor.Shim;
  TimeZoneInfoInterceptor.Shim = shim;
  SystemDateTimeZone.ResetSystemDefaultCache();
  try {
    return body();
  } finally {
    TimeZoneInfoInterceptor.Shim = original;
    SystemDateTimeZone.ResetSystemDefaultCache();
  }
}

/// In place until the returned function is called.
void Function() ReplaceTimeZoneInfo(TimeZoneInfo? local, List<TimeZoneInfo> zones) {
  final original = TimeZoneInfoInterceptor.Shim;
  TimeZoneInfoInterceptor.Shim = _TimeZoneInfoReplacer(local, zones);
  return () => TimeZoneInfoInterceptor.Shim = original;
}

final class _TimeZoneInfoReplacer implements TimeZoneInfoInterceptorITimeZoneInfoShim {
  @override
  final TimeZoneInfo? Local;
  final List<TimeZoneInfo> _zones;

  _TimeZoneInfoReplacer(this.Local, this._zones);

  @override
  SystemTimeZoneBackend get Backend => 'ffi';

  @override
  String get Description => 'TimeZoneInfoReplacer';

  @override
  TimeZoneInfo FindSystemTimeZoneById(String id) => _zones.firstWhere((zone) => zone.Id == id,
      orElse: () => throw TimeZoneNotFoundException('No such time zone: $id'));

  @override
  List<TimeZoneInfo> GetSystemTimeZones() => _zones;
}

final class _ShimLookup implements ISystemTimeZoneLookup {
  final TimeZoneInfoInterceptorITimeZoneInfoShim _shim;

  _ShimLookup(this._shim);

  @override
  TimeZoneInfo FindSystemTimeZoneById(String id) => _shim.FindSystemTimeZoneById(id);

  @override
  List<TimeZoneInfo> GetSystemTimeZones() => _shim.GetSystemTimeZones();

  @override
  TimeZoneInfo get Utc => _shim.FindSystemTimeZoneById('UTC');
}

List<int> WeeklyOffsets(DateTimeZone zone, int startYear, int endYear) {
  final offsets = <int>[];
  final end = Instant.FromUtc(endYear, 1, 1, 0, 0);
  for (var instant = Instant.FromUtc(startYear, 1, 1, 0, 0);
      instant < end;
      instant = instant.PlusTicks(7 * 864000000000)) {
    offsets.add(zone.GetUtcOffset(instant).Seconds);
  }
  return offsets;
}

FakeWindowsOptions local(FakeZone zone, {String? KeyName, bool DynamicDaylightTimeDisabled = false}) =>
    FakeWindowsOptions.WithLocal(DynamicInformation(zone,
        Year: 2024, KeyName: KeyName, DynamicDaylightTimeDisabled: DynamicDaylightTimeDisabled));

// TZ is replaced (ReplaceTZEnvironmentVariable), not set on the process, which would change dart:core's local zone.
void Function()? _restoreTZ;

void SetTZ(String? value) {
  _restoreTZ?.call();
  _restoreTZ = ReplaceTZEnvironmentVariable(value);
}

/// A fresh source (empty guess cache).
TzdbDateTimeZoneSource NewTzdbSource() => TzdbDateTimeZoneSource.FromBytes(nzdBytes);

final class _FakeHostTimeZone implements IHostTimeZone {
  @override
  final String Id;
  @override
  final bool FromEnvironment;
  final Offset Function(Instant instant) _getUtcOffset;

  _FakeHostTimeZone(this.Id, this.FromEnvironment, this._getUtcOffset);

  @override
  Offset GetUtcOffset(Instant instant) => _getUtcOffset(instant);
}

IHostTimeZone like(DateTimeZone zone, [String id = 'Local', bool fromEnvironment = false]) =>
    _FakeHostTimeZone(id, fromEnvironment, zone.GetUtcOffset);

IHostTimeZone fromTz(String id) => _FakeHostTimeZone(id, true, (_) => Offset.Zero);

void main() {
  setUp(() => SetTZ(null));
  tearDown(() {
    _restoreTZ?.call();
    _restoreTZ = null;
  });

  group('SystemDateTimeZoneSource on Windows (fake registry)', () {
    test("advertises the registry's zones, sorted as TimeZoneInfo.GetSystemTimeZones sorts them, plus the local zone",
        () {
      WithWindows(FakeZones, local(SaWesternZone), (source, _) {
        expect(source.Backend, 'ffi');
        expect(source.VersionId, 'TimeZoneInfo: Windows (fake)');
        // By base offset, then display name (ordinal).
        expect(source.GetIds().toList(), [
          'SA Western Standard Time',
          'E. South America Standard Time',
          'UTC-02',
          'UTC',
          'AUS Eastern Standard Time',
          'Samoa Standard Time',
        ]);
        expect(source.GetSystemDefaultId(), 'SA Western Standard Time');
      });
    });

    test('leaves out zones whose data is invalid, as .NET does', () {
      final bad = FakeZone(Id: 'Bad Standard Time', Display: '(UTC) Bad', Std: 'Bad', TziBytes: Uint8List(40));
      final badDynamic = AusEasternZone.With(
          Id: 'Bad Dynamic Standard Time',
          Dynamic: FakeDynamicDst(First: 2007, Last: 2009, Years: AusEasternZone.Dynamic!.Years));
      final badFirst = AusEasternZone.With(
          Id: 'Bad First Standard Time',
          Dynamic: FakeDynamicDst(First: '2007', Last: 2008, Years: AusEasternZone.Dynamic!.Years));
      const badTransition = FakeZone(
          Id: 'Bad Transition Standard Time',
          Std: 'x',
          Tzi: FakeTzi(
              Bias: 0,
              DaylightBias: -60,
              StandardDate: [0, 13, 0, 1, 2, 0, 0, 0],
              DaylightDate: [0, 3, 0, 1, 2, 0, 0, 0]));
      final zones = [UtcZone, bad, badDynamic, badFirst, badTransition];
      // Before every zone is read, FindSystemTimeZoneById reads the registry and throws InvalidTimeZoneException.
      WithWindows(zones, local(UtcZone), (source, _) {
        expect(() => source.ForId('Bad Standard Time'), throwsA(isA<InvalidTimeZoneException>()));
        expect(() => source.ForId('Bad Dynamic Standard Time'), throwsA(isA<InvalidTimeZoneException>()));
        expect(() => source.ForId('Bad First Standard Time'), throwsA(isA<InvalidTimeZoneException>()));
        expect(() => source.ForId('Bad Transition Standard Time'), throwsA(isA<InvalidTimeZoneException>()));
      });
      // After, it only looks in its cache, so they're not found.
      WithWindows(zones, local(UtcZone), (source, _) {
        expect(source.GetIds().toList(), ['UTC']);
        expect(() => source.ForId('Bad Standard Time'), throwsA(isA<ArgumentError>()));
      });
    });

    test('ForId: Windows IDs case-insensitively, IANA IDs (keeping the IANA ID), UTC; ArgumentError otherwise', () {
      WithWindows(FakeZones, local(SaWesternZone), (source, _) {
        source.GetIds();
        expect(source.ForId('aus eastern standard time').Id, 'AUS Eastern Standard Time');
        final sydney = source.ForId('Australia/Sydney');
        expect(sydney.Id, 'Australia/Sydney');
        expect(sydney.OriginalZone!.HasIanaId, isTrue);
        expect(WeeklyOffsets(sydney, 2000, 2030), WeeklyOffsets(source.ForId('AUS Eastern Standard Time'), 2000, 2030));
        expect(source.ForId('utc').Id, 'UTC');
        expect(source.ForId('UTC').OriginalZone!.DisplayName, '(UTC) Coordinated Universal Time');
        expect(() => source.ForId('Mars/Olympus_Mons'), throwsA(isA<ArgumentError>()));
        // An IANA ID whose Windows zone isn't in this registry.
        expect(() => source.ForId('Europe/London'), throwsA(isA<ArgumentError>()));
      });
    });

    test(
        "converts Windows' rules into the same zone intervals as tzdb's, where they agree (including midnight "
        'transitions and Samoa)', () {
      WithWindows(FakeZones, local(UtcZone), (source, _) {
        expect(WeeklyOffsets(source.ForId('AUS Eastern Standard Time'), 2008, 2040),
            WeeklyOffsets(tzdb['Australia/Sydney'], 2008, 2040));
        expect(WeeklyOffsets(source.ForId('E. South America Standard Time'), 2010, 2040),
            WeeklyOffsets(tzdb['America/Sao_Paulo'], 2010, 2040));
        expect(WeeklyOffsets(source.ForId('Samoa Standard Time'), 2012, 2021),
            WeeklyOffsets(tzdb['Pacific/Apia'], 2012, 2021));
        expect(WeeklyOffsets(source.ForId('Samoa Standard Time'), 2022, 2040),
            WeeklyOffsets(tzdb['Pacific/Apia'], 2022, 2040));
        // Samoa's base offset changed (UTC-11 → UTC+13) at the end of 2011: a rule's own standard offset.
        final before = source.ForId('Samoa Standard Time').GetZoneInterval(Instant.FromUtc(2010, 7, 1, 0, 0));
        expect(before.StandardOffset, Offset.FromHours(-11));
        // A transition at 24:00 (23:59:59.999 in Windows' data) is at midnight.
        final brazil =
            source.ForId('E. South America Standard Time').GetZoneInterval(Instant.FromUtc(2012, 6, 1, 0, 0));
        expect(brazil.Start, Instant.FromUtc(2012, 2, 26, 2, 0));
        expect(brazil.End, Instant.FromUtc(2012, 10, 21, 3, 0));
        // Names are the TimeZoneInfo's.
        final sydney = source.ForId('AUS Eastern Standard Time');
        expect(sydney.GetZoneInterval(Instant.FromUtc(2024, 1, 1, 0, 0)).Name, 'AUS Eastern Summer Time');
        expect(sydney.GetZoneInterval(Instant.FromUtc(2024, 7, 1, 0, 0)).Name, 'AUS Eastern Standard Time');
        expect(sydney.GetZoneInterval(Instant.MinValue).HasStart, isFalse);
        expect(sydney.GetZoneInterval(Instant.MaxValue).HasEnd, isFalse);
      });
    });

    test("reads names from the MUI files of the user's UI language or a parent, else from the registry", () {
      FakeWindowsOptions options(List<String> languages, Map<String, Map<int, String>> files) =>
          FakeWindowsOptions.WithLocal(DynamicInformation(UtcZone, Year: 2024), Languages: languages, MuiFiles: files);
      WithWindows(
          FakeZones,
          options([
            'fr-CA'
          ], {
            'C:\\Windows\\system32\\fr\\tzres.dll.mui': {
              670: '(UTC+10:00) Canberra, Melbourne, Sydney (fr)',
              672: "Est de l'Australie"
            }
          }), (source, _) {
        final sydney = source.ForId('AUS Eastern Standard Time');
        expect(sydney.DisplayName, '(UTC+10:00) Canberra, Melbourne, Sydney (fr)');
        expect(sydney.OriginalZone!.StandardName, "Est de l'Australie");
        // No string 671: the registry's Dlt.
        expect(sydney.OriginalZone!.DaylightName, 'AUS Eastern Summer Time');
        // Not English: UTC's standard name is localized too (from MUI_Std, -932: not in the file, so the registry's).
        expect(source.ForId('UTC').OriginalZone!.StandardName, 'Coordinated Universal Time');
      });
      WithWindows(FakeZones, options(['de-DE'], {}), (source, _) {
        expect(source.ForId('AUS Eastern Standard Time').DisplayName, '(UTC+10:00) Canberra, Melbourne, Sydney');
      });
    });

    test("the local zone: GetDynamicTimeZoneInformation's key name, or the matching registry entry, or 'Local'", () {
      // DST turned off ("Adjust for daylight saving time automatically"): the same ID, but ForSystemDefault has no DST.
      WithWindows(FakeZones, local(AusEasternZone, DynamicDaylightTimeDisabled: true), (source, _) {
        expect(source.GetSystemDefaultId(), 'AUS Eastern Standard Time');
        final zone = SystemDateTimeZone.ForSystemDefault();
        expect(zone.Id, 'AUS Eastern Standard Time');
        expect(zone.OriginalZone!.SupportsDaylightSavingTime, isFalse);
        expect(zone.GetUtcOffset(Instant.FromUtc(2024, 1, 1, 0, 0)), Offset.FromHours(10));
        expect(SystemDateTimeZone.ForSystemDefault(), same(zone));
        expect(DateTimeZoneCache(source).GetSystemDefault().GetUtcOffset(Instant.FromUtc(2024, 1, 1, 0, 0)),
            Offset.FromHours(11));
      });
      // No key name: found by comparing the data with the registry's.
      WithWindows(FakeZones, local(AusEasternZone, KeyName: ''), (source, _) {
        expect(source.GetSystemDefaultId(), 'AUS Eastern Standard Time');
      });
      // A key that doesn't exist, and data that matches nothing: a zone built from the data, named by its standard name.
      const custom =
          FakeZone(Id: 'Nowhere', Std: 'Nowhere Standard Time', Dlt: 'Nowhere Daylight Time', Tzi: FakeTzi(Bias: -345));
      WithWindows(FakeZones, local(custom, KeyName: 'Nowhere'), (source, _) {
        expect(source.GetSystemDefaultId(), 'Nowhere Standard Time');
        expect(source.GetIds(), isNot(contains('Nowhere Standard Time')));
        expect(SystemDateTimeZone.ForSystemDefault().GetUtcOffset(Instant.FromUtc(2024, 1, 1, 0, 0)),
            Offset.FromHoursAndMinutes(5, 45));
        expect(() => DateTimeZoneCache(source).GetSystemDefault(), throwsA(isA<DateTimeZoneNotFoundException>()));
      });
      // TIME_ZONE_ID_INVALID: a dummy UTC zone called "Local".
      WithWindows(FakeZones, const FakeWindowsOptions.WithLocal(null), (source, _) {
        expect(source.GetSystemDefaultId(), 'Local');
      });
    });

    test('caches TimeZoneInfo as .NET does: ForId returns zones over the same TimeZoneInfo', () {
      WithWindows(FakeZones, local(UtcZone), (source, api) {
        source.GetIds();
        final reads = api.Calls['GetRegistryValue'];
        expect(source.ForId('AUS Eastern Standard Time').OriginalZone,
            same(source.ForId('AUS Eastern Standard Time').OriginalZone));
        expect(api.Calls['GetRegistryValue'], reads);
      });
    });
  });

  // Reading TZ itself is tested in child processes: Environment_test.dart.
  group('resolving the TZ environment variable', () {
    test(
        'with TimeZoneInfo, TimeZoneInfo.Local is the zone TZ names (read when Local is first used): a Windows ID, an '
        'IANA ID, or UTC for anything else', () {
      List<String?> localWith(String? tz) {
        SetTZ(tz);
        return WithWindows(
            FakeZones,
            local(SaWesternZone),
            (source, _) => [
                  TimeZoneInfoInterceptor.Local!.Id,
                  source.GetSystemDefaultId(),
                  SystemDateTimeZone.ForSystemDefault().Id
                ]);
      }

      expect(localWith(null), ['SA Western Standard Time', 'SA Western Standard Time', 'SA Western Standard Time']);
      expect(localWith(''), ['SA Western Standard Time', 'SA Western Standard Time', 'SA Western Standard Time']);
      expect(localWith(':AUS Eastern Standard Time'),
          ['AUS Eastern Standard Time', 'AUS Eastern Standard Time', 'AUS Eastern Standard Time']);
      expect(localWith('AUS Eastern Standard Time'),
          ['AUS Eastern Standard Time', 'AUS Eastern Standard Time', 'AUS Eastern Standard Time']);
      expect(localWith('Australia/Sydney'),
          ['AUS Eastern Standard Time', 'AUS Eastern Standard Time', 'AUS Eastern Standard Time']);
      expect(localWith('Mars/Olympus_Mons'), ['UTC', 'UTC', 'UTC']);
    });

    test(
        "a replaced TimeZoneInfo.Local (NodaTime's TimeZoneInfoReplacer) wins over TZ, as TZ only decides what Local is",
        () {
      SetTZ('AUS Eastern Standard Time');
      WithWindows(FakeZones, local(SaWesternZone), (_, __) {
        final shim = TimeZoneInfoInterceptor.Shim!;
        final samoa = shim.FindSystemTimeZoneById('Samoa Standard Time');
        final restore = ReplaceTimeZoneInfo(samoa, shim.GetSystemTimeZones());
        try {
          SystemDateTimeZone.ResetSystemDefaultCache();
          // A source created after the replacement, as in NodaTime's tests.
          expect(SystemDateTimeZoneSource().GetSystemDefaultId(), 'Samoa Standard Time');
          expect(SystemDateTimeZone.ForSystemDefault().Id, 'Samoa Standard Time');
        } finally {
          restore();
        }
      });
    });

    String? resolve(String tz) => WithWindows(
        FakeZones, local(UtcZone), (_, __) => ResolveTimeZoneInfoId(_ShimLookup(TimeZoneInfoInterceptor.Shim!), tz));

    test('with TimeZoneInfo: a Windows ID (any case), or an IANA ID mapped to its Windows ID', () {
      expect(resolve('AUS Eastern Standard Time'), 'AUS Eastern Standard Time');
      expect(resolve('aus eastern standard time'), 'AUS Eastern Standard Time');
      expect(resolve('Australia/Sydney'), 'AUS Eastern Standard Time');
      expect(resolve('Australia/Melbourne'), 'AUS Eastern Standard Time');
      expect(resolve('America/La_Paz'), 'SA Western Standard Time');
      expect(resolve('UTC'), 'UTC');
      expect(resolve('Etc/UTC'), 'UTC');
    });

    test('with TimeZoneInfo: anything else names no zone (and so means UTC: see Environment_test.dart)', () {
      expect(resolve('Mars/Olympus_Mons'), isNull);
      // An IANA ID whose Windows zone isn't in the registry.
      expect(resolve('Europe/London'), isNull);
      // A POSIX TZ string.
      expect(resolve('AEST-10AEDT,M10.1.0,M4.1.0/3'), isNull);
    });

    test(
        'the tzdb source: a Windows ID mapped by its WindowsMapping, a tzdb ID as is, anything else is Etc/UTC (no guess)',
        () {
      final source = NewTzdbSource();
      expect(source.MapTimeZoneInfoId(fromTz('SA Western Standard Time')), 'America/La_Paz');
      expect(source.MapTimeZoneInfoId(fromTz('Asia/Tokyo')), 'Asia/Tokyo');
      expect(source.MapTimeZoneInfoId(fromTz('Mars/Olympus_Mons')), 'Etc/UTC');
      expect(source.MapTimeZoneInfoId(fromTz('UTC')), 'Etc/UTC');
    });

    test('the tzdb source: an ID in TZ matched ignoring case, as the system source matches it', () {
      final source = NewTzdbSource();
      expect(source.MapTimeZoneInfoId(fromTz('sa western standard time')), 'America/La_Paz');
      expect(source.MapTimeZoneInfoId(fromTz('SA WESTERN STANDARD TIME')), 'America/La_Paz');
      expect(source.MapTimeZoneInfoId(fromTz('asia/tokyo')), 'Asia/Tokyo');
      // An alias keeps its ID, as when it's matched exactly.
      expect(source.MapTimeZoneInfoId(fromTz('asia/calcutta')), 'Asia/Calcutta');
      expect(source.MapTimeZoneInfoId(fromTz('utc')), 'Etc/UTC');
    });
  });

  group("without TimeZoneInfo: the host's Intl zones", () {
    final skip = host.IntlIsAvailable() ? null : 'The web only (Intl)';

    test('on Windows: Windows IDs mapped by CLDR, with the rules of their primary IANA zone; IANA IDs accepted too',
        () {
      final intl = IntlSystemTimeZones(true);
      final source = SystemDateTimeZoneSource.NewHost(intl);
      expect(source.Backend, 'intl');
      expect(source.VersionId, matches(RegExp(r'^Intl: .+ \(Windows IDs from CLDR windowsZones \d+\)$')));
      final ids = source.GetIds();
      expect(ids, contains('AUS Eastern Standard Time'));
      expect(ids, contains('UTC'));
      expect(ids, isNot(contains('Australia/Sydney')));
      final zone = source.ForId('aus eastern standard time');
      expect(zone.Id, 'AUS Eastern Standard Time');
      expect(zone.OriginalZone, isNull);
      expect(WeeklyOffsets(zone, 2000, 2030), WeeklyOffsets(tzdb['Australia/Sydney'], 2000, 2030));
      expect(source.ForId('Australia/Sydney').Id, 'Australia/Sydney');
      expect(() => source.ForId('Mars/Olympus_Mons'), throwsA(isA<ArgumentError>()));
      expect(intl.ResolveId('America/La_Paz'), 'SA Western Standard Time');
      expect(intl.ResolveId('sa western standard time'), 'SA Western Standard Time');
      expect(intl.ResolveId('Mars/Olympus_Mons'), isNull);
    }, skip: skip);

    test('elsewhere: IANA IDs', () {
      final intl = IntlSystemTimeZones(false);
      final source = SystemDateTimeZoneSource.NewHost(intl);
      expect(source.VersionId, matches(RegExp(r'^Intl: [^(]+$')));
      expect(source.GetIds(), contains('Australia/Sydney'));
      expect(source.GetIds(), isNot(contains('AUS Eastern Standard Time')));
      final zone = source.ForId('Australia/Sydney');
      expect(WeeklyOffsets(zone, 2000, 2030), WeeklyOffsets(tzdb['Australia/Sydney'], 2000, 2030));
      expect(() => source.ForId('AUS Eastern Standard Time'), throwsA(isA<ArgumentError>()));
      expect(intl.ResolveId('Asia/Tokyo'), 'Asia/Tokyo');
      expect(intl.ResolveId('AUS Eastern Standard Time'), isNull);
      final IDateTimeZoneProvider provider = DateTimeZoneCache(source);
      expect(provider.GetSystemDefault(), isA<SystemDateTimeZone>());
    }, skip: skip);

    test('SystemDateTimeZone.ForSystemDefault and the provider agree', () {
      WithShim(null, () {
        final source = SystemDateTimeZoneSource();
        expect(source.Backend, 'intl');
        expect(SystemDateTimeZone.ForSystemDefault().Id, DateTimeZoneCache(source).GetSystemDefault().Id);
      });
    }, skip: skip);
  });

  group("the tzdb source's guess of the host's zone (GuessZoneIdByTransitionsUncached)", () {
    late List<DateTimeZone> candidates;
    setUpAll(() {
      candidates = tzdbSource.CanonicalIdMap.values.toSet().map(tzdbSource.ForId).toList()
        ..sort((a, b) => a.Id.compareTo(b.Id));
    });

    test("picks the first zone (in ordinal order) with the host zone's offsets", () {
      final tokyo = tzdb['Asia/Tokyo'];
      final guess = TzdbDateTimeZoneSource.GuessZoneIdByTransitionsUncached(like(tokyo), candidates);
      // The first of the zones that are UTC+9 for the next five years (Asia/Chita, Asia/Dili, ..., Asia/Tokyo, ...).
      final thisYear = SystemClock.Instance.GetCurrentInstant().InUtc().Year;
      final expected = candidates
          .firstWhere((zone) => WeeklyOffsets(zone, thisYear, thisYear + 5).every((offset) => offset == 32400));
      expect(guess, expected.Id);
      // Antarctica/Macquarie has had Sydney's rules since 2010.
      expect(TzdbDateTimeZoneSource.GuessZoneIdByTransitionsUncached(like(tzdb['Australia/Sydney']), candidates),
          'Antarctica/Macquarie');
    });

    test('returns null when no zone matches 70% of the transitions', () {
      final strange = _FakeHostTimeZone('Strange', false, (_) => Offset.FromHoursAndMinutes(13, 37));
      expect(TzdbDateTimeZoneSource.GuessZoneIdByTransitionsUncached(strange, candidates), isNull);
    });

    test("MapTimeZoneInfoId: a Windows ID, a tzdb ID, a guess; a TZ ID that doesn't map is UTC", () {
      final source = NewTzdbSource();
      expect(source.MapTimeZoneInfoId(like(tzdb['Asia/Tokyo'], 'Tokyo Standard Time')), 'Asia/Tokyo');
      expect(source.MapTimeZoneInfoId(like(tzdb['Asia/Tokyo'], 'Asia/Tokyo')), 'Asia/Tokyo');
      expect(source.MapTimeZoneInfoId(like(DateTimeZone.ForOffset(Offset.FromHours(-10)), 'Lilo and Stitch')),
          'Etc/GMT+10');
      expect(source.MapTimeZoneInfoId(like(tzdb['Asia/Tokyo'], 'Not A Zone', true)), 'Etc/UTC');
    });

    test("the host's zone has DateTime's offsets", () {
      final hostZone = GetHostTimeZone();
      final instant = Instant.FromUtc(2024, 1, 15, 12, 0);
      expect(hostZone.GetUtcOffset(instant).Seconds,
          DateTime.fromMillisecondsSinceEpoch(instant.ToUnixTimeMilliseconds()).timeZoneOffset.inSeconds);
    });
  });
}
