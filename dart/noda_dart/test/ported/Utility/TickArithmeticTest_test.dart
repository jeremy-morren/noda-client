// Ported from NodaTime 6e024dde: src/NodaTime.Test/Utility/TickArithmeticTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: TicksToDaysAndTickOfDay's `out long tickOfDay` is the second element of the returned record.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Utility/TickArithmetic.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Utility/TickArithmeticTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'TicksToDaysAndTickOfDayAndBack': (args) {
      final [int ticks] = args;
      final (int days, int tickOfDay) = TickArithmetic.TicksToDaysAndTickOfDay(ticks);

      Assert.AreEqual(ticks, TickArithmetic.DaysAndTickOfDayToTicks(days, tickOfDay));
    },

    'DaysAndTickOfDayToTicksUncheckedBoundaries': (args) {
      // Only a useful test under debug, but this proves that the arithmetic won't overflow when used from
      // LocalDateTime or Instant. (In debug mode, we have
      TickArithmetic.BoundedDaysAndTickOfDayToTicks(CalendarSystem.Iso.MinDays, 0);
      TickArithmetic.BoundedDaysAndTickOfDayToTicks(CalendarSystem.Iso.MaxDays, NodaConstants.TicksPerDay - 1);
    },
  });
}
