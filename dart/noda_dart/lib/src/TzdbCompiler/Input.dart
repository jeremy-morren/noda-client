// noda_dart: new code. Reads the tzdb compiler's input: bytes, a stream, a URL, a data: URI or a path.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../Tools/Common/FileUtility.dart';
import '../Utility/SystemExceptions.dart';
import 'Archive.dart';
import 'FileSystem.dart' as host;
import 'Shims.dart';
import 'Tzdb/FileSource.dart';
import 'Tzdb/TzdbZoneInfoCompiler.dart';

/// The files the compiler reads (besides the Makefile).
final List<String> _CompilerFiles = List<String>.unmodifiable([
  ...TzdbZoneInfoCompiler.ZoneFiles,
  TzdbZoneInfoCompiler.Iso3166TabFile,
  TzdbZoneInfoCompiler.ZoneTabFile,
  TzdbZoneInfoCompiler.Zone1970TabFile,
]);

/// The files to download from a directory URL: the files the compiler reads, and the `version` file (Archive.dart).
List<String> _DirectoryFiles() => [..._CompilerFiles, 'version'];

/// The bytes of a list of byte values (0 to 255, or -128 to 127 as signed bytes).
Uint8List _Bytes(List<int> chunk, String from) {
  if (chunk is Uint8List) {
    return chunk;
  }
  final bytes = Uint8List(chunk.length);
  for (var i = 0; i < chunk.length; i++) {
    final value = chunk[i];
    if (value < -128 || value > 255) {
      throw ArgumentError('$from must be bytes, from 0 to 255 (or -128 to 127); element $i is $value.');
    }
    bytes[i] = value & 0xff;
  }
  return bytes;
}

/// Whether the URL is an http: or https: URL.
bool _IsHttpUrl(String url) => url.startsWith('http://') || url.startsWith('https://');

/// The URL without its query and fragment.
String _WithoutQuery(String url) {
  final index = url.indexOf(RegExp('[?#]'));
  return index == -1 ? url : url.substring(0, index);
}

/// The archive's file name, for the compiler's version detection.
String _OriginOf(String url) => GetFileName(_IsHttpUrl(url) ? _WithoutQuery(url) : url);

/// The URL of a file in a directory (keeping the directory URL's query and fragment, if any).
String _DirectoryFileUrl(String directory, String name) {
  final index = directory.indexOf(RegExp('[?#]'));
  return index == -1 ? directory + name : directory.substring(0, index) + name + directory.substring(index);
}

/// A directory's name, for the compiler's version detection.
String _DirectoryOrigin(String url) {
  final segments = _WithoutQuery(url).split(RegExp(r'[/\\]')).where((segment) => segment != '').toList();
  return segments.length > 1 ? segments.last : '';
}

/// The files of a directory, checking it has some of the zone files.
FileSource _Directory(String url, Map<String, Uint8List> files) {
  if (!_CompilerFiles.any(files.containsKey)) {
    throw InvalidDataException('$url has none of the tzdata files (${_CompilerFiles.join(', ')}).');
  }
  return TzdataFileSource(files, _DirectoryOrigin(url));
}

/// The error for an unsuccessful HTTP status.
HttpRequestException _DownloadFailed(String url, int status, String statusText) =>
    HttpRequestException('Downloading $url failed: HTTP $status $statusText'.trim(), status);

/// Downloads the files the compiler reads from a directory URL, in parallel.
Future<FileSource> _FetchDirectory(String url, void Function(String line)? log) async {
  final downloads = _DirectoryFiles().map((name) async {
    final fileUrl = _DirectoryFileUrl(url, name);
    log?.call('Downloading $fileUrl');
    final response = await host.HttpGetAsync(fileUrl);
    if (response.StatusCode == 404) {
      return null; // A file this release doesn't have (e.g. systemv, removed in 2020b).
    }
    if (response.StatusCode < 200 || response.StatusCode > 299) {
      throw _DownloadFailed(fileUrl, response.StatusCode, response.ReasonPhrase);
    }
    return (Name: name, Bytes: response.Content);
  });
  final downloaded = await Future.wait(downloads);
  final files = <String, Uint8List>{};
  for (final file in downloaded) {
    if (file != null) {
      files[file.Name] = file.Bytes;
    }
  }
  return _Directory(url, files);
}

/// Reads the files of a local directory (with dart:io), as NodaTime's FileSource.FromDirectory does.
FileSource _ReadDirectory(String path) {
  final files = <String, Uint8List>{};
  for (final file in host.GetFiles(path)) {
    files[GetFileName(file)] = host.ReadAllBytes(file);
  }
  return _Directory(path, files);
}

/// Reads a stream of byte chunks to its end.
Future<Uint8List> _ReadStream(Stream<List<int>> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(_Bytes(chunk, 'The tzdata stream'));
  }
  return builder.takeBytes();
}

/// The error for a source that isn't one of the supported kinds.
ArgumentError _UnsupportedSource(Object? source, bool sync) => ArgumentError(sync
    ? "The tzdata source must be the archive's bytes (a List<int>, such as a Uint8List) or a data: Uri, not "
        '${source.runtimeType}. (CompileTzdb and CompileTzdbToNzd also take a URL, path or stream.)'
    : "The tzdata source must be the archive's bytes (a List<int>, such as a Uint8List), a Stream<List<int>> of them, "
        'or a URL or path (a String or Uri), not ${source.runtimeType}.');

/// Reads a tzdata source (see [CompileTzdb]); a directory URL's missing files (HTTP 404) are skipped.
@internal
Future<FileSource> ReadTzdataSource(Object? source, void Function(String line)? log) async {
  if (source is List<int>) {
    return ReadTzdbArchive(_Bytes(source, 'The tzdata bytes'), '');
  }
  if (source is Stream<List<int>>) {
    return ReadTzdbArchive(await _ReadStream(source), '');
  }
  if (source is Uri && source.scheme == 'file') {
    source = source.toFilePath();
  }
  if (source is Uri && source.scheme == 'data') {
    return ReadTzdbArchive(source.data!.contentAsBytes(), '');
  }
  if (source is String || source is Uri) {
    final url = source.toString();
    if (url.startsWith('data:')) {
      return ReadTzdbArchive(UriData.parse(url).contentAsBytes(), '');
    }
    if (_IsHttpUrl(url) && _WithoutQuery(url).endsWith('/')) {
      return await _FetchDirectory(url, log);
    }
    if (host.DirectoryExists(url)) {
      log?.call('Compiling from directory $url');
      return _ReadDirectory(url);
    }
    log?.call(_IsHttpUrl(url) ? 'Downloading $url' : 'Compiling from archive file $url');
    return ReadTzdbArchive(await FileUtility.LoadFileOrUrlAsync(url), _OriginOf(url));
  }
  throw _UnsupportedSource(source, false);
}

/// Reads a tzdata source synchronously: an archive's bytes (a `List<int>`), or a data: URI.
@internal
FileSource ReadTzdataSourceSync(Object? source) {
  if (source is List<int>) {
    return ReadTzdbArchive(_Bytes(source, 'The tzdata bytes'), '');
  }
  if (source is Uri && source.scheme == 'data') {
    return ReadTzdbArchive(source.data!.contentAsBytes(), '');
  }
  if (source is String && source.startsWith('data:')) {
    return ReadTzdbArchive(UriData.parse(source).contentAsBytes(), '');
  }
  throw _UnsupportedSource(source, true);
}
