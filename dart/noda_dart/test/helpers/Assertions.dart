// noda_dart: new code. NUnit's assertions over package:test, so ported tests read like the C#.
// Assert.Throws<T> requires the exact type, as in NUnit; Assert.Catch<T> accepts subtypes.

// ignore_for_file: non_constant_identifier_names

import 'dart:async';

import 'package:test/test.dart';

/// Thrown by [Assert.Ignore]; the harness reports the test as skipped.
final class IgnoreException implements Exception {
  final String message;

  IgnoreException(this.message);

  @override
  String toString() => 'Ignored: $message';
}

String _Prefix(String? message) => message == null || message.isEmpty ? '' : '$message\n';

String Describe(Object? value) {
  if (value is String) {
    return '"$value"';
  }
  if (value is Iterable<Object?> && value is! String) {
    return '< ${value.map(Describe).join(', ')} >';
  }
  try {
    return '$value';
  } catch (e) {
    return '<${value.runtimeType}: toString() threw $e>';
  }
}

/// NUnit's equality: numbers by value, collections element by element, maps entry by entry, else `==`.
bool AreEqualValues(Object? expected, Object? actual) {
  if (identical(expected, actual)) {
    return true;
  }
  if (expected == null || actual == null) {
    return false;
  }
  if (expected is num && actual is num) {
    return expected == actual || (expected.isNaN && actual.isNaN);
  }
  if (expected is String || actual is String) {
    return expected == actual;
  }
  if (expected is Map<Object?, Object?> && actual is Map<Object?, Object?>) {
    if (expected.length != actual.length) {
      return false;
    }
    for (final entry in expected.entries) {
      if (!actual.containsKey(entry.key) || !AreEqualValues(entry.value, actual[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (expected is Iterable<Object?> && actual is Iterable<Object?>) {
    final e = expected.iterator;
    final a = actual.iterator;
    while (true) {
      final hasE = e.moveNext();
      final hasA = a.moveNext();
      if (hasE != hasA) {
        return false;
      }
      if (!hasE) {
        return true;
      }
      if (!AreEqualValues(e.current, a.current)) {
        return false;
      }
    }
  }
  return expected == actual;
}

String _TypeName(Object? e) => e == null ? 'null' : '${e.runtimeType}';

/// NUnit's `Assert`.
abstract final class Assert {
  /// A [num] third argument is the tolerance.
  static void AreEqual(Object? expected, Object? actual, [Object? messageOrDelta, String? message]) {
    if (messageOrDelta is num) {
      final delta = messageOrDelta;
      if (expected is! num || actual is! num) {
        fail('${_Prefix(message)}AreEqual with a tolerance needs numbers: ${Describe(expected)}, ${Describe(actual)}');
      }
      if (!((expected - actual).abs() <= delta || expected == actual)) {
        fail('${_Prefix(message)}Expected: $expected +/- $delta\n  But was:  $actual');
      }
      return;
    }
    if (!AreEqualValues(expected, actual)) {
      fail('${_Prefix(messageOrDelta as String?)}Expected: ${Describe(expected)}\n  But was:  ${Describe(actual)}');
    }
  }

  static void AreNotEqual(Object? expected, Object? actual, [String? message]) {
    if (AreEqualValues(expected, actual)) {
      fail('${_Prefix(message)}Expected: not equal to ${Describe(expected)}\n  But was:  ${Describe(actual)}');
    }
  }

  static void AreSame(Object? expected, Object? actual, [String? message]) {
    if (!identical(expected, actual)) {
      fail('${_Prefix(message)}Expected: same as ${Describe(expected)}\n  But was:  ${Describe(actual)}');
    }
  }

  static void AreNotSame(Object? expected, Object? actual, [String? message]) {
    if (identical(expected, actual)) {
      fail('${_Prefix(message)}Expected: not same as ${Describe(expected)}\n  But was:  ${Describe(actual)}');
    }
  }

  static void IsTrue(bool condition, [String? message]) {
    if (!condition) {
      fail('${_Prefix(message)}Expected: True\n  But was:  False');
    }
  }

  static void True(bool condition, [String? message]) => IsTrue(condition, message);

  static void IsFalse(bool condition, [String? message]) {
    if (condition) {
      fail('${_Prefix(message)}Expected: False\n  But was:  True');
    }
  }

  static void False(bool condition, [String? message]) => IsFalse(condition, message);

  static void IsNull(Object? value, [String? message]) {
    if (value != null) {
      fail('${_Prefix(message)}Expected: null\n  But was:  ${Describe(value)}');
    }
  }

  static void Null(Object? value, [String? message]) => IsNull(value, message);

  static void IsNotNull(Object? value, [String? message]) {
    if (value == null) {
      fail('${_Prefix(message)}Expected: not null\n  But was:  null');
    }
  }

  static void NotNull(Object? value, [String? message]) => IsNotNull(value, message);

  static void IsEmpty(Object? value, [String? message]) {
    final empty = value is String ? value.isEmpty : value is Iterable<Object?> ? value.isEmpty : value is Map<Object?, Object?> ? value.isEmpty : false;
    if (!empty) {
      fail('${_Prefix(message)}Expected: <empty>\n  But was:  ${Describe(value)}');
    }
  }

  static void IsNotEmpty(Object? value, [String? message]) {
    final empty = value is String ? value.isEmpty : value is Iterable<Object?> ? value.isEmpty : value is Map<Object?, Object?> ? value.isEmpty : true;
    if (empty) {
      fail('${_Prefix(message)}Expected: not <empty>\n  But was:  ${Describe(value)}');
    }
  }

  static void Greater(Object? arg1, Object? arg2, [String? message]) {
    if (!(_Compare(arg1, arg2) > 0)) {
      fail('${_Prefix(message)}Expected: greater than ${Describe(arg2)}\n  But was:  ${Describe(arg1)}');
    }
  }

  static void GreaterOrEqual(Object? arg1, Object? arg2, [String? message]) {
    if (!(_Compare(arg1, arg2) >= 0)) {
      fail('${_Prefix(message)}Expected: greater than or equal to ${Describe(arg2)}\n  But was:  ${Describe(arg1)}');
    }
  }

  static void Less(Object? arg1, Object? arg2, [String? message]) {
    if (!(_Compare(arg1, arg2) < 0)) {
      fail('${_Prefix(message)}Expected: less than ${Describe(arg2)}\n  But was:  ${Describe(arg1)}');
    }
  }

  static void LessOrEqual(Object? arg1, Object? arg2, [String? message]) {
    if (!(_Compare(arg1, arg2) <= 0)) {
      fail('${_Prefix(message)}Expected: less than or equal to ${Describe(arg2)}\n  But was:  ${Describe(arg1)}');
    }
  }

  static int _Compare(Object? a, Object? b) {
    if (a is num && b is num) {
      return a.compareTo(b);
    }
    if (a is Comparable<Object?>) {
      return a.compareTo(b);
    }
    // ignore: avoid_dynamic_calls
    return (a as dynamic).compareTo(b) as int;
  }

  static void IsInstanceOf<T>(Object? value, [String? message]) {
    if (value is! T) {
      fail('${_Prefix(message)}Expected: instance of <$T>\n  But was:  <${_TypeName(value)}> ${Describe(value)}');
    }
  }

  static void IsNotInstanceOf<T>(Object? value, [String? message]) {
    if (value is T) {
      fail('${_Prefix(message)}Expected: not instance of <$T>\n  But was:  <${_TypeName(value)}>');
    }
  }

  static void Contains(Object? expected, Iterable<Object?> collection, [String? message]) {
    if (!collection.any((item) => AreEqualValues(expected, item))) {
      fail('${_Prefix(message)}Expected: collection containing ${Describe(expected)}\n  But was:  ${Describe(collection)}');
    }
  }

  static Never Fail([String? message]) => fail(message ?? 'Assert.Fail');

  static Never Ignore([String? message]) => throw IgnoreException(message ?? 'Ignored');

  /// A no-op (NUnit stops the test): return after calling it.
  static void Pass([String? message]) {}

  /// Stops at the first failure (NUnit collects them).
  static void Multiple(void Function() action) => action();

  static void DoesNotThrow(dynamic Function() action, [String? message]) {
    try {
      action();
    } catch (e) {
      fail('${_Prefix(message)}Expected: No Exception to be thrown\n  But was:  <${_TypeName(e)}> $e');
    }
  }

  /// Exactly type [T], as in NUnit. A returned Future isn't awaited: use [ThrowsAsync].
  static T Throws<T extends Object>(dynamic Function() action, [String? message]) {
    try {
      action();
    } catch (e) {
      if (e.runtimeType == T) {
        return e as T;
      }
      if (e is TestFailure) {
        rethrow;
      }
      fail('${_Prefix(message)}Expected: <$T>\n  But was:  <${_TypeName(e)}> $e');
    }
    fail('${_Prefix(message)}Expected: <$T>\n  But was:  no exception thrown');
  }

  static T Catch<T extends Object>(dynamic Function() action, [String? message]) {
    try {
      action();
    } catch (e) {
      if (e is T) {
        return e;
      }
      if (e is TestFailure) {
        rethrow;
      }
      fail('${_Prefix(message)}Expected: instance of <$T>\n  But was:  <${_TypeName(e)}> $e');
    }
    fail('${_Prefix(message)}Expected: instance of <$T>\n  But was:  no exception thrown');
  }

  static ArgumentError ThrowsArgumentNull(dynamic Function() action, [String? message]) {
    final e = Throws<ArgumentError>(action, message);
    if (!IsArgumentNull(e)) {
      fail('${_Prefix(message)}Expected: ArgumentError.notNull\n  But was:  $e');
    }
    return e;
  }

  static Future<T> ThrowsAsync<T extends Object>(Future<dynamic> Function() action, [String? message]) async {
    try {
      await action();
    } catch (e) {
      if (e.runtimeType == T) {
        return e as T;
      }
      if (e is TestFailure) {
        rethrow;
      }
      fail('${_Prefix(message)}Expected: <$T>\n  But was:  <${_TypeName(e)}> $e');
    }
    fail('${_Prefix(message)}Expected: <$T>\n  But was:  no exception thrown');
  }

  /// A constraint ([Is], [Throws], any [Matcher]), or a bool condition.
  static void That(Object? actual, [Object? constraintOrMessage, String? message]) {
    if (constraintOrMessage is Matcher) {
      expect(actual, constraintOrMessage, reason: message);
      return;
    }
    if (actual is bool) {
      IsTrue(actual, constraintOrMessage as String?);
      return;
    }
    fail('Assert.That needs a constraint (Is..., Throws...) or a bool, not ${Describe(actual)}');
  }
}

/// Whether [e] is `ArgumentError.notNull` (.NET's ArgumentNullException).
bool IsArgumentNull(Object? e) => e is ArgumentError && e.runtimeType == ArgumentError && e.message == 'Must not be null';

/// NUnit's `CollectionAssert`.
abstract final class CollectionAssert {
  static void AreEqual(Iterable<Object?> expected, Iterable<Object?> actual, [String? message]) {
    if (!AreEqualValues(expected.toList(), actual.toList())) {
      fail('${_Prefix(message)}Expected: ${Describe(expected)}\n  But was:  ${Describe(actual)}');
    }
  }

  static void AreNotEqual(Iterable<Object?> expected, Iterable<Object?> actual, [String? message]) {
    if (AreEqualValues(expected.toList(), actual.toList())) {
      fail('${_Prefix(message)}Expected: not ${Describe(expected)}\n  But was:  ${Describe(actual)}');
    }
  }

  static void AreEquivalent(Iterable<Object?> expected, Iterable<Object?> actual, [String? message]) {
    final remaining = actual.toList();
    var ok = expected.length == remaining.length;
    if (ok) {
      for (final item in expected) {
        final index = remaining.indexWhere((x) => AreEqualValues(item, x));
        if (index == -1) {
          ok = false;
          break;
        }
        remaining.removeAt(index);
      }
    }
    if (!ok) {
      fail('${_Prefix(message)}Expected: equivalent to ${Describe(expected)}\n  But was:  ${Describe(actual)}');
    }
  }

  static void IsEmpty(Iterable<Object?> collection, [String? message]) => Assert.IsEmpty(collection, message);

  static void IsNotEmpty(Iterable<Object?> collection, [String? message]) => Assert.IsNotEmpty(collection, message);

  static void Contains(Iterable<Object?> collection, Object? expected, [String? message]) =>
      Assert.Contains(expected, collection, message);

  static void IsOrdered(Iterable<Object?> collection, [int Function(Object? x, Object? y)? compare, String? message]) {
    final list = collection.toList();
    for (var i = 1; i < list.length; i++) {
      final result = compare != null ? compare(list[i - 1], list[i]) : Assert._Compare(list[i - 1], list[i]);
      if (result > 0) {
        fail('${_Prefix(message)}Expected: collection ordered\n  But was:  ${Describe(list)} (index $i)');
      }
    }
  }

  static void AllItemsAreUnique(Iterable<Object?> collection, [String? message]) {
    final list = collection.toList();
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        if (AreEqualValues(list[i], list[j])) {
          fail('${_Prefix(message)}Expected: all items unique\n  But was:  ${Describe(list)}');
        }
      }
    }
  }
}

/// NUnit's `StringAssert`.
abstract final class StringAssert {
  static void Contains(String expected, String actual, [String? message]) {
    if (!actual.contains(expected)) {
      fail('${_Prefix(message)}Expected: String containing ${Describe(expected)}\n  But was:  ${Describe(actual)}');
    }
  }

  static void StartsWith(String expected, String actual, [String? message]) {
    if (!actual.startsWith(expected)) {
      fail('${_Prefix(message)}Expected: String starting with ${Describe(expected)}\n  But was:  ${Describe(actual)}');
    }
  }

  static void EndsWith(String expected, String actual, [String? message]) {
    if (!actual.endsWith(expected)) {
      fail('${_Prefix(message)}Expected: String ending with ${Describe(expected)}\n  But was:  ${Describe(actual)}');
    }
  }
}

final class _AreEqualMatcher extends Matcher {
  final Object? _expected;

  const _AreEqualMatcher(this._expected);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) => AreEqualValues(_expected, item);

  @override
  Description describe(Description description) => description.add('equal to ${Describe(_expected)}');
}

final class _ComparisonMatcher extends Matcher {
  final Object? _value;
  final bool Function(int comparison) _test;
  final String _description;

  const _ComparisonMatcher(this._value, this._test, this._description);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) => _test(Assert._Compare(item, _value));

  @override
  Description describe(Description description) => description.add('$_description ${Describe(_value)}');
}

final class _ExactTypeMatcher<T> extends Matcher {
  const _ExactTypeMatcher();

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) => item.runtimeType == T;

  @override
  Description describe(Description description) => description.add('exactly <$T>');
}

/// NUnit's `Is` constraints, for [Assert.That].
abstract final class Is {
  static Matcher EqualTo(Object? expected) => _AreEqualMatcher(expected);
  static Matcher SameAs(Object? expected) => same(expected);
  static Matcher GreaterThan(Object? value) => _ComparisonMatcher(value, (c) => c > 0, 'greater than');
  static Matcher GreaterThanOrEqualTo(Object? value) => _ComparisonMatcher(value, (c) => c >= 0, 'greater than or equal to');
  static Matcher LessThan(Object? value) => _ComparisonMatcher(value, (c) => c < 0, 'less than');
  static Matcher LessThanOrEqualTo(Object? value) => _ComparisonMatcher(value, (c) => c <= 0, 'less than or equal to');
  static Matcher InRange(Object? from, Object? to) => allOf(GreaterThanOrEqualTo(from), LessThanOrEqualTo(to));
  static Matcher InstanceOf<T>() => isA<T>();
  static Matcher TypeOf<T>() => _ExactTypeMatcher<T>();
  static const Matcher True = isTrue;
  static const Matcher False = isFalse;
  static const Matcher Null = isNull;
  static const Matcher Empty = isEmpty;
  static const Matcher NaN = isNaN;

  static const IsNot Not = IsNot._();
}

/// NUnit's `Is.Not` constraints.
final class IsNot {
  const IsNot._();

  Matcher get Null => isNotNull;
  Matcher get Empty => isNotEmpty;
  Matcher EqualTo(Object? expected) => isNot(Is.EqualTo(expected));
  Matcher SameAs(Object? expected) => isNot(same(expected));
  Matcher InstanceOf<T>() => isNot(isA<T>());
}

/// NUnit's `Throws` constraints, for [Assert.That] on an action.
abstract final class Throws {
  static Matcher TypeOf<T>() => throwsA(_ExactTypeMatcher<T>());

  static Matcher InstanceOf<T>() => throwsA(isA<T>());

  static final Matcher Nothing = returnsNormally;
}
