// noda_dart: new code. The host's languages on the web: navigator.languages, navigator.language, or Intl's.

import 'dart:js_interop';

@JS('navigator')
external JSObject? get _navigator;

@JS('Intl')
external JSObject? get _intl;

extension type _Navigator._(JSObject _) implements JSObject {
  external JSAny? get languages;
  external JSAny? get language;
}

@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external _DateTimeFormat();
  external _ResolvedOptions resolvedOptions();
}

extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external JSAny? get locale;
}

/// The host's languages, most preferred first (BCP 47 tags such as "es-AR").
List<String> HostLanguages() {
  try {
    final navigatorObject = _navigator;
    if (navigatorObject != null) {
      final navigator = navigatorObject as _Navigator;
      final languages = navigator.languages;
      if (languages != null && languages.isA<JSArray>()) {
        final list = [
          for (final language in (languages as JSArray).toDart)
            if (language != null && language.isA<JSString>()) (language as JSString).toDart,
        ];
        if (list.isNotEmpty) {
          return list;
        }
      }
      final language = navigator.language;
      if (language != null && language.isA<JSString>()) {
        return [(language as JSString).toDart];
      }
    }
  } catch (_) {
    // No usable navigator: try Intl.
  }
  // No navigator (e.g. Node before 21): Intl's default locale, if Intl is available.
  try {
    if (_intl != null) {
      final locale = _DateTimeFormat().resolvedOptions().locale;
      if (locale != null && locale.isA<JSString>()) {
        final name = (locale as JSString).toDart;
        if (name.isNotEmpty) {
          return [name];
        }
      }
    }
  } catch (_) {
    // No usable Intl: no host languages.
  }
  return const [];
}
