// noda_dart: new code. Runs NodaTime's test cases (test/scenarios) through the ported bodies; see test/README.md.

import 'dart:async';

import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:test/test.dart';

import '../scenarios/types.dart';
import 'Assertions.dart';
import 'Decode.dart';

/// Called with the case's arguments in C# order; returns the result for an ExpectedResult case.
typedef TestBody = dynamic Function(List<dynamic> args);

/// Whether this is dart2js (ints exact only to ±2^53).
const bool isDart2js = identical(1, 1.0);

/// One test per case; [bodies] are keyed by C# method name, or "Method(int, LocalDate)" for an overload.
/// [runExcluded] runs an excluded fixture's parameterless tests once each.
void port(ScenarioFixture fixture, Map<String, TestBody> bodies,
    {Map<String, String> skip = const {}, Map<String, CultureData>? cultures, bool runExcluded = false}) {
  if (cultures != null) {
    scenarioCultureData = cultures;
  }
  final used = <String>{};
  final usedSkips = <String>{};
  group(fixture.name, () {
    for (final test_ in fixture.tests) {
      final overloadKey = _overloadKeyOf(test_);
      final key = bodies.containsKey(overloadKey) ? overloadKey : bodies.containsKey(test_.method) ? test_.method : null;
      final body = key == null ? null : bodies[key];
      if (key != null) {
        used.add(key);
      }
      final skipKey = skip.containsKey(overloadKey) ? overloadKey : skip.containsKey(test_.method) ? test_.method : null;
      if (skipKey != null) {
        usedSkips.add(skipKey);
      }
      final label = '${test_.method} [${test_.source}]';
      final runAnyway = runExcluded && test_.parameters.isEmpty && test_.cases.isEmpty;
      final skipReason = (skipKey == null ? null : skip[skipKey]) ??
          (runAnyway ? null : fixture.excluded) ??
          (runAnyway ? null : test_.excluded) ??
          test_.ignored ??
          test_.notRunnable ??
          test_.skipped ??
          (test_.explicit ? 'explicit' : null);
      if (skipReason != null) {
        test(label, () {}, skip: skipReason);
        continue;
      }
      if (body == null) {
        test(label, () {}, skip: 'not ported');
        continue;
      }
      if (runAnyway || (test_.cases.length == 1 && test_.cases[0].args.isEmpty && test_.parameters.isEmpty)) {
        final case_ = runAnyway ? const ScenarioCase(args: []) : test_.cases[0];
        test(test_.method, () => _runCase(test_, case_, body), skip: _caseSkipReason(case_));
        continue;
      }
      group(test_.method, () {
        for (var index = 0; index < test_.cases.length; index++) {
          final case_ = test_.cases[index];
          test('#$index ${_caseLabel(case_)}', () => _runCase(test_, case_, body), skip: _caseSkipReason(case_));
        }
      });
    }
    // Catch typos: every supplied body (and skip entry) must match a NodaTime test method.
    test('has no bodies for unknown test methods', () {
      final unknown = [
        ...bodies.keys.where((k) => !used.contains(k)),
        ...skip.keys.where((k) => !usedSkips.contains(k)).map((k) => 'skip: $k'),
      ];
      if (unknown.isNotEmpty) {
        fail('Bodies with no matching test in ${fixture.name}: ${unknown.join(', ')}');
      }
    });
  });
}

String _overloadKeyOf(ScenarioTest test) {
  final types = test.parameters.map((p) => p.substring(0, p.lastIndexOf(' '))).join(', ');
  return '${test.method}($types)';
}

String? _caseSkipReason(ScenarioCase case_) =>
    case_.ignored ??
    case_.notRunnable ??
    case_.encodingError ??
    (case_.explicit ? 'explicit' : null) ??
    (isDart2js && !case_.dart2js ? 'an integer beyond ±2^53, which dart2js can\'t represent exactly' : null);

Future<void> _runCase(ScenarioTest test, ScenarioCase case_, TestBody body) async {
  final List<Object?> args;
  final Object? expected;
  try {
    args = case_.args.map(decode).toList();
    expected = case_.hasExpected ? decodeExpected(case_.expected) : null;
  } on UnsupportedValue catch (e) {
    markTestSkipped(e.message);
    return;
  }
  Object? actual;
  try {
    actual = body(args);
    if (actual is Future<Object?>) {
      actual = await actual;
    }
  } on UnsupportedValue catch (e) {
    markTestSkipped(e.message);
    return;
  } on IgnoreException catch (e) {
    markTestSkipped(e.message);
    return;
  }
  if (case_.hasExpected) {
    Assert.AreEqual(expected, actual, '${test.method} ExpectedResult');
  }
}

String _caseLabel(ScenarioCase case_) {
  final text = case_.description ?? render(case_.args);
  return text.length > 120 ? '${text.substring(0, 117)}...' : text;
}

/// Shared reasons for `skip:` entries.
abstract final class SkipReasons {
  static const String Xml = "XML serialization isn't ported";
  static const String NullSafety = "null safety: Dart's types don't allow the null argument";
  static const String UnaryPlus = "Dart has no unary + operator";
  static const String MinMaxValue = ".NET's IMinMaxValue<T> (generic math static interfaces) has no Dart equivalent";
  static const String DefaultConstructor =
      "C#'s default struct value (new T()) has no Dart equivalent: noda_dart's types have no parameterless constructor";
  static const String DateTimeOffset = "BCL interop (DateTimeOffset) isn't ported: Dart has no DateTimeOffset";
  static const String DateOnlyTimeOnly = "BCL interop (DateOnly, TimeOnly) isn't ported: Dart has no such types";
  static const String CurrentCulture =
      "CultureInfo.CurrentCulture can't be set in noda_dart (NodaCultureInfo.CurrentCulture is the host's language)";
  static const String BclFormatting = "Compares with .NET's own formatting (DateTime.ToString(pattern, culture)), which Dart doesn't have";
  static const String BclCalendar = "Uses a .NET System.Globalization calendar as the oracle; test/golden/calendars covers every year of every calendar";
  static const String Reflection = "Uses .NET reflection over NodaTime's assembly";

  /// For bodies (not arguments, which the generator marks) using integers beyond ±2^53.
  static const String Dart2jsInt = "Uses integers beyond ±2^53, which dart2js can't represent exactly";
}
