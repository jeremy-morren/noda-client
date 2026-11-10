// Ported from NodaTime 6e024dde: src/NodaTime.Test/Utility/PreconditionsTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the scenarios are a release build, so the "NotDebug" variants (debug checks are off here too).

import 'package:noda_dart/src/Utility/Preconditions.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Utility/PreconditionsTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    // This overload is only called from one place, and only when it's going to fail...
    'CheckArgument2_Success': (args) {
      Preconditions.CheckArgument(true, 'param', '{0} is {1}', 1, 10);
    },

    'CheckArgument2_Failure': (args) {
      var exception = Assert.Throws<ArgumentError>(() => Preconditions.CheckArgument(false, 'param', '{0} is {1}', 1, 10));
      Assert.AreEqual('param', exception.name);
      Assert.IsTrue((exception.message as String).contains('1 is 10'));
    },

    // It's really not worth inventing parameters for these...
    'DebugCheckArgumentRange_NotDebug': (args) {
      Preconditions.DebugCheckArgumentRange('ignore', 5, 0, 10);
      Preconditions.DebugCheckArgumentRange('ignore', 5, 0, 10);
      Preconditions.DebugCheckArgumentRange('ignore', 10, 0, 5);
      Preconditions.DebugCheckArgumentRange('ignore', 10, 0, 5);
    },

    'DebugCheckNotNull_NotDebug': (args) {
      Preconditions.DebugCheckNotNull('value', 'ignore');
      Preconditions.DebugCheckNotNull(null as String?, 'ignore');
    },
  });
}
