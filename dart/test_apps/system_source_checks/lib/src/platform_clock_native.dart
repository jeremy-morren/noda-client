// Use of this source code is governed by the Apache License 2.0, as found in the LICENSE.txt file.

/// For failure messages.
const String platformClockDescription = 'DateTime.timeZoneOffset';

/// The local UTC offset at [epochMilliseconds], in seconds.
int platformUtcOffsetSeconds(int epochMilliseconds) =>
    DateTime.fromMillisecondsSinceEpoch(epochMilliseconds).timeZoneOffset.inSeconds;

/// Null: native Dart has no zone ID (timeZoneName is an abbreviation).
String? platformTimeZoneId() => null;
