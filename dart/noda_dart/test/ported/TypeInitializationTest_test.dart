// Ported from NodaTime 6e024dde: src/NodaTime.Test/TypeInitializationTest.cs
// Copyright 2020 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator: Dart initializes statics lazily and can't reload them.

import '../helpers/Scenarios.dart';
import '../scenarios/TypeInitializationTest.generated.dart' as scenarios;

const String _NotPorted = "Runs each type's static constructor in a new AssemblyLoadContext by reflection: Dart "
    'initializes static fields lazily and has no load contexts or reflection';

void main() {
  port(scenarios.fixture, {}, skip: {
    'InitializeType': _NotPorted,
    'GetProperties': _NotPorted,
  });
}
