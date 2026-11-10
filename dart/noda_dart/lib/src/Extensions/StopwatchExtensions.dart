// Ported from NodaTime 6e024dde: src/NodaTime/Extensions/StopwatchExtensions.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:core';
import 'dart:core' as core;

import '../Duration.dart';
import 'TimeSpanExtensions.dart';

/// Extension methods for Dart's [core.Stopwatch] (C#: for `System.Diagnostics.Stopwatch`).
extension StopwatchExtensions on core.Stopwatch {
  /// Returns the elapsed time of this stopwatch as a [Duration].
  ///

  /// Returns the elapsed time of this stopwatch as a `Duration`.
  Duration ElapsedDuration() {
    // Dart: null safety checks stopwatch.
    return elapsed.ToDuration();
  }
}
