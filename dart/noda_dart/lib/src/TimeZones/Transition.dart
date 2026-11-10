// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/Transition.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

// Transition has a member named Instant, which hides the type inside the class.
import '../Instant.dart' as nt show Instant;
import '../Offset.dart';

/// A transition between two offsets, usually for daylight saving reasons. This type only knows about
/// the new offset, and the transition point.
@internal
final class Transition {
  @internal
  final nt.Instant Instant;

  /// The offset from the time when this transition occurs until the next transition.
  @internal
  final Offset NewOffset;

  @internal
  Transition.NewInstantNewOffset(nt.Instant instant, Offset newOffset)
      : Instant = instant,
        NewOffset = newOffset;

  bool Equals(Transition other) => Instant == other.Instant && NewOffset == other.NewOffset;

  // #region Operators
  /// Implements the operator == (equality).
  ///
  /// [other]: The right hand side of the operator.
  ///
  /// Returns `true` if values are equal to each other, otherwise `false`.
  @override
  bool operator ==(Object other) => other is Transition && Equals(other);

  // Dart: != is Dart's own (the negation of ==).
  // #endregion

  // #region Object overrides
  /// Returns a hash code for this instance.
  ///
  /// Returns a hash code for this instance, suitable for use in hashing algorithms and data
  /// structures like a hash table.
  @override
  int get hashCode {
    // unchecked
    int hash = 23;
    hash = (hash * 31 + Instant.hashCode).toSigned(32);
    hash = (hash * 31 + NewOffset.hashCode).toSigned(32);
    return hash;
  }

  /// Returns a [String] that represents this instance.
  ///
  /// Returns a [String] that represents this instance.
  @override
  String toString() => 'Transition to $NewOffset at $Instant';
  // #endregion  // Object overrides
}
