// Ported from NodaTime 6e024dde: src/NodaTime.Test/ExceptionConstructorTests.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator; ported anyway.

import 'package:noda_dart/src/Text/InvalidPatternException.dart';
import 'package:noda_dart/src/Text/UnparsableValueException.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../scenarios/ExceptionConstructorTests.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    // We never actually use this constructor, but it's in the public API and it's harmless...
    'InvalidPatternExceptionParameterlessConstructor': (args) {
      var exception = InvalidPatternException();
          // noda_dart: .NET's default message (Dart's FormatException has none).
      Assert.AreEqual('One of the identified items was in an invalid format.', exception.message);
    },

    // We never actually use these constructors, but they're in the public API and we don't want to create
    // a breaking change. They're obsolete to discourage external use though, as we want an UnparsableValueException
    // to always have a value.
    'UnparsableValueObsoleteConstructors': (args) {
      var exceptions = [
        // ignore: deprecated_member_use
        UnparsableValueException.MessageInnerException(),
        // ignore: deprecated_member_use
        UnparsableValueException.MessageInnerException('message'),
        // ignore: deprecated_member_use
        UnparsableValueException.MessageInnerException('message', Exception()),
      ];

      for (var exception in exceptions) {
        Assert.IsEmpty(exception.Value);
        Assert.AreEqual(-1, exception.Index);
      }
    },
  });
}
