// Ported from NodaTime 6e024dde: src/NodaTime/Extensions/TimeSpanExtensions.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:core';
import 'dart:core' as core;

import '../Duration.dart';
import '../Offset.dart';

/// Extension methods for Dart's [core.Duration] (C#: for `TimeSpan`).
extension TimeSpanExtensions on core.Duration {
  /// Converts a Dart [core.Duration] into a [Duration].
  ///
  /// This is a convenience method which calls [Duration.FromCoreDuration].
  ///
  /// Returns a `Duration` representing the same length of time as this Dart `Duration`.
  Duration ToDuration() => Duration.FromCoreDuration(this);

  /// Converts a Dart [core.Duration] into an [Offset].
  ///
  /// This is a convenience method which calls [Offset.FromCoreDuration].
  ///
  /// Returns an `Offset` representing the same length of time as this Dart `Duration`.
  ///
  /// Throws [RangeError] if this Dart `Duration` is too large or small to
  /// be represented as an `Offset`.
  Offset ToOffset() => Offset.FromCoreDuration(this);
}
