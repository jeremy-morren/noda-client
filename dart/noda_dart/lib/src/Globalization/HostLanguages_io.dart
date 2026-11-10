// noda_dart: new code. The host's languages on native platforms.

import 'dart:io' show Platform;

/// The host's languages as BCP 47 tags, from [Platform.localeName] (a POSIX locale on Linux and Android).
List<String> HostLanguages() {
  String name;
  try {
    name = Platform.localeName;
  } catch (_) {
    // No usable locale: no host languages.
    return const [];
  }
  // POSIX: language[_territory][.codeset][@modifier].
  final codeset = name.indexOf('.');
  if (codeset != -1) {
    name = name.substring(0, codeset);
  }
  final modifier = name.indexOf('@');
  if (modifier != -1) {
    name = name.substring(0, modifier);
  }
  name = name.replaceAll('_', '-');
  if (name.isEmpty || name == 'C' || name == 'POSIX') {
    return const [];
  }
  return [name];
}
