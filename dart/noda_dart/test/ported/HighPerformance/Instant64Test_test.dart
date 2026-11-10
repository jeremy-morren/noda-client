// Ported from NodaTime 6e024dde: src/NodaTime.Test/HighPerformance/Instant64Test.cs (+ Instant64Test.Operators.cs)
// Copyright 2025 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator (NodaTime.HighPerformance isn't ported).

import '../../helpers/Scenarios.dart';
import '../../scenarios/HighPerformance/Instant64Test.generated.dart' as scenarios;

const String _NotPorted = "NodaTime.HighPerformance (Duration64, Instant64) isn't ported: .NET-specific performance types";

void main() {
  port(scenarios.fixture, {}, skip: {
    'MinMax_IsoCalendar': _NotPorted,
    'FromInstant_Extreme': _NotPorted,
    'FromUtcNoSeconds': _NotPorted,
    'FromUtcWithSeconds': _NotPorted,
    'FromUtcNoSeconds_ExtremelyNegative': _NotPorted,
    'FromUtcWithSeconds_ExtremelyNegative': _NotPorted,
    'FromTicksSinceUnixEpoch': _NotPorted,
    'FromUnixTimeMilliseconds_Valid': _NotPorted,
    'FromUnixTimeMilliseconds_TooLarge': _NotPorted,
    'FromUnixTimeMilliseconds_TooSmall': _NotPorted,
    'FromUnixTimeSeconds_Valid': _NotPorted,
    'FromUnixTimeSeconds_TooLarge': _NotPorted,
    'FromUnixTimeSeconds_TooSmall': _NotPorted,
    'ToUnixTimeSeconds': _NotPorted,
    'ToUnixTimeSecondsAndNanoseconds': _NotPorted,
    'ToUnixTimeMilliseconds': _NotPorted,
    'UnixConversions_ExtremeValues': _NotPorted,
    'Max': _NotPorted,
    'Min': _NotPorted,
    'DefaultConstructor': _NotPorted,
    'ToUnixTimeTicksTruncatesDown': _NotPorted,
    'PlusDuration_Overflow': _NotPorted,
    'FromUnixTimeMilliseconds_Range': _NotPorted,
    'FromUnixTimeSeconds_Range': _NotPorted,
    'FromTicksSinceUnixEpoch_Range': _NotPorted,
    'MinValue': _NotPorted,
    'MaxValue': _NotPorted,
    'ToInstant': _NotPorted,
    'ToDateTimeUtc': _NotPorted,
    'ToBclTypes_TruncateNanosTowardStartOfTime': _NotPorted,
    'ToDateTimeOffset': _NotPorted,
    'FromDateTimeOffset': _NotPorted,
    'FromDateTimeUtc_Invalid': _NotPorted,
    'FromDateTimeUtc_Valid': _NotPorted,
    'BclConversionLimits': _NotPorted,
    'Equality': _NotPorted,
    'Comparison': _NotPorted,
    'PlusTicks': _NotPorted,
    'PlusNanoseconds': _NotPorted,
    'OperatorPlusDuration_Zero_IsNeutralElement': _NotPorted,
    'OperatorPlusDuration_NonZero': _NotPorted,
    'OperatorPlus_Equivalents': _NotPorted,
    'OperatorPlus_OutOfRange': _NotPorted,
    'OperatorMinusDuration': _NotPorted,
    'OperatorMinus_Duration_Equivalents': _NotPorted,
    'OperatorMinus_OutOfRange': _NotPorted,
    'OperatorMinusInstant_NonZero': _NotPorted,
    'OperatorMinusInstant_UnixEpoch_IsNeutralElement': _NotPorted,
    'OperatorMinus_Instant_Equivalents': _NotPorted,
  });
}
