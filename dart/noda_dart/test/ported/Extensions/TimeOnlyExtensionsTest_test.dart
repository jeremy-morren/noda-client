// Ported from NodaTime 6e024dde: src/NodaTime.Test/Extensions/TimeOnlyExtensionsTest.cs
// Copyright 2022 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../../helpers/Scenarios.dart';
import '../../scenarios/Extensions/TimeOnlyExtensionsTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {}, skip: {
    'ToLocalTime': SkipReasons.DateOnlyTimeOnly,
  });
}
