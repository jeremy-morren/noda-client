// Ported from NodaTime 6e024dde: src/NodaTime/IClock.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'Instant.dart';

/// Represents a clock which can return the current time as an [Instant].
///
/// [IClock] is intended for use anywhere you need to have access to the current time.
/// Although it's not strictly incorrect to call `SystemClock.Instance.GetCurrentInstant()` directly,
/// in the same way as you might call `DateTime.UtcNow`, it's strongly discouraged
/// as a matter of style for production code. We recommend providing an instance of [IClock]
/// to anything that needs it, which allows you to write tests using the fake clock in the NodaTime.Testing
/// assembly (or your own implementation).
///
/// See also [SystemClock].
///
/// All implementations in Noda Time are thread-safe; custom implementations
/// should be thread-safe too. See the thread safety section of the user guide for more information.
abstract interface class IClock {
  /// Gets the current [Instant] on the time line according to this clock.
  ///
  /// Returns the current instant on the time line according to this clock.
  Instant GetCurrentInstant();
}
