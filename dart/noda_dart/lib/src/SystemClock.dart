// Ported from NodaTime 6e024dde: src/NodaTime/SystemClock.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:core';
import 'dart:core' as core;

import 'IClock.dart';
import 'Instant.dart';
import 'NodaConstants.dart';

/// Singleton implementation of [IClock] which reads the current system time.
/// It is recommended that for anything other than throwaway code, this is only referenced
/// in a single place in your code: where you provide a value to inject into the rest of
/// your application, which should only depend on the interface.
///
/// noda_dart: Dart's `DateTime.now()` (microsecond precision; millisecond on the web).
///
/// This type has no state, and is thread-safe. See the thread safety section of the user guide for more information.
final class SystemClock implements IClock {
  /// The singleton instance of [SystemClock].
  static final SystemClock Instance = SystemClock._New();

  /// Constructor present to prevent external construction.
  SystemClock._New();

  /// Gets the current time as an [Instant].
  ///
  /// Returns the current time in ticks as an [Instant].
  @override
  Instant GetCurrentInstant() {
    // C#: NodaConstants.BclEpoch.PlusTicks(DateTime.UtcNow.Ticks)
    // (noda_dart: seconds, then microseconds, to stay exact on the web.)
    int microseconds = core.DateTime.now().microsecondsSinceEpoch;
    int microsecondOfSecond = microseconds % core.Duration.microsecondsPerSecond;
    int seconds = (microseconds - microsecondOfSecond) ~/ core.Duration.microsecondsPerSecond;
    return Instant.FromUnixTimeSeconds(seconds)
        .PlusNanoseconds(microsecondOfSecond * NodaConstants.NanosecondsPerMicrosecond);
  }
}
