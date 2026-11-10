// noda_dart: new code. No file system or HTTP access (neither dart:io nor dart:js_interop).

import 'dart:typed_data';

/// An HTTP GET response: status, final URL (after redirects) and body.
typedef HttpGetResult = ({int StatusCode, String ReasonPhrase, String Url, Uint8List Content});

UnsupportedError _NoFileSystem() =>
    UnsupportedError('This platform has no file system or HTTP access; pass the tzdata archive\'s bytes instead.');

/// `Directory.Exists(path)`.
bool DirectoryExists(String path) => false;

/// `Directory.GetFiles(path)`.
List<String> GetFiles(String path) => throw _NoFileSystem();

/// `File.ReadAllBytes(path)`.
Uint8List ReadAllBytes(String path) => throw _NoFileSystem();

/// `File.OpenRead(path)`, read to its end.
Future<Uint8List> ReadAllBytesAsync(String path) => Future.error(_NoFileSystem());

/// `HttpClient.GetAsync(url)`, following redirects.
Future<HttpGetResult> HttpGetAsync(String url) => Future.error(_NoFileSystem());
