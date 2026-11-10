// Ported from NodaTime 6e024dde: src/NodaTime.Test/Extensions/TimeProviderExtensionsTest.cs
// Copyright 2024 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the C# class is TimeProviderOnlyExtensionsTest (scenarios/Extensions/TimeProviderOnlyExtensionsTest).

import '../../helpers/Scenarios.dart';
import '../../scenarios/Extensions/TimeProviderOnlyExtensionsTest.generated.dart' as scenarios;

const String _NotPorted = "BCL interop (TimeProvider) isn't ported: Dart has no TimeProvider";

void main() {
  port(scenarios.fixture, {}, skip: {
    'GetCurrentInstant': _NotPorted,
    'ToClock': _NotPorted,
    'ToZonedClock_Iso': _NotPorted,
    'ToZonedClock_Julian': _NotPorted,
    'ToZonedClock_ZoneChangeAfterConversionIsIgnored': _NotPorted,
  });
}
