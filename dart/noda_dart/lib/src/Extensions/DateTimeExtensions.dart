// Ported from NodaTime 6e024dde: src/NodaTime/Extensions/DateTimeExtensions.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:core';
import 'dart:core' as core;

import '../Instant.dart';
import '../LocalDateTime.dart';

/// Extension methods for Dart's [core.DateTime] (C#: for `DateTime`).
extension DateTimeExtensions on core.DateTime {
  /// Converts a Dart [core.DateTime] (local or UTC) to [LocalDateTime].
  ///
  /// This is a convenience method which calls [LocalDateTime.FromDateTime].
  ///
  /// Returns a new [LocalDateTime] with the same values as this `DateTime`.
  LocalDateTime ToLocalDateTime() => LocalDateTime.FromDateTime(this);

  /// Converts a UTC Dart [core.DateTime] (C#: one with a kind of `DateTimeKind.Utc`) into an [Instant].
  ///
  /// This is a convenience method which calls [Instant.FromDateTimeUtc].
  ///
  /// Returns an [Instant] value representing the same instant in time as this `DateTime`.
  ///
  /// Throws [ArgumentError] if this `DateTime` is not UTC.
  Instant ToInstant() => Instant.FromDateTimeUtc(this);
}
