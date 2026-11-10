// noda_dart: new code. The tzdb compiler's public functions (package:noda_dart/tzdb_compiler.dart).

import 'dart:typed_data';

import '../Bcl/CldrWindowsZones.dart';
import '../TimeZones/Cldr/WindowsZones.dart' as nt show WindowsZones;
import '../TimeZones/TzdbDateTimeZoneSource.dart';
import 'Input.dart';
import 'Program.dart';
import 'Tzdb/FileSource.dart';

/// Options for [CompileTzdb], [CompileTzdbToNzd] and their synchronous variants.
final class CompileTzdbOptions {
  /// The Windows mapping to include (the compiler's `-w`); null: the CLDR mapping bundled with noda_dart.
  final nt.WindowsZones? WindowsZones;

  /// Called with each line of the compiler's log; null: no logging.
  final void Function(String line)? Log;

  const CompileTzdbOptions({this.WindowsZones, this.Log});
}

/// Compiles the files, writes the data, reads it back and validates it (NodaTime's TzdbCompiler program).
({Uint8List Nzd, TzdbDateTimeZoneSource Source}) _CompileFiles(FileSource files, CompileTzdbOptions? options) =>
    Program.Main(files, options?.WindowsZones ?? GetCldrWindowsZones(), options?.Log);

/// Compiles an IANA tzdata release into a validated time zone source, as NodaTime's TzdbCompiler does.
///
/// ```dart
/// final source = await CompileTzdb('https://data.iana.org/time-zones/tzdata-latest.tar.gz');
/// final zones = DateTimeZoneCache(source);
/// ```
///
/// [source]: a `tzdata*.tar.gz` (or `.tar`) as bytes, a byte stream, or a URL or path; a URL ending with `/` is a
/// directory of tzdata files (on the web, use one on a CORS-enabled CDN, e.g.
/// `https://cdn.jsdelivr.net/gh/eggert/tz@2026f/`, as data.iana.org sends no CORS headers).
///
/// Throws [ArgumentError] for an unsupported [source], [HttpRequestException] for an HTTP error status,
/// [UnsupportedError] for lzip or a path without file system access, [InvalidDataException] for an invalid archive or
/// unknown version, [InvalidNodaDataException] if validation fails, and the compiler's own errors for bad tzdata.
Future<TzdbDateTimeZoneSource> CompileTzdb(Object source, [CompileTzdbOptions? options]) async =>
    _CompileFiles(await ReadTzdataSource(source, options?.Log), options).Source;

/// As [CompileTzdb], returning the NZD bytes (load them later with `TzdbDateTimeZoneSource.FromBytes`).
///
/// ```dart
/// final nzd = await CompileTzdbToNzd('https://data.iana.org/time-zones/tzdata-latest.tar.gz');
/// final zones = DateTimeZoneCache(TzdbDateTimeZoneSource.FromBytes(nzd));
/// ```
Future<Uint8List> CompileTzdbToNzd(Object source, [CompileTzdbOptions? options]) async =>
    _CompileFiles(await ReadTzdataSource(source, options?.Log), options).Nzd;

/// As [CompileTzdb], synchronously, from the archive's bytes or a data: URI.
TzdbDateTimeZoneSource CompileTzdbSync(Object source, [CompileTzdbOptions? options]) =>
    _CompileFiles(ReadTzdataSourceSync(source), options).Source;

/// As [CompileTzdbToNzd], synchronously, from the archive's bytes or a data: URI.
Uint8List CompileTzdbToNzdSync(Object source, [CompileTzdbOptions? options]) =>
    _CompileFiles(ReadTzdataSourceSync(source), options).Nzd;
