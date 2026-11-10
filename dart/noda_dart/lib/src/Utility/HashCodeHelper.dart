// Ported from NodaTime 6e024dde: src/NodaTime/Utility/HashCodeHelper.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

/// The multiplier for each value.
const int _HashCodeMultiplier = 37;

/// The initial hash value.
const int _HashCodeInitializer = 17;

/// noda_dart: marks a two-value [HashCodeHelper.HashStatic] call (C#'s two-value overload).
const Object _NoValue = Object();

/// Provides method to help with generating hash codes for structures and classes. This handles
/// value types, nullable type, and objects. If we ever drop .NET Framework, we can use System.HashCode.
///
/// The basic usage pattern is:
///
/// ```dart
/// @override
/// int get hashCode => HashCodeHelper.Initialize().Hash(Field1).Hash(Field2).Hash(Field3).Value;
/// ```
///
/// (C#'s `unchecked` 32-bit arithmetic is reproduced with `toSigned(32)`.)
@internal
final class HashCodeHelper {
  final int Value;

  const HashCodeHelper.NewValue(int value) : Value = value;

  /// Convenience method to hash two values, or three if [t3] is given.
  ///
  /// (C#'s static `Hash(t1, t2)` and `Hash(t1, t2, t3)`: renamed, as Dart doesn't allow a static and an instance
  /// member with the same name.)
  static int HashStatic(Object? t1, Object? t2, [Object? t3 = _NoValue]) {
    // unchecked
    int hash = _HashCodeInitializer;
    hash = (hash * _HashCodeMultiplier + (t1?.hashCode ?? 0)).toSigned(32);
    hash = (hash * _HashCodeMultiplier + (t2?.hashCode ?? 0)).toSigned(32);
    if (!identical(t3, _NoValue)) {
      hash = (hash * _HashCodeMultiplier + (t3?.hashCode ?? 0)).toSigned(32);
    }
    return hash;
  }

  /// Returns the initial value for a hash code.
  ///
  /// Returns the initial integer wrapped in a [HashCodeHelper] value.
  static HashCodeHelper Initialize() => const HashCodeHelper.NewValue(_HashCodeInitializer);

  /// Adds the hash value for the given value to the current hash and returns the new value.
  ///
  /// [value]: The value to hash.
  ///
  /// Returns the new hash code.
  HashCodeHelper Hash<T>(T value) {
    // unchecked
    return HashCodeHelper.NewValue((Value * _HashCodeMultiplier + (value?.hashCode ?? 0)).toSigned(32));
  }
}
