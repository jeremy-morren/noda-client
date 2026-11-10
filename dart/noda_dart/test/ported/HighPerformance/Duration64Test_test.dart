// Ported from NodaTime 6e024dde: src/NodaTime.Test/HighPerformance/Duration64Test.cs (+ Duration64Test.Construction.cs, Duration64Test.Operators.cs)
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator (NodaTime.HighPerformance isn't ported).

import '../../helpers/Scenarios.dart';
import '../../scenarios/HighPerformance/Duration64Test.generated.dart' as scenarios;

const String _NotPorted = "NodaTime.HighPerformance (Duration64, Instant64) isn't ported: .NET-specific performance types";

void main() {
  port(scenarios.fixture, {}, skip: {
    'Zero': _NotPorted,
    'FromDays_Int32': _NotPorted,
    'FromHours_Int32': _NotPorted,
    'FromMinutes_Int64': _NotPorted,
    'FromSeconds_Int64': _NotPorted,
    'FromMilliseconds_Int64': _NotPorted,
    'FromTicks': _NotPorted,
    'FromNanoseconds_Int64': _NotPorted,
    'FactoryMethods_OutOfRange': _NotPorted,
    'DefaultConstructor': _NotPorted,
    'Int64Conversions': _NotPorted,
    'Addition_Subtraction': _NotPorted,
    'Equality': _NotPorted,
    'Comparison': _NotPorted,
    'UnaryNegation': _NotPorted,
    'UnaryNegation_MinValue': _NotPorted,
    'MaxMinRelationship': _NotPorted,
    'Max': _NotPorted,
    'Min': _NotPorted,
    'AdditiveIdentityIsZero': _NotPorted,
    'MinValue': _NotPorted,
    'MaxValue': _NotPorted,
    'TotalNanoseconds': _NotPorted,
    'FromAndToTimeSpan': _NotPorted,
    'BclConversionLimits': _NotPorted,
    'Extreme_IsoCalendar': _NotPorted,
    'OperatorPlus_Zero_IsNeutralElement': _NotPorted,
    'OperatorPlus_NonZero': _NotPorted,
    'OperatorPlus_MethodEquivalents': _NotPorted,
    'OperatorMinus_Zero_IsNeutralElement': _NotPorted,
    'OperatorMinus_NonZero': _NotPorted,
    'OperatorMinus_MethodEquivalents': _NotPorted,
    'UnaryMinusAndNegate': _NotPorted,
    'UnaryAddition': _NotPorted,
  });
}
