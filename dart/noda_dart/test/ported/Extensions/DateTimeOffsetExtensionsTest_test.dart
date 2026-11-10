// Ported from NodaTime 6e024dde: src/NodaTime.Test/Extensions/DateTimeOffsetExtensionsTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../../helpers/Scenarios.dart';
import '../../scenarios/Extensions/DateTimeOffsetExtensionsTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {}, skip: {
    'ToZonedDateTime': SkipReasons.DateTimeOffset,
    'ToOffsetDateTime': SkipReasons.DateTimeOffset,
    'ToInstant': SkipReasons.DateTimeOffset,
  });
}
