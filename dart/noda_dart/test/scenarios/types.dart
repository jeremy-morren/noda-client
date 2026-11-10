// noda_dart: new code. Types of the generated scenarios (as ts/test/scenarios/types.ts).

/// One NUnit fixture (test class) of NodaTime.Test or NodaTime.TzdbCompiler.Test.
final class ScenarioFixture {
  const ScenarioFixture({required this.name, required this.source, this.excluded, required this.tests});

  /// NUnit full name, e.g. "NodaTime.Test.LocalDateTest".
  final String name;

  /// C# source file(s) of the fixture, relative to the NodaTime repo root.
  final String source;

  /// Why the fixture's cases weren't exported (tools/scenario-exclusions.txt).
  final String? excluded;

  final List<ScenarioTest> tests;
}

/// One test method. A plain [Test] has a single case with no arguments.
final class ScenarioTest {
  const ScenarioTest({
    required this.method,
    required this.source,
    this.parameters = const [],
    this.declaredIn,
    this.excluded,
    this.ignored,
    this.explicit = false,
    this.notRunnable,
    this.skipped,
    required this.cases,
  });

  final String method;

  /// "file:line" of the test body in the NodaTime repo.
  final String source;

  /// C# parameters, e.g. ["int days", "LocalDate expected"].
  final List<String> parameters;

  /// Base class declaring the method, when inherited (e.g. "PatternTestBase").
  final String? declaredIn;

  final String? excluded;
  final String? ignored;
  final bool explicit;
  final String? notRunnable;
  final String? skipped;
  final List<ScenarioCase> cases;
}

/// No ExpectedResult (as opposed to an expected `null`).
const Object noExpectedResult = _NoExpectedResult();

final class _NoExpectedResult {
  const _NoExpectedResult();

  @override
  String toString() => 'no expected result';
}

/// One case of a test method.
final class ScenarioCase {
  const ScenarioCase({
    required this.args,
    this.expected = noExpectedResult,
    this.description,
    this.ignored,
    this.explicit = false,
    this.notRunnable,
    this.encodingError,
    this.dart2js = true,
  });

  final List<EncodedValue> args;

  final EncodedValue expected;

  bool get hasExpected => !identical(expected, noExpectedResult);

  final String? description;
  final String? ignored;
  final bool explicit;
  final String? notRunnable;
  final String? encodingError;

  /// False when an integer is beyond ±2^53 (skipped on dart2js).
  final bool dart2js;
}

/// A primitive, a list, or a map tagged under `$` (`{r'$': 'LocalDate', 'year': 2024, ...}`), as noda-js encodes.
typedef EncodedValue = Object?;

typedef EncodedObject = Map<String, Object?>;
