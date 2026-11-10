// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler.Test/Tzdb/NameIdMappingSupportTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator (compares with the host's TimeZoneInfo names); nothing to port.

import '../../../helpers/Scenarios.dart';
import '../../../scenarios/TzdbCompiler/Tzdb/NameIdMappingSupportTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {});
}
