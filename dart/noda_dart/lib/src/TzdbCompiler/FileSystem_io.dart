// noda_dart: new code. The tzdb compiler's file system and HTTP access with dart:io.

import 'dart:io' as io;
import 'dart:typed_data';

/// An HTTP GET response: status, final URL (after redirects) and body.
typedef HttpGetResult = ({int StatusCode, String ReasonPhrase, String Url, Uint8List Content});

/// `Directory.Exists(path)`.
bool DirectoryExists(String path) => io.FileSystemEntity.isDirectorySync(path);

/// `Directory.GetFiles(path)`.
List<String> GetFiles(String path) =>
    [for (final entity in io.Directory(path).listSync(followLinks: true)) if (entity is io.File) entity.path];

/// `File.ReadAllBytes(path)`.
Uint8List ReadAllBytes(String path) => io.File(path).readAsBytesSync();

/// `File.OpenRead(path)`, read to its end; a `file:` URI is read as its file.
Future<Uint8List> ReadAllBytesAsync(String path) =>
    io.File(path.startsWith('file:') ? Uri.parse(path).toFilePath() : path).readAsBytes();

/// `HttpClient.GetAsync(url)`, following redirects: the response, whatever its status.
Future<HttpGetResult> HttpGetAsync(String url) async {
  final client = io.HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.followRedirects = true;
    final response = await request.close();
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    // The URL the response came from: each redirect's location is relative to the URL before it.
    var finalUri = Uri.parse(url);
    for (final redirect in response.redirects) {
      finalUri = finalUri.resolveUri(redirect.location);
    }
    return (
      StatusCode: response.statusCode,
      ReasonPhrase: response.reasonPhrase,
      Url: finalUri.toString(),
      Content: builder.takeBytes(),
    );
  } finally {
    client.close();
  }
}
