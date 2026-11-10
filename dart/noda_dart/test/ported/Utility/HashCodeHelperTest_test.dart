// Ported from NodaTime 6e024dde: src/NodaTime.Test/Utility/HashCodeHelperTest.cs
// Copyright 2026 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the static Hash overloads are HashStatic (no static and instance member of the same name).

import 'package:noda_dart/src/Utility/HashCodeHelper.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Utility/HashCodeHelperTest.generated.dart' as scenarios;

// Most aspects are effectively tested indirectly. This test is just to add coverage.
void main() {
  port(scenarios.fixture, {
    'Hash_Nulls': (args) {
      // The constants in HashCodeHelper aren't internal as we don't want to expose them in the assembly.
      // But really, we're never going to change them either.
      Assert.AreEqual(17 * 37, HashCodeHelper.Initialize().Hash<String?>(null).Value);
      Assert.AreEqual(17 * 37 * 37, HashCodeHelper.HashStatic(null, null));
      Assert.AreEqual(17 * 37 * 37 * 37, HashCodeHelper.HashStatic(null, null, null));
    },
  });
}
