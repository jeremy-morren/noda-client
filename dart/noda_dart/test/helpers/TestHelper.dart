// Ported from NodaTime 6e024dde: src/NodaTime.Test/TestHelper.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the 1-3 argument overloads are one method each (Function.apply); operators are called dynamically, a
// missing one skipped as C#'s reflection does.

// ignore_for_file: avoid_dynamic_calls

import 'package:noda_dart/src/Utility/Comparers.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';

import 'Assertions.dart';

/// Marks an optional argument as not given (null is a valid argument).
const Object _none = _None();

final class _None {
  const _None();
}

/// `TestHelper.Consume(this T ignored)`: lets a value appear to be used (`value.Consume();`).
extension TestHelperConsume<T> on T {
  /// Does nothing other than let us prove method or constructor calls don't throw.
  void Consume() {}
}

/// Provides methods to help run tests for some of the system interfaces and object support.
abstract final class TestHelper {
  static bool get IsRunningOnMono => false;

  static bool get IsRunningOnDotNetCoreUnix => false;

  /// Does nothing other than let us prove method or constructor calls don't throw.
  static void Consume<T>(T ignored) {}

  static Object? _Apply(Function func, Object? arg1, Object? arg2, Object? arg3) =>
      Function.apply(func, [arg1, arg2, arg3].where((a) => !identical(a, _none)).toList());

  /// Asserts that calling the specified delegate with the specified value(s) throws ArgumentException.
  static void AssertInvalid(Function func, Object? arg1, [Object? arg2 = _none, Object? arg3 = _none]) {
    final e = Assert.Throws<ArgumentError>(() => _Apply(func, arg1, arg2, arg3));
    // noda_dart: ArgumentNullException is ArgumentError.notNull, the same Dart type.
    Assert.IsFalse(IsArgumentNull(e), 'Expected ArgumentException, but was ArgumentNullException: $e');
  }

  /// Asserts that calling the specified delegate with the specified value(s) throws ArgumentNullException.
  static void AssertArgumentNull(Function func, Object? arg1, [Object? arg2 = _none, Object? arg3 = _none]) {
    Assert.ThrowsArgumentNull(() => _Apply(func, arg1, arg2, arg3));
  }

  /// Asserts that calling the specified delegate with the specified value(s) throws ArgumentOutOfRangeException.
  static void AssertOutOfRange(Function func, Object? arg1, [Object? arg2 = _none, Object? arg3 = _none]) {
    Assert.Throws<RangeError>(() => _Apply(func, arg1, arg2, arg3));
  }

  /// Asserts that calling the specified delegate with the specified value(s) doesn't throw an exception.
  static void AssertValid(Function func, Object? arg1, [Object? arg2 = _none, Object? arg3 = _none]) {
    _Apply(func, arg1, arg2, arg3);
  }

  /// Typically used to report a list of items (e.g. reflection members) that fail a condition, one per line.
  static void AssertNoFailures<T>(Iterable<T> failures, String Function(T) failureFormatter) {
    var failureList = failures.toList();
    if (failureList.isEmpty) {
      return;
    }
    var newLine = '\n';
    var message = 'Failures: ${failureList.length}$newLine${failureList.map(failureFormatter).join(newLine)}';
    Assert.Fail(message);
  }

  // noda_dart: not ported: AssertNoFailures with a TestExemptionCategory, IsExempt (reflection).

  /// Asserts that the given operation throws one of InvalidOperationException, ArgumentException (including
  /// ArgumentOutOfRangeException) or OverflowException. (It's hard to always be consistent bearing in mind
  /// one method calling another.)
  ///
  /// noda_dart: both C# overloads: `AssertOverflow(action)` and `AssertOverflow(func, arg1)`.
  static void AssertOverflow(Function funcOrAction, [Object? arg1 = _none]) {
    try {
      _Apply(funcOrAction, arg1, _none, _none);
    } catch (e) {
      if (e is OverflowException || e is StateError) {
        return;
      }
      if (e is ArgumentError) {
        Assert.IsTrue((e.runtimeType == ArgumentError && !IsArgumentNull(e)) || e.runtimeType == RangeError,
            'Exception should not be a subtype of ArgumentException, other than ArgumentOutOfRangeException');
        return;
      }
      rethrow;
    }
    Assert.Fail('Expected OverflowException, ArgumentException, ArgumentOutOfRangeException or InvalidOperationException');
  }

  static void TestComparerStruct<T>(IComparer<T> comparer, T value, T equalValue, T greaterValue) {
    Assert.AreEqual(0, comparer.Compare(value, equalValue));
    Assert.AreEqual(1, comparer.Compare(greaterValue, value).sign);
    Assert.AreEqual(-1, comparer.Compare(value, greaterValue).sign);
  }

  /// Tests the [IComparable{T}.CompareTo] method for reference objects.
  ///
  /// [T]: The type to test.
  /// [value]: The base value.
  /// [equalValue]: The value equal to but not the same object as the base value.
  /// [greaterValues]: The values greater than the base value, in ascending order.
  static void TestCompareToClass<T extends Comparable<T>>(T value, T equalValue, List<T> greaterValues) {
    _ValidateInput(value, equalValue, greaterValues, 'greaterValue', checkNotSame: true);
    Assert.Greater((value as dynamic).CompareTo(null), 0, 'value.CompareTo<T>(null)');
    Assert.AreEqual(value.compareTo(value), 0, 'value.CompareTo<T>(value)');
    Assert.AreEqual(value.compareTo(equalValue), 0, 'value.CompareTo<T>(equalValue)');
    Assert.AreEqual(equalValue.compareTo(value), 0, 'equalValue.CompareTo<T>(value)');
    for (var greaterValue in greaterValues) {
      Assert.Less(value.compareTo(greaterValue), 0, 'value.CompareTo<T>(greaterValue)');
      Assert.Greater(greaterValue.compareTo(value), 0, 'greaterValue.CompareTo<T>(value)');
      // Now move up to the next pair...
      value = greaterValue;
    }
  }

  /// Tests the [IComparable{T}.CompareTo] method for value objects.
  ///
  /// [T]: The type to test.
  /// [value]: The base value.
  /// [equalValue]: The value equal to but not the same object as the base value.
  /// [greaterValues]: The values greater than the base value, in ascending order.
  static void TestCompareToStruct<T extends Comparable<T>>(T value, T equalValue, List<T> greaterValues) {
    Assert.AreEqual(value.compareTo(value), 0, 'value.CompareTo(value)');
    Assert.AreEqual(value.compareTo(equalValue), 0, 'value.CompareTo(equalValue)');
    Assert.AreEqual(equalValue.compareTo(value), 0, 'equalValue.CompareTo(value)');
    for (var greaterValue in greaterValues) {
      Assert.Less(value.compareTo(greaterValue), 0, 'value.CompareTo(greaterValue)');
      Assert.Greater(greaterValue.compareTo(value), 0, 'greaterValue.CompareTo(value)');
      // Now move up to the next pair...
      value = greaterValue;
    }
  }

  /// Tests the [IComparable.CompareTo] method - note that this is the non-generic interface.
  ///
  /// [T]: The type to test.
  /// [value]: The base value.
  /// [equalValue]: The value equal to but not the same object as the base value.
  /// [greaterValues]: The values greater than the base value, in ascending order.
  static void TestNonGenericCompareTo<T>(T value, T equalValue, List<T> greaterValues) {
    // Just type the values as plain IComparable for simplicity
    dynamic value2 = value;
    dynamic equalValue2 = equalValue;

    _ValidateInput(value2, equalValue2, greaterValues, 'greaterValues');
    Assert.Greater(value2.CompareTo(null), 0, 'value.CompareTo(null)');
    Assert.AreEqual(value2.CompareTo(value2), 0, 'value.CompareTo(value)');
    Assert.AreEqual(value2.CompareTo(equalValue2), 0, 'value.CompareTo(equalValue)');
    Assert.AreEqual(equalValue2.CompareTo(value2), 0, 'equalValue.CompareTo(value)');

    for (dynamic greaterValue in greaterValues) {
      Assert.Less(value2.CompareTo(greaterValue), 0, 'value.CompareTo(greaterValue)');
      Assert.Greater(greaterValue.CompareTo(value2), 0, 'greaterValue.CompareTo(value)');
      // Now move up to the next pair...
      value2 = greaterValue;
    }
    Assert.Throws<ArgumentError>(() => value2.CompareTo(Object()));
  }

  /// Tests the IEquatable.Equals method for reference objects. Also tests the
  /// object equals method.
  ///
  /// [T]: The type to test.
  /// [value]: The base value.
  /// [equalValue]: The value equal to but not the same object as the base value.
  /// [unequalValues]: Values not equal to the base value.
  static void TestEqualsClass<T extends Object>(T value, T equalValue, List<T> unequalValues) {
    _TestObjectEquals(value, equalValue, unequalValues, checkNotSame: true);
    dynamic dynamicValue = value;
    Assert.False(dynamicValue.Equals(null) as bool, 'value.Equals<T>(null)');
    Assert.True(dynamicValue.Equals(value) as bool, 'value.Equals<T>(value)');
    Assert.True(dynamicValue.Equals(equalValue) as bool, 'value.Equals<T>(equalValue)');
    Assert.True((equalValue as dynamic).Equals(value) as bool, 'equalValue.Equals<T>(value)');
    for (var unequal in unequalValues) {
      Assert.False(dynamicValue.Equals(unequal) as bool, 'value.Equals<T>(unequalValue)');
    }
  }

  /// Tests the IEquatable.Equals method for value objects. Also tests the
  /// object equals method.
  ///
  /// [T]: The type to test.
  /// [value]: The base value.
  /// [equalValue]: The value equal to but not the same object as the base value.
  /// [unequalValues]: The value not equal to the base value.
  static void TestEqualsStruct<T extends Object>(T value, T equalValue, List<T> unequalValues) {
    var unequalArray = unequalValues.cast<Object>().toList();
    TestObjectEquals(value, equalValue, unequalArray);
    dynamic dynamicValue = value;
    Assert.True(dynamicValue.Equals(value) as bool, 'value.Equals<T>(value)');
    Assert.True(dynamicValue.Equals(equalValue) as bool, 'value.Equals<T>(equalValue)');
    Assert.True((equalValue as dynamic).Equals(value) as bool, 'equalValue.Equals<T>(value)');
    for (var unequalValue in unequalValues) {
      Assert.False(dynamicValue.Equals(unequalValue) as bool, 'value.Equals<T>(unequalValue)');
    }
  }

  /// Tests the Object.Equals method.
  ///
  /// It takes two equal values, and then an array of values which should not be equal to the first argument.
  ///
  /// [value]: The base value.
  /// [equalValue]: The value equal to but not the same object as the base value.
  /// [unequalValues]: The value not equal to the base value.
  static void TestObjectEquals(Object? value, Object? equalValue, List<Object?> unequalValues) =>
      _TestObjectEquals(value, equalValue, unequalValues, checkNotSame: false);

  static void _TestObjectEquals(Object? value, Object? equalValue, List<Object?> unequalValues,
      {required bool checkNotSame}) {
    _ValidateInput(value, equalValue, unequalValues, 'unequalValue', checkNotSame: checkNotSame);
    // noda_dart: Dart's == never passes null to operator ==, so this checks the language's rule.
    Assert.False(value == null, 'value.Equals(null)');
    Assert.True(value == value, 'value.Equals(value)');
    Assert.True(value == equalValue, 'value.Equals(equalValue)');
    Assert.True(equalValue == value, 'equalValue.Equals(value)');
    for (var unequalValue in unequalValues) {
      Assert.False(value == unequalValue, 'value.Equals(unequalValue)');
    }
    Assert.AreEqual(value.hashCode, value.hashCode, 'GetHashCode() twice for same object');
    Assert.AreEqual(value.hashCode, equalValue.hashCode, 'GetHashCode() for two different but equal objects');
    Assert.False(value == Object(), 'Equals with the wrong type');
  }

  /// Calls a binary operator dynamically; null if the type doesn't have it (as C#'s GetMethod("op_...") returns null).
  static bool? _Operator(String op, dynamic left, dynamic right) {
    try {
      return switch (op) {
        '>' => left > right,
        '<' => left < right,
        '>=' => left >= right,
        '<=' => left <= right,
        _ => throw ArgumentError(op),
      } as bool;
    } on NoSuchMethodError {
      return null;
    }
  }

  static bool _HasOperator(String op, Object? value) => _Operator(op, value, value) != null;

  /// Tests the less than (&lt;) and greater than (&gt;) operators if they exist on the object.
  ///
  /// [T]: The type to test.
  /// [value]: The base value.
  /// [equalValue]: The value equal to but not the same object as the base value.
  /// [greaterValues]: The values greater than the base value, in ascending order.
  static void TestOperatorComparison<T extends Object>(T value, T equalValue, List<T> greaterValues) {
    _ValidateInput(value, equalValue, greaterValues, 'greaterValue');
    var greaterThan = _HasOperator('>', value);
    var lessThan = _HasOperator('<', value);

    // Comparisons only involving equal values
    if (greaterThan) {
      // noda_dart: not ported: the null checks (Dart's operators don't take null).
      Assert.False(_Operator('>', value, value)!, 'value > value');
      Assert.False(_Operator('>', value, equalValue)!, 'value > equalValue');
      Assert.False(_Operator('>', equalValue, value)!, 'equalValue > value');
    }
    if (lessThan) {
      Assert.False(_Operator('<', value, value)!, 'value < value');
      Assert.False(_Operator('<', value, equalValue)!, 'value < equalValue');
      Assert.False(_Operator('<', equalValue, value)!, 'equalValue < value');
    }

    // Then comparisons involving the greater values
    for (var greaterValue in greaterValues) {
      if (greaterThan) {
        Assert.False(_Operator('>', value, greaterValue)!, 'value > greaterValue');
        Assert.True(_Operator('>', greaterValue, value)!, 'greaterValue > value');
      }
      if (lessThan) {
        Assert.True(_Operator('<', value, greaterValue)!, 'value < greaterValue');
        Assert.False(_Operator('<', greaterValue, value)!, 'greaterValue < value');
      }
      // Now move up to the next pair...
      value = greaterValue;
    }
  }

  /// Tests the equality (==), inequality (!=), less than (&lt;), greater than (&gt;), less than or equals (&lt;=),
  /// and greater than or equals (&gt;=) operators if they exist on the object.
  ///
  /// [T]: The type to test.
  /// [value]: The base value.
  /// [equalValue]: The value equal to but not the same object as the base value.
  /// [greaterValues]: The values greater than the base value, in ascending order.
  static void TestOperatorComparisonEquality<T extends Object>(T value, T equalValue, List<T> greaterValues) {
    for (var greaterValue in greaterValues) {
      TestOperatorEquality(value, equalValue, greaterValue);
    }
    TestOperatorComparison(value, equalValue, greaterValues);
    var greaterThanOrEqual = _HasOperator('>=', value);
    var lessThanOrEqual = _HasOperator('<=', value);

    // First the comparisons with equal values
    if (greaterThanOrEqual) {
      Assert.True(_Operator('>=', value, value)!, 'value >= value');
      Assert.True(_Operator('>=', value, equalValue)!, 'value >= equalValue');
      Assert.True(_Operator('>=', equalValue, value)!, 'equalValue >= value');
    }
    if (lessThanOrEqual) {
      Assert.True(_Operator('<=', value, value)!, 'value <= value');
      Assert.True(_Operator('<=', value, equalValue)!, 'value <= equalValue');
      Assert.True(_Operator('<=', equalValue, value)!, 'equalValue <= value');
    }

    // Now the "greater than" values
    for (var greaterValue in greaterValues) {
      if (greaterThanOrEqual) {
        Assert.False(_Operator('>=', value, greaterValue)!, 'value >= greaterValue');
        Assert.True(_Operator('>=', greaterValue, value)!, 'greaterValue >= value');
      }
      if (lessThanOrEqual) {
        Assert.True(_Operator('<=', value, greaterValue)!, 'value <= greaterValue');
        Assert.False(_Operator('<=', greaterValue, value)!, 'greaterValue <= value');
      }
      // Now move up to the next pair...
      value = greaterValue;
    }
  }

  /// Tests the equality and inequality operators (==, !=) on the object.
  ///
  /// [T]: The type to test.
  /// [value]: The base value.
  /// [equalValue]: The value equal to but not the same object as the base value.
  /// [unequalValue]: The value not equal to the base value.
  static void TestOperatorEquality<T extends Object>(T value, T equalValue, T unequalValue) {
    _ValidateInput(value, equalValue, [unequalValue], 'unequalValue');
    Assert.True(value == value, 'value == value');
    Assert.True(value == equalValue, 'value == equalValue');
    Assert.True(equalValue == value, 'equalValue == value');
    Assert.False(value == unequalValue, 'value == unequalValue');

    Assert.False(value != value, 'value != value');
    Assert.False(value != equalValue, 'value != equalValue');
    Assert.False(equalValue != value, 'equalValue != value');
    Assert.True(value != unequalValue, 'value != unequalValue');
  }

  // noda_dart: not ported: AssertMinMaxValue (generic math static interfaces).

  // noda_dart: not ported: the XML assertions.

  /// Validates that the input parameters to the test methods are valid.
  ///
  /// [value]: The base value.
  /// [equalValue]: The value equal to but not the same object as the base value.
  /// [unequalValues]: The values not equal to the base value.
  /// [unequalName]: The name to use in "not equal value" error messages.
  ///
  /// noda_dart: AreNotSame only for the Class variants ([checkNotSame]): Dart doesn't box structs.
  static void _ValidateInput(Object? value, Object? equalValue, List<Object?> unequalValues, String unequalName,
      {bool checkNotSame = false}) {
    Assert.NotNull(value, 'value cannot be null in TestObjectEquals() method');
    Assert.NotNull(equalValue, 'equalValue cannot be null in TestObjectEquals() method');
    if (checkNotSame) {
      Assert.AreNotSame(value, equalValue, 'value and equalValue MUST be different objects');
    }
    for (var unequalValue in unequalValues) {
      Assert.NotNull(unequalValue, '$unequalName cannot be null in TestObjectEquals() method');
      if (checkNotSame) {
        Assert.AreNotSame(value, unequalValue, '$unequalName and value MUST be different objects');
      }
    }
  }
}

// noda_dart: not ported: SerializationHelper<T> (XML).
