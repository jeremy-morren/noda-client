// noda_dart: new code. Port of noda-js's ts/test/golden/calendars.test.ts: every year and month of every calendar
// matches NodaTime (standing in for NodaTime's BCL comparisons).

import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/src/YearMonthDay.dart';
import 'package:test/test.dart';

import 'types.dart';
import 'calendars/badi.generated.dart' as badi;
import 'calendars/coptic.generated.dart' as coptic;
import 'calendars/gregorian.generated.dart' as gregorian;
import 'calendars/hebrew-civil.generated.dart' as hebrew_civil;
import 'calendars/hebrew-scriptural.generated.dart' as hebrew_scriptural;
import 'calendars/hijri-astronomical-base15.generated.dart' as hijri_astronomical_base15;
import 'calendars/hijri-astronomical-base16.generated.dart' as hijri_astronomical_base16;
import 'calendars/hijri-astronomical-habashalhasib.generated.dart' as hijri_astronomical_habashalhasib;
import 'calendars/hijri-astronomical-indian.generated.dart' as hijri_astronomical_indian;
import 'calendars/hijri-civil-base15.generated.dart' as hijri_civil_base15;
import 'calendars/hijri-civil-base16.generated.dart' as hijri_civil_base16;
import 'calendars/hijri-civil-habashalhasib.generated.dart' as hijri_civil_habashalhasib;
import 'calendars/hijri-civil-indian.generated.dart' as hijri_civil_indian;
import 'calendars/iso.generated.dart' as iso;
import 'calendars/julian.generated.dart' as julian;
import 'calendars/persian-algorithmic.generated.dart' as persian_algorithmic;
import 'calendars/persian-arithmetic.generated.dart' as persian_arithmetic;
import 'calendars/persian-simple.generated.dart' as persian_simple;
import 'calendars/um-al-qura.generated.dart' as um_al_qura;

final List<CalendarGolden> goldens = [
  badi.golden,
  coptic.golden,
  gregorian.golden,
  hebrew_civil.golden,
  hebrew_scriptural.golden,
  hijri_astronomical_base15.golden,
  hijri_astronomical_base16.golden,
  hijri_astronomical_habashalhasib.golden,
  hijri_astronomical_indian.golden,
  hijri_civil_base15.golden,
  hijri_civil_base16.golden,
  hijri_civil_habashalhasib.golden,
  hijri_civil_indian.golden,
  iso.golden,
  julian.golden,
  persian_algorithmic.golden,
  persian_arithmetic.golden,
  persian_simple.golden,
  um_al_qura.golden,
]..sort((a, b) => a.id.compareTo(b.id));

// Mismatches are collected, not asserted per value (there are millions).
const int MaxReported = 10;

void Check(List<String> mismatches, String what, Object? actual, Object? expected) {
  if (actual != expected && mismatches.length < MaxReported) {
    mismatches.add('$what: $actual, expected $expected');
  }
}

String Describe(YearMonthDay ymd) => '${ymd.Year}-${ymd.Month}-${ymd.Day}';

void main() {
  test('covers every calendar system', () {
    expect(goldens.map((g) => g.id).toList(), CalendarSystem.Ids.toList()..sort());
  });

  for (final golden in goldens) {
    group(golden.id, () {
      CalendarSystem calendar() => CalendarSystem.ForId(golden.id);

      test('has the same range of years and days', () {
        expect({
          'MinYear': calendar().MinYear,
          'MaxYear': calendar().MaxYear,
          'MinDays': calendar().MinDays,
          'MaxDays': calendar().MaxDays,
        }, {
          'MinYear': golden.minYear,
          'MaxYear': golden.maxYear,
          'MinDays': golden.minDays,
          'MaxDays': golden.maxDays,
        });
      });

      test('agrees on every year: leap year, days, months, month lengths and the start of the year', () {
        final cal = calendar();
        final calculator = cal.YearMonthDayCalculator;
        final mismatches = <String>[];
        var startOfYear = golden.minDays;
        for (var year = golden.minYear; year <= golden.maxYear; year++) {
          final type = golden.yearTypes[golden.years[year - golden.minYear]];
          Check(mismatches, 'IsLeapYear($year)', cal.IsLeapYear(year), type.leap);
          Check(mismatches, 'GetDaysInYear($year)', cal.GetDaysInYear(year), type.days);
          Check(mismatches, 'GetMonthsInYear($year)', cal.GetMonthsInYear(year), type.monthLengths.length);
          Check(mismatches, 'GetStartOfYearInDays($year)', calculator.GetStartOfYearInDays(year), startOfYear);
          for (var month = 1; month <= type.monthLengths.length; month++) {
            Check(mismatches, 'GetDaysInMonth($year, $month)', cal.GetDaysInMonth(year, month), type.monthLengths[month - 1]);
          }
          startOfYear += type.days;
        }
        Check(mismatches, 'the day after the last year', startOfYear - 1, golden.maxDays);
        expect(mismatches, isEmpty);
      });

      test('converts the first and last day of every month to days since the epoch and back', () {
        final cal = calendar();
        final calculator = cal.YearMonthDayCalculator;
        final mismatches = <String>[];
        var startOfYear = golden.minDays;
        for (var year = golden.minYear; year <= golden.maxYear; year++) {
          final type = golden.yearTypes[golden.years[year - golden.minYear]];
          for (var month = 1; month <= type.monthLengths.length; month++) {
            final length = type.monthLengths[month - 1];
            final first = startOfYear + type.monthStarts[month - 1];
            for (final (day, days) in [(1, first), (length, first + length - 1)]) {
              final ymd = YearMonthDay.NewYearMonthDay(year, month, day);
              Check(mismatches, 'GetDaysSinceEpoch($year-$month-$day)', calculator.GetDaysSinceEpoch(ymd), days);
              Check(mismatches, 'GetYearMonthDay($days)', Describe(calculator.GetYearMonthDayDaysSinceEpoch(days)), Describe(ymd));
              Check(mismatches, 'GetDayOfYear($year-$month-$day)', calculator.GetDayOfYear(ymd), days - startOfYear + 1);
            }
          }
          startOfYear += type.days;
        }
        expect(mismatches, isEmpty);
      });
    });
  }
}
