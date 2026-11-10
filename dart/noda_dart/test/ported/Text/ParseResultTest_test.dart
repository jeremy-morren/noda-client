// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/ParseResultTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: ParseResult<int>.ForValue(x) is ParseResult.ForValue<int>(x) (statics can't use the class's type parameter).

import 'package:noda_dart/src/Text/ParseResult.dart';
import 'package:noda_dart/src/Text/UnparsableValueException.dart';
import 'package:noda_dart/src/Text/ValueCursor.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/ParseResultTest.generated.dart' as scenarios;

final ParseResult<int> FailureResult = ParseResult.ForInvalidValue<int>(ValueCursor.NewValue('text'), 'text');

void main() {
  port(scenarios.fixture, {
    'Value_Success': (args) {
      ParseResult<int> result = ParseResult.ForValue<int>(5);
      Assert.AreEqual(5, result.Value);
    },

    'Value_Failure': (args) {
      var exception = Assert.Throws<UnparsableValueException>(() => FailureResult.Value.hashCode);
      Assert.AreEqual('text', exception.Value);
      Assert.AreEqual(-1, exception.Index);
    },

    'Exception_Success': (args) {
      ParseResult<int> result = ParseResult.ForValue<int>(5);
      Assert.Throws<StateError>(() => result.Exception.hashCode);
    },

    'Exception_Failure': (args) {
      Assert.IsInstanceOf<UnparsableValueException>(FailureResult.Exception);
      Assert.AreEqual('text', (FailureResult.Exception as UnparsableValueException).Value);
      Assert.AreEqual(-1, (FailureResult.Exception as UnparsableValueException).Index);
    },

    'GetValueOrThrow_Success': (args) {
      ParseResult<int> result = ParseResult.ForValue<int>(5);
      Assert.AreEqual(5, result.GetValueOrThrow());
    },

    'GetValueOrThrow_Failure': (args) {
      var exception = Assert.Throws<UnparsableValueException>(() => FailureResult.GetValueOrThrow());
      Assert.AreEqual('text', exception.Value);
      Assert.AreEqual(-1, exception.Index);
    },

    'TryGetValue_Success': (args) {
      ParseResult<int> result = ParseResult.ForValue<int>(5);
      final (bool success, int actual) = result.TryGetValue(-1);
      Assert.IsTrue(success);
      Assert.AreEqual(5, actual);
    },

    'TryGetValue_Failure': (args) {
      final (bool success, int actual) = FailureResult.TryGetValue(-1);
      Assert.IsFalse(success);
      Assert.AreEqual(-1, actual);
    },

    'Convert_ForFailureResult': (args) {
      ParseResult<String> converted = FailureResult.Convert((x) => 'xx${x}xx');
      var exception = Assert.Throws<UnparsableValueException>(() => converted.GetValueOrThrow());
      Assert.AreEqual('text', exception.Value);
      Assert.AreEqual(-1, exception.Index);
    },

    'Convert_ForSuccessResult': (args) {
      ParseResult<int> original = ParseResult.ForValue<int>(10);
      ParseResult<String> converted = original.Convert((x) => 'xx${x}xx');
      Assert.AreEqual('xx10xx', converted.Value);
    },

    'ConvertError_ForFailureResult': (args) {
      ParseResult<String> converted = FailureResult.ConvertError<String>();
      var exception = Assert.Throws<UnparsableValueException>(() => converted.GetValueOrThrow());
      Assert.AreEqual('text', exception.Value);
      Assert.AreEqual(-1, exception.Index);
    },

    'ConvertError_ForSuccessResult': (args) {
      ParseResult<int> original = ParseResult.ForValue<int>(10);
      Assert.Throws<StateError>(() => original.ConvertError<String>());
    },

    'ForException': (args) {
      Exception e = Exception();
      ParseResult<int> result = ParseResult.ForException<int>(() => e);
      Assert.IsFalse(result.Success);
      Assert.AreSame(e, result.Exception);
    },
  });
}
