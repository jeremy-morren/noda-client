// Ported from NodaTime 6e024dde: src/NodaTime.Test/Annotations/SecurityTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator (attribute/reflection checks on the .NET assembly).

import '../../helpers/Scenarios.dart';
import '../../scenarios/Annotations/SecurityTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {}, skip: {
    'SecurityAttributesOnInterfaceImplementations': SkipReasons.Reflection,
  });
}
