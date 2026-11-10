// noda_dart: new code. Conversions to and from Dart's DateTime, Duration and Stopwatch, at the edges.
// The DST tests are skipped where the local zone has no transitions.

import 'dart:core' as core;
import 'dart:core' hide Duration;

import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/src/Utility/Int64.dart';
import 'package:noda_dart/tzdb_bundled.dart' as tzdb_bundled;
import 'package:test/test.dart';

import 'helpers/Scenarios.dart' show isDart2js;

const String _beyond2To53 = "Uses integers beyond ±2^53, which dart2js can't represent exactly";

final core.DateTime lastMicrosecond = core.DateTime.utc(9999, 12, 31, 23, 59, 59, 999, 999);

void main() {
  group('Instant', () {
    test('ToDateTimeUtc is UTC, with the same instant', () {
      var instant = Instant.FromUtc(2017, 8, 21, 12, 46, 13).PlusNanoseconds(123456789);
      var dateTime = instant.ToDateTimeUtc();
      expect(dateTime.isUtc, isTrue);
      expect(dateTime, core.DateTime.utc(2017, 8, 21, 12, 46, 13, 123, 456));
    });

    test('ToDateTimeUtc truncates to the microsecond towards the start of time', () {
      expect(NodaConstants.UnixEpoch.PlusNanoseconds(999).ToDateTimeUtc(), core.DateTime.utc(1970));
      expect(NodaConstants.UnixEpoch.PlusNanoseconds(1000).ToDateTimeUtc(), core.DateTime.utc(1970, 1, 1, 0, 0, 0, 0, 1));
      // Before 1970: towards the start of time, not towards the epoch (as .NET truncates to ticks).
      expect(NodaConstants.UnixEpoch.PlusNanoseconds(-1).ToDateTimeUtc(),
          core.DateTime.utc(1969, 12, 31, 23, 59, 59, 999, 999));
      expect(NodaConstants.UnixEpoch.PlusNanoseconds(-1000).ToDateTimeUtc(),
          core.DateTime.utc(1969, 12, 31, 23, 59, 59, 999, 999));
      expect(NodaConstants.UnixEpoch.PlusNanoseconds(-1001).ToDateTimeUtc(),
          core.DateTime.utc(1969, 12, 31, 23, 59, 59, 999, 998));
      expect(Instant.FromUtc(1066, 10, 14, 9, 30).PlusNanoseconds(-1).ToDateTimeUtc(),
          core.DateTime.utc(1066, 10, 14, 9, 29, 59, 999, 999));
    });

    test('ToDateTimeUtc at the ends of the range', () {
      expect(NodaConstants.BclEpoch.ToDateTimeUtc(), core.DateTime.utc(1));
      expect(Instant.MaxValue.ToDateTimeUtc(), lastMicrosecond);
      expect(() => NodaConstants.BclEpoch.PlusNanoseconds(-1).ToDateTimeUtc(), throwsStateError);
      expect(() => Instant.MinValue.ToDateTimeUtc(), throwsStateError);
    });

    test('FromDateTimeUtc', () {
      expect(Instant.FromDateTimeUtc(core.DateTime.utc(2017, 8, 21, 12, 46, 13, 123, 456)),
          Instant.FromUtc(2017, 8, 21, 12, 46, 13).PlusNanoseconds(123456000));
      expect(Instant.FromDateTimeUtc(core.DateTime.utc(1969, 12, 31, 23, 59, 59, 999, 999)),
          NodaConstants.UnixEpoch.PlusNanoseconds(-1000));
      expect(Instant.FromDateTimeUtc(core.DateTime.utc(1)), NodaConstants.BclEpoch);
      expect(Instant.FromDateTimeUtc(lastMicrosecond), Instant.MaxValue.PlusNanoseconds(-999));
      expect(core.DateTime.utc(2000).ToInstant(), Instant.FromUtc(2000, 1, 1, 0, 0));
    });

    test('FromDateTimeUtc rejects a local DateTime (as .NET rejects other kinds than Utc)', () {
      var local = core.DateTime(2017, 8, 21, 12, 46, 13);
      expect(() => Instant.FromDateTimeUtc(local), throwsA(isA<ArgumentError>().having((e) => e is RangeError, 'is RangeError', isFalse)));
      expect(() => local.ToInstant(), throwsArgumentError);
      expect(() => core.DateTime.now().ToInstant(), throwsArgumentError);
      // A local DateTime is an instant too: converted to UTC, it gives that instant.
      expect(local.toUtc().ToInstant(), Instant.FromUnixTimeMilliseconds(local.millisecondsSinceEpoch));
    });

    test("FromDateTimeUtc accepts Dart's wider range down to Instant's (before .NET's year 1)", () {
      expect(Instant.FromDateTimeUtc(core.DateTime.utc(0)), Instant.FromUtc(0, 1, 1, 0, 0));
      expect(Instant.FromDateTimeUtc(core.DateTime.utc(-9998)), Instant.MinValue);
      expect(() => Instant.FromDateTimeUtc(core.DateTime.utc(-9998).subtract(const core.Duration(microseconds: 1))),
          throwsRangeError);
      expect(() => Instant.FromDateTimeUtc(core.DateTime.utc(10000)), throwsRangeError);
      expect(() => Instant.FromDateTimeUtc(core.DateTime.utc(275760, 9, 13)), throwsRangeError);
      expect(() => Instant.FromDateTimeUtc(core.DateTime.utc(-271821, 4, 20)), throwsRangeError);
    });

    test('round trips, and agrees with microsecondsSinceEpoch', () {
      for (var dateTime in sampleUtcDateTimes()) {
        var instant = Instant.FromDateTimeUtc(dateTime);
        if (dateTime.year >= 1) {
          expect(instant.ToDateTimeUtc(), dateTime, reason: '$dateTime');
        } else {
          expect(() => instant.ToDateTimeUtc(), throwsStateError, reason: '$dateTime');
        }
        expect(instant.ToUnixTimeMilliseconds(), dateTime.millisecondsSinceEpoch, reason: '$dateTime');
        if (!isDart2js || dateTime.year > 1700 && dateTime.year < 2200) {
          expect(instant.ToUnixTimeTicks(), dateTime.microsecondsSinceEpoch * 10, reason: '$dateTime');
        }
      }
    });
  });

  group('LocalDateTime', () {
    test("FromDateTime reads a UTC DateTime's fields", () {
      expect(LocalDateTime.FromDateTime(core.DateTime.utc(2017, 8, 21, 12, 46, 13, 123, 456)),
          LocalDateTime(2017, 8, 21, 12, 46, 13).PlusNanoseconds(123456000));
      expect(core.DateTime.utc(1969, 12, 31, 23, 59, 59, 999, 999).ToLocalDateTime(),
          LocalDateTime(1969, 12, 31, 23, 59, 59, 999).PlusNanoseconds(999000));
    });

    test("FromDateTime reads a local DateTime's fields (no time zone conversion)", () {
      var local = core.DateTime(2017, 8, 21, 12, 46, 13, 123, 456);
      expect(LocalDateTime.FromDateTime(local), LocalDateTime(2017, 8, 21, 12, 46, 13).PlusNanoseconds(123456000));
      expect(local.ToLocalDateTime(), LocalDateTime.FromDateTime(local));
      // The same instant in UTC has other fields unless the local zone is UTC.
      var utc = local.toUtc();
      expect(LocalDateTime.FromDateTime(utc),
          LocalDateTime.FromDateTime(local).PlusSeconds(-local.timeZoneOffset.inSeconds));
      var now = core.DateTime.now();
      var fromNow = LocalDateTime.FromDateTime(now);
      expect([fromNow.Year, fromNow.Month, fromNow.Day, fromNow.Hour, fromNow.Minute, fromNow.Second],
          [now.year, now.month, now.day, now.hour, now.minute, now.second]);
    });

    test('FromDateTime with a calendar', () {
      var dateTime = core.DateTime.utc(2011, 8, 18, 20, 53);
      var julian = LocalDateTime.FromDateTime(dateTime, CalendarSystem.Julian);
      expect(julian, LocalDateTime(2011, 8, 18, 20, 53).WithCalendar(CalendarSystem.Julian));
      expect([julian.Year, julian.Month, julian.Day], [2011, 8, 5]);
    });

    test("FromDateTime: Dart's range is wider than NodaTime's", () {
      expect(LocalDateTime.FromDateTime(core.DateTime.utc(-9998)), LocalDateTime(-9998, 1, 1, 0, 0));
      expect(LocalDateTime.FromDateTime(lastMicrosecond),
          LocalDateTime(9999, 12, 31, 23, 59, 59, 999).PlusNanoseconds(999000));
      expect(() => LocalDateTime.FromDateTime(core.DateTime.utc(-9999, 12, 31)), throwsRangeError);
      expect(() => LocalDateTime.FromDateTime(core.DateTime.utc(10000)), throwsRangeError);
    });

    test('ToDateTimeUnspecified is a local DateTime with the same fields', () {
      var ldt = LocalDateTime(2017, 8, 21, 12, 46, 13, 123).PlusNanoseconds(456789);
      var dateTime = ldt.ToDateTimeUnspecified();
      expect(dateTime.isUtc, isFalse);
      expect(dateTime, core.DateTime(2017, 8, 21, 12, 46, 13, 123, 456));
      expect(LocalDateTime(1066, 10, 14, 9, 30).ToDateTimeUnspecified(), core.DateTime(1066, 10, 14, 9, 30));
    });

    test('ToDateTimeUnspecified truncates to the microsecond (towards the start of the day)', () {
      var midnight = LocalDateTime(1969, 12, 31, 0, 0);
      expect(midnight.PlusNanoseconds(999).ToDateTimeUnspecified(), core.DateTime(1969, 12, 31));
      expect(midnight.PlusNanoseconds(1999).ToDateTimeUnspecified(), core.DateTime(1969, 12, 31, 0, 0, 0, 0, 1));
      expect(midnight.PlusNanoseconds(-1).ToDateTimeUnspecified(), core.DateTime(1969, 12, 30, 23, 59, 59, 999, 999));
    });

    test('ToDateTimeUnspecified at the ends of the range', () {
      expect(LocalDateTime(1, 1, 1, 0, 0).ToDateTimeUnspecified(), core.DateTime(1));
      expect(LocalDateTime(9999, 12, 31, 23, 59, 59, 999).PlusNanoseconds(999999).ToDateTimeUnspecified(),
          core.DateTime(9999, 12, 31, 23, 59, 59, 999, 999));
      expect(() => LocalDateTime(0, 12, 31, 23, 59, 59, 999).ToDateTimeUnspecified(), throwsStateError);
      expect(() => LocalDateTime(-9998, 1, 1, 0, 0).ToDateTimeUnspecified(), throwsStateError);
    });

    test('ToDateTimeUnspecified converts other calendars to the ISO calendar', () {
      var julian = LocalDateTime(2011, 8, 5, 20, 53).WithCalendar(CalendarSystem.Julian);
      // LocalDateTime(y, m, d, ...) is ISO; WithCalendar keeps the day. Build the Julian value directly instead.
      var julianDirect = LocalDateTime.YearMonthDayHourMinuteCalendar(2011, 8, 5, 20, 53, CalendarSystem.Julian);
      expect(julian.ToDateTimeUnspecified(), core.DateTime(2011, 8, 5, 20, 53));
      expect(julianDirect.ToDateTimeUnspecified(), core.DateTime(2011, 8, 18, 20, 53));
    });

    test('round trips through local and UTC DateTimes', () {
      for (var utc in sampleUtcDateTimes()) {
        var ldt = LocalDateTime.FromDateTime(utc);
        if (utc.year >= 1) {
          var local = ldt.ToDateTimeUnspecified();
          if (!isInLocalGap(local, ldt)) {
            expect(LocalDateTime.FromDateTime(local), ldt, reason: '$utc');
          }
        }
      }
    });
  });

  group('LocalDate', () {
    test('FromDateTime ignores the time of day, for local and UTC DateTimes', () {
      expect(LocalDate.FromDateTime(core.DateTime.utc(2011, 8, 18, 23, 59, 59, 999, 999)), LocalDate(2011, 8, 18));
      expect(LocalDate.FromDateTime(core.DateTime(2011, 8, 18, 23, 59, 59, 999, 999)), LocalDate(2011, 8, 18));
      expect(LocalDate.FromDateTime(core.DateTime.utc(1969, 12, 31, 23, 59)), LocalDate(1969, 12, 31));
      expect(LocalDate.FromDateTime(core.DateTime.utc(-9998)), LocalDate(-9998, 1, 1));
      expect(LocalDate.FromDateTime(lastMicrosecond), LocalDate(9999, 12, 31));
      expect(() => LocalDate.FromDateTime(core.DateTime.utc(10000)), throwsRangeError);
      expect(() => LocalDate.FromDateTime(core.DateTime.utc(-9999, 12, 31)), throwsRangeError);
    });

    test('FromDateTime with a calendar', () {
      var date = LocalDate.FromDateTime(core.DateTime(2011, 8, 18, 20, 53), CalendarSystem.Julian);
      expect(date, LocalDate(2011, 8, 5, CalendarSystem.Julian));
    });

    test('ToDateTimeUnspecified is local midnight (or the first time of day the local zone has)', () {
      var dateTime = LocalDate(2015, 4, 2).ToDateTimeUnspecified();
      expect(dateTime.isUtc, isFalse);
      expect(dateTime, core.DateTime(2015, 4, 2));
      expect(LocalDate(1, 1, 1).ToDateTimeUnspecified(), core.DateTime(1));
      expect(LocalDate(9999, 12, 31).ToDateTimeUnspecified(), core.DateTime(9999, 12, 31));
      expect(LocalDate(2015, 3, 20, CalendarSystem.Julian).ToDateTimeUnspecified(),
          core.DateTime(2015, 4, 2));
    });

    test("ToDateTimeUnspecified throws before .NET DateTime's year 1, as .NET does", () {
      expect(() => LocalDate(0, 12, 31).ToDateTimeUnspecified(), throwsRangeError);
      expect(() => LocalDate(-9998, 1, 1).ToDateTimeUnspecified(), throwsRangeError);
    });
  });

  group('ZonedDateTime and OffsetDateTime', () {
    var london = tzdb_bundled.tzdb['Europe/London'];

    test('ZonedDateTime.ToDateTimeUtc is the instant; ToDateTimeUnspecified the local date and time', () {
      // 2017-08-21T12:46:13.123456789 BST (+01)
      var zoned = LocalDateTime(2017, 8, 21, 12, 46, 13, 123).PlusNanoseconds(456789).InZoneStrictly(london);
      expect(zoned.ToDateTimeUtc(), core.DateTime.utc(2017, 8, 21, 11, 46, 13, 123, 456));
      expect(zoned.ToDateTimeUtc().isUtc, isTrue);
      expect(zoned.ToDateTimeUnspecified(), core.DateTime(2017, 8, 21, 12, 46, 13, 123, 456));
      expect(zoned.ToDateTimeUnspecified().isUtc, isFalse);
    });

    test('ZonedDateTime across a DST transition', () {
      // 2017-10-29T01:30 happens twice in London.
      var earlier = Instant.FromUtc(2017, 10, 29, 0, 30).InZone(london);
      var later = Instant.FromUtc(2017, 10, 29, 1, 30).InZone(london);
      expect(earlier.LocalDateTime, later.LocalDateTime);
      expect(earlier.ToDateTimeUtc(), core.DateTime.utc(2017, 10, 29, 0, 30));
      expect(later.ToDateTimeUtc(), core.DateTime.utc(2017, 10, 29, 1, 30));
      expect(earlier.ToDateTimeUnspecified(), later.ToDateTimeUnspecified());
    });

    test('ZonedDateTime from a DateTime', () {
      var dateTime = core.DateTime.utc(2017, 10, 29, 1, 30);
      expect(dateTime.ToInstant().InZone(london).ToDateTimeUtc(), dateTime);
    });

    test('ZonedDateTime.ToDateTimeUtc at the ends of the range', () {
      expect(Instant.MaxValue.InUtc().ToDateTimeUtc(), lastMicrosecond);
      expect(() => Instant.MinValue.InUtc().ToDateTimeUtc(), throwsStateError);
      expect(() => LocalDateTime(1, 1, 1, 0, 0).InZoneStrictly(DateTimeZone.ForOffset(Offset.FromHours(1))).ToDateTimeUtc(),
          throwsStateError);
    });

    test('OffsetDateTime.ToDateTimeUtc is the instant, truncated to the microsecond', () {
      var offsetDateTime = LocalDateTime(2017, 8, 21, 12, 46, 13).PlusNanoseconds(1999).WithOffset(Offset.FromHoursAndMinutes(-3, -30));
      expect(offsetDateTime.ToDateTimeUtc(), core.DateTime.utc(2017, 8, 21, 16, 16, 13, 0, 1));
      expect(offsetDateTime.ToDateTimeUtc().isUtc, isTrue);
      expect(offsetDateTime.ToDateTimeUtc(), offsetDateTime.ToInstant().ToDateTimeUtc());
      var beforeEpoch = LocalDateTime(1969, 12, 31, 20, 0).PlusNanoseconds(-1).WithOffset(Offset.FromHours(-4));
      expect(beforeEpoch.ToDateTimeUtc(), core.DateTime.utc(1969, 12, 31, 23, 59, 59, 999, 999));
      expect(() => LocalDateTime(1, 1, 1, 0, 0).WithOffset(Offset.FromHours(1)).ToDateTimeUtc(), throwsStateError);
    });

    test("OffsetDateTime from a local DateTime and its offset", () {
      var local = core.DateTime(2017, 8, 21, 12, 46, 13, 123, 456);
      var offsetDateTime = local.toUtc().ToInstant().WithOffset(Offset.FromCoreDuration(local.timeZoneOffset));
      expect(offsetDateTime.LocalDateTime, local.ToLocalDateTime());
      expect(offsetDateTime.ToDateTimeUtc(), local.toUtc());
    });
  });

  group('Duration', () {
    test('FromCoreDuration', () {
      expect(Duration.FromCoreDuration(core.Duration.zero), Duration.Zero);
      expect(Duration.FromCoreDuration(const core.Duration(microseconds: 1)), Duration.FromNanoseconds(1000));
      expect(Duration.FromCoreDuration(const core.Duration(microseconds: -1)), Duration.FromNanoseconds(-1000));
      expect(Duration.FromCoreDuration(const core.Duration(days: -1, microseconds: 1)),
          Duration.FromDays(-1) + Duration.FromNanoseconds(1000));
      expect(Duration.FromCoreDuration(const core.Duration(days: 12345, hours: 6, microseconds: 789)),
          Duration.FromDays(12345) + Duration.FromHours(6) + Duration.FromNanoseconds(789000));
      expect(const core.Duration(seconds: 90).ToDuration(), Duration.FromSeconds(90));
    });

    test('FromCoreDuration: the ends of the range', () {
      // TimeSpan.MaxValue / MinValue, in microseconds (as Dart counts them): within Duration's range.
      var maxTimeSpan = core.Duration(microseconds: Int64.MaxValue ~/ 10);
      var minTimeSpan = core.Duration(microseconds: Int64.MinValue ~/ 10);
      expect(Duration.FromCoreDuration(maxTimeSpan).BclCompatibleTicks, Int64.MaxValue ~/ 10 * 10);
      expect(Duration.FromCoreDuration(minTimeSpan).BclCompatibleTicks, Int64.MinValue ~/ 10 * 10);
      // A Dart Duration's range (±2^63 microseconds) is wider than Duration's (±2^24 days).
      expect(() => Duration.FromCoreDuration(core.Duration(microseconds: Int64.MaxValue)), throwsRangeError);
      expect(() => Duration.FromCoreDuration(core.Duration(microseconds: Int64.MinValue)), throwsRangeError);
      expect(() => Duration.FromCoreDuration(core.Duration(days: 1 << 24)), throwsRangeError);
    }, skip: isDart2js ? _beyond2To53 : null);

    test('ToCoreDuration truncates to the microsecond towards zero (as .NET truncates to ticks)', () {
      expect(Duration.FromNanoseconds(999).ToCoreDuration(), core.Duration.zero);
      expect(Duration.FromNanoseconds(1999).ToCoreDuration(), const core.Duration(microseconds: 1));
      expect(Duration.FromNanoseconds(-1999).ToCoreDuration(), const core.Duration(microseconds: -1));
      expect(Duration.FromNanoseconds(-999).ToCoreDuration(), core.Duration.zero);
      expect((Duration.FromDays(-3) + Duration.FromNanoseconds(1)).ToCoreDuration(),
          const core.Duration(days: -3) + const core.Duration(microseconds: 1));
      expect(Duration.FromHours(25).ToCoreDuration(), const core.Duration(hours: 25));
    });

    test('ToCoreDuration: the ends of the range', () {
      expect(Duration.FromTicks(Int64.MaxValue).ToCoreDuration(), core.Duration(microseconds: Int64.MaxValue ~/ 10));
      expect(Duration.FromTicks(Int64.MinValue).ToCoreDuration(), core.Duration(microseconds: Int64.MinValue ~/ 10));
      // Beyond TimeSpan's range: .NET's OverflowException.
      expect(() => Duration.MaxValue.ToCoreDuration(), throwsA(isA<OverflowException>()));
      expect(() => Duration.MinValue.ToCoreDuration(), throwsA(isA<OverflowException>()));
    }, skip: isDart2js ? _beyond2To53 : null);

    test('round trips', () {
      for (var microseconds in [0, 1, -1, 999999, -1000001, 86400000000 * 365 * 300 + 7, -86400000000 * 365 * 300 - 7]) {
        var dartDuration = core.Duration(microseconds: microseconds);
        expect(Duration.FromCoreDuration(dartDuration).ToCoreDuration(), dartDuration);
        expect(dartDuration.ToDuration().BclCompatibleTicks, microseconds * 10);
      }
    });
  });

  group('Offset', () {
    test('FromCoreDuration truncates fractional seconds towards zero', () {
      expect(Offset.FromCoreDuration(const core.Duration(hours: 5, minutes: 30)), Offset.FromHoursAndMinutes(5, 30));
      expect(Offset.FromCoreDuration(const core.Duration(seconds: 1, microseconds: 999999)), Offset.FromSeconds(1));
      expect(Offset.FromCoreDuration(const core.Duration(seconds: -1, microseconds: -999999)), Offset.FromSeconds(-1));
      expect(Offset.FromCoreDuration(const core.Duration(microseconds: -1)), Offset.Zero);
      expect(const core.Duration(hours: -3).ToOffset(), Offset.FromHours(-3));
    });

    test('FromCoreDuration: the ends of the range', () {
      expect(Offset.FromCoreDuration(const core.Duration(hours: 18)), Offset.MaxValue);
      expect(Offset.FromCoreDuration(const core.Duration(hours: -18)), Offset.MinValue);
      expect(() => Offset.FromCoreDuration(const core.Duration(hours: 18, microseconds: 1)), throwsRangeError);
      expect(() => Offset.FromCoreDuration(const core.Duration(hours: -18, microseconds: -1)), throwsRangeError);
      expect(() => const core.Duration(days: 1).ToOffset(), throwsRangeError);
    });

    test('ToCoreDuration', () {
      expect(Offset.FromHoursAndMinutes(-9, -30).ToCoreDuration(), const core.Duration(hours: -9, minutes: -30));
      expect(Offset.MaxValue.ToCoreDuration(), const core.Duration(hours: 18));
      expect(Offset.MinValue.ToCoreDuration(), const core.Duration(hours: -18));
    });

    test("a local DateTime's timeZoneOffset", () {
      var now = core.DateTime.now();
      expect(Offset.FromCoreDuration(now.timeZoneOffset).ToCoreDuration(), now.timeZoneOffset);
      expect(Offset.FromCoreDuration(now.toUtc().timeZoneOffset), Offset.Zero);
    });
  });

  group('Stopwatch and the clock', () {
    test('ElapsedDuration', () async {
      var stopwatch = core.Stopwatch()..start();
      await Future<void>.delayed(const core.Duration(milliseconds: 2));
      stopwatch.stop();
      expect(stopwatch.ElapsedDuration(), Duration.FromCoreDuration(stopwatch.elapsed));
      expect(stopwatch.ElapsedDuration() >= Duration.FromMilliseconds(1), isTrue);
    });

    test('SystemClock agrees with DateTime.now()', () {
      var before = core.DateTime.now().toUtc().ToInstant();
      var now = SystemClock.Instance.GetCurrentInstant();
      var after = core.DateTime.now().toUtc().ToInstant();
      expect(before <= now.PlusNanoseconds(999), isTrue, reason: '$before <= $now');
      expect(now <= after.PlusNanoseconds(999), isTrue, reason: '$now <= $after');
    });
  });

  group('the local time zone', () {
    final transitions = localTransitions();
    final gap = transitions.where((t) => t.offsetAfter > t.offsetBefore).firstOrNull;
    final fold = transitions.where((t) => t.offsetAfter < t.offsetBefore).firstOrNull;
    final noGap = gap == null ? 'the local time zone has no DST gap in 1990-2030' : null;
    final noFold = fold == null ? 'the local time zone has no DST fold in 1990-2030' : null;

    test("LocalDateTime.FromDateTime of a local DateTime in a fold: both instants have the same fields", () {
      var first = core.DateTime.fromMicrosecondsSinceEpoch(fold!.utc.microsecondsSinceEpoch - 1);
      var second = first.add(fold.offsetBefore - fold.offsetAfter);
      expect(second.isAfter(first), isTrue);
      expect(LocalDateTime.FromDateTime(second), LocalDateTime.FromDateTime(first));
      expect(LocalDate.FromDateTime(second), LocalDate.FromDateTime(first));
      // Converted to UTC first, they're different instants.
      expect(second.toUtc().ToInstant() - first.toUtc().ToInstant(), Duration.FromCoreDuration(fold.offsetBefore - fold.offsetAfter));
    }, skip: noFold);

    test('ToDateTimeUnspecified of a local time in a gap: Dart moves it forward past the gap', () {
      // The first microsecond after the gap.
      var afterGap = core.DateTime.fromMicrosecondsSinceEpoch(gap!.utc.microsecondsSinceEpoch);
      var gapLength = gap.offsetAfter - gap.offsetBefore;
      var inGap = LocalDateTime.FromDateTime(afterGap).Minus(Period.FromSeconds(gapLength.inSeconds ~/ 2));
      var dateTime = inGap.ToDateTimeUnspecified();
      expect(dateTime.isUtc, isFalse);
      expect(dateTime,
          core.DateTime(inGap.Year, inGap.Month, inGap.Day, inGap.Hour, inGap.Minute, inGap.Second, inGap.Millisecond));
      expect(LocalDateTime.FromDateTime(dateTime) == inGap, isFalse);
      expect(LocalDateTime.FromDateTime(dateTime), inGap.Plus(Period.FromSeconds(gapLength.inSeconds)));
    }, skip: noGap);

    test('LocalDateTime round trips around the transitions', () {
      for (var transition in transitions) {
        for (var deltaMinutes in [-120, -60, -1, 0, 1, 60, 120]) {
          var local = core.DateTime.fromMicrosecondsSinceEpoch(
              transition.utc.microsecondsSinceEpoch + deltaMinutes * core.Duration.microsecondsPerMinute);
          var ldt = local.ToLocalDateTime();
          var back = ldt.ToDateTimeUnspecified();
          expect(back.ToLocalDateTime(), ldt, reason: '$local');
          // In a fold, Dart's constructor may pick either instant; outside one, it's the same instant.
          if (back != local) {
            expect(back.timeZoneOffset != local.timeZoneOffset, isTrue, reason: '$local');
          }
        }
      }
    }, skip: transitions.isEmpty ? 'the local time zone has no transitions in 1990-2030' : null);
  });
}

Iterable<core.DateTime> sampleUtcDateTimes() sync* {
  yield core.DateTime.utc(-9998);
  yield core.DateTime.utc(0, 2, 29, 23, 59, 59, 999, 999);
  yield core.DateTime.utc(1);
  yield core.DateTime.utc(1, 1, 1, 0, 0, 0, 0, 1);
  yield core.DateTime.utc(1066, 10, 14, 9, 30, 1, 2, 3);
  yield core.DateTime.utc(1600, 2, 29, 12);
  yield core.DateTime.utc(1969, 12, 31, 23, 59, 59, 999, 999);
  yield core.DateTime.utc(1970);
  yield core.DateTime.utc(1970, 1, 1, 0, 0, 0, 0, 1);
  yield core.DateTime.utc(2000, 2, 29, 1, 2, 3, 4, 5);
  yield core.DateTime.utc(2038, 1, 19, 3, 14, 8);
  yield core.DateTime.utc(2262, 4, 11, 23, 47, 16, 854, 775);
  yield core.DateTime.utc(9999, 12, 31);
  yield lastMicrosecond;
  // Every month of a few years, at odd times.
  for (var year in [-500, 1582, 1752, 1900, 1999, 2024, 2100, 4000]) {
    for (var month = 1; month <= 12; month++) {
      yield core.DateTime.utc(year, month, month * 2, month, month * 4, month * 5, month * 80, month * 70 + 1);
    }
  }
}

/// Whether [ldt] is in a gap of the local zone, where Dart moves the time.
bool isInLocalGap(core.DateTime local, LocalDateTime ldt) =>
    local.year != ldt.Year || local.month != ldt.Month || local.day != ldt.Day || local.hour != ldt.Hour ||
    local.minute != ldt.Minute;

final class LocalTransition {
  LocalTransition(this.utc, this.offsetBefore, this.offsetAfter);

  final core.DateTime utc;
  final core.Duration offsetBefore;
  final core.Duration offsetAfter;
}

List<LocalTransition> localTransitions() {
  var result = <LocalTransition>[];
  core.Duration offsetAt(int ms) => core.DateTime.fromMillisecondsSinceEpoch(ms).timeZoneOffset;
  const msPerDay = 86400000;
  const msPerMinute = 60000;
  var start = core.DateTime.utc(1990).millisecondsSinceEpoch;
  var end = core.DateTime.utc(2030).millisecondsSinceEpoch;
  for (var day = start; day < end; day += msPerDay) {
    var before = offsetAt(day);
    var after = offsetAt(day + msPerDay);
    if (before == after) {
      continue;
    }
    // Binary search for the first minute with the new offset.
    var low = day;
    var high = day + msPerDay;
    while (high - low > msPerMinute) {
      var middle = low + ((high - low) ~/ msPerMinute ~/ 2) * msPerMinute;
      if (offsetAt(middle) == before) {
        low = middle;
      } else {
        high = middle;
      }
    }
    result.add(LocalTransition(core.DateTime.fromMillisecondsSinceEpoch(high, isUtc: true), before, offsetAt(high)));
  }
  return result;
}
