// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/TypeConvertersTest.cs
// Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator: .NET's TypeConverters have no Dart equivalent.

import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/TypeConvertersTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {});
}
