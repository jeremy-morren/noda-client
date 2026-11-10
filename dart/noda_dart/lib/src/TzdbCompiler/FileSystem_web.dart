// noda_dart: new code. The tzdb compiler's HTTP access on the web (fetch()); a path is a URL relative to the page.

import 'dart:js_interop';
import 'dart:typed_data';

import 'Shims.dart' show HttpRequestException;

/// An HTTP GET response: status, final URL (after redirects) and body.
typedef HttpGetResult = ({int StatusCode, String ReasonPhrase, String Url, Uint8List Content});

/// The host's `fetch(url)`.
@JS('fetch')
external JSPromise<_Response> _fetch(JSString url);

/// The parts of a fetch `Response` the compiler uses.
extension type _Response._(JSObject _) implements JSObject {
  external JSNumber get status;
  external JSString get statusText;
  external JSString get url;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

UnsupportedError _NoFileSystem() => UnsupportedError(
    "The web has no file system; pass the tzdata archive's bytes, or a URL (downloaded with fetch()), instead.");

/// `Directory.Exists(path)`: never, on the web.
bool DirectoryExists(String path) => false;

/// `Directory.GetFiles(path)`.
List<String> GetFiles(String path) => throw _NoFileSystem();

/// `File.ReadAllBytes(path)`.
Uint8List ReadAllBytes(String path) => throw _NoFileSystem();

/// `File.OpenRead(path)`: on the web, the path is a URL downloaded with fetch().
Future<Uint8List> ReadAllBytesAsync(String path) async {
  final response = await HttpGetAsync(path);
  if (response.StatusCode < 200 || response.StatusCode > 299) {
    throw HttpRequestException(
        'Downloading $path failed: HTTP ${response.StatusCode} ${response.ReasonPhrase}'.trim(), response.StatusCode);
  }
  return response.Content;
}

/// `HttpClient.GetAsync(url)`, following redirects: the response, whatever its status.
Future<HttpGetResult> HttpGetAsync(String url) async {
  final response = await _fetch(url.toJS).toDart;
  final content = (await response.arrayBuffer().toDart).toDart.asUint8List();
  final responseUrl = response.url.toDart;
  return (
    StatusCode: response.status.toDartInt,
    ReasonPhrase: response.statusText.toDart,
    Url: responseUrl == '' ? url : responseUrl,
    Content: content,
  );
}
