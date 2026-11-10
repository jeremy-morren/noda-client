// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/MissingTokenException.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

/// Thrown when an expected token is missing from the token stream.
class MissingTokenException implements Exception {
  /// The message (.NET's `Exception.Message`).
  final String message;

  /// Initializes a new instance of the [MissingTokenException] class.
  ///
  /// (NodaTime's constructors `MissingTokenException(string name)` and `MissingTokenException(string name, string
  /// message)`, as one with an optional message: by default, "Missing token {name}".)
  ///
  /// [name]: The name.
  /// [message]: The message.
  MissingTokenException(this.Name, [String? message]) : message = message ?? 'Missing token $Name';

  /// Gets or sets the name of the missing token
  ///
  /// The token name.
  final String Name;

  @override
  String toString() => 'MissingTokenException: $message';
}
