// Ported from NodaTime 6e024dde: src/NodaTime/AmbiguousTimeException.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'DateTimeZone.dart';
import 'LocalDateTime.dart' as nt show LocalDateTime;
import 'Utility/Preconditions.dart';
import 'ZonedDateTime.dart';

// Standard exception constructors: we don't *want* those constructors.
// The single constructor provided in this class populates the message and
// accepts the required parameters for populating other properties.
// There are never any other causes to the exception, at least that I can
// envisage for the moment.

/// Exception thrown to indicate that the specified local date/time occurs twice
/// in a particular time zone due to daylight saving time changes.
///
/// This occurs for transitions where the clock goes backward (usually by
/// an hour). For example, suppose the time zone goes backward
/// at 2am, so the second after 01:59:59 becomes 01:00:00. In that case,
/// times such as 01:30:00 occur twice.
///
/// This exception is used to indicate such problems, as they're usually
/// not the same as other [RangeError] causes,
/// such as entering "15" for a month number.
///
/// In theory this isn't calendar-specific; the local value will be ambiguous in
/// this time zone regardless of the calendar used. However, this exception is
/// always created in conjunction with a specific calendar, which leads to a more
/// natural way of examining its information and constructing an error message.
///
/// (C#'s base type is `ArgumentOutOfRangeException`: Dart's [RangeError].)
final class AmbiguousTimeException extends RangeError {
  /// Get the local date and time which is ambiguous in the time zone.
  @internal
  nt.LocalDateTime get LocalDateTime => EarlierMapping.LocalDateTime;

  /// The time zone in which the local date and time is ambiguous.
  DateTimeZone get Zone => EarlierMapping.Zone;

  /// Gets the earlier of the two occurrences of the local date and time within the time zone.
  final ZonedDateTime EarlierMapping;

  /// Gets the later of the two occurrences of the local date and time within the time zone.
  final ZonedDateTime LaterMapping;

  /// Constructs an instance from the given information.
  ///
  /// User code is unlikely to need to deliberately call this constructor except
  /// possibly for testing.
  ///
  /// The two mappings must have the same local time and time zone.
  ///
  /// [earlierMapping]: The earlier possible mapping
  /// [laterMapping]: The later possible mapping
  AmbiguousTimeException(ZonedDateTime earlierMapping, ZonedDateTime laterMapping)
      : EarlierMapping = earlierMapping,
        LaterMapping = laterMapping,
        super('Local time ${earlierMapping.LocalDateTime} is ambiguous in time zone ${earlierMapping.Zone.Id}') {
    Preconditions.CheckArgument(
        earlierMapping.Zone == laterMapping.Zone, 'laterMapping', 'Ambiguous possible values must use the same time zone');
    Preconditions.CheckArgument(earlierMapping.LocalDateTime == laterMapping.LocalDateTime, 'laterMapping',
        'Ambiguous possible values must have the same local date/time');
  }
}
