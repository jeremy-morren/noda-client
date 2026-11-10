// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/PatternNamingTest.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/PatternNamingTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {}, skip: {
    // https://github.com/nodatime/nodatime/issues/556
    'NoPatternSuffix': SkipReasons.Reflection,
  });
}
