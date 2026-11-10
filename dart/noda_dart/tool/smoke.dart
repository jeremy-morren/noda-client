// noda_dart: new code. A quick end-to-end check of the public API (dart run tool/smoke.dart).
import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/tzdb_bundled.dart';

void main() {
  final zone = tzdb['Australia/Sydney'];
  final instant = Instant.FromUtc(2026, 11, 8, 9, 15, 42);
  final zoned = instant.InZone(zone);
  print(zoned);
  print(zoned.Date.PlusMonths(1));
  print(Period.BetweenLocalDate(LocalDate(2026, 1, 31), zoned.Date));
  print(LocalDatePattern.Iso.Parse('2026-02-29').Success);
  print(tzdb.VersionId);
  print(Duration.FromHours(25));
}
