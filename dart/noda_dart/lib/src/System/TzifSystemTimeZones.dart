// noda_dart: new code. System zones on native non-Windows platforms from the OS's TZif files (as .NET reads them),
// with IntlSystemTimeZones' semantics. Finding the files and local zone follows time_machine2: the zoneinfo directory
// and /etc/localtime on Unix, the tzdata bundle and persist.sys.timezone on Android.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../TimeZones/SystemDateTimeZone.dart';
import '../Utility/TimeZoneEnvironment.dart';
import 'IHostSystemTimeZones.dart';
import 'TzifTimeZone.dart';
import 'Windows/WindowsTimeZoneApi.dart';

TzifSystemTimeZones? _forHost;

/// The zone everything falls back to: UTC, as in noda-js elsewhere than Windows.
const String _EtcUtc = 'Etc/UTC';

/// The zoneinfo directories tried after $TZDIR, in order.
const List<String> _ZoneInfoDirectories = [
  '/usr/share/zoneinfo/',
  '/var/db/timezone/zoneinfo/',
  '/usr/lib/zoneinfo/',
  '/usr/share/lib/zoneinfo/',
];

/// Android's tzdata bundle locations (APEX, legacy update, system image); the first that exists is used.
const List<String> _AndroidBundlePaths = [
  '/apex/com.android.tzdata/etc/tz/tzdata',
  '/data/misc/zoneinfo/current/tzdata',
  '/system/usr/share/zoneinfo/tzdata',
];

/// The entries of a zoneinfo directory's top level that aren't zones.
const Set<String> _ExcludedTopLevel = {'posix', 'right', 'localtime', 'posixrules', 'Factory'};

/// The operating system's TZif zones, with IANA IDs.
@internal
final class TzifSystemTimeZones implements IHostSystemTimeZones {
  /// The zoneinfo directory (with a trailing slash), or the Android bundle's path.
  final String Path;

  final _AndroidTzdataBundle? _bundle;
  List<String>? _ids;
  Map<String, String>? _idsByUpperCase;
  SystemDateTimeZone? _systemDefault;

  TzifSystemTimeZones._(this.Path, this._bundle);

  /// The zones for this host: Android's tzdata bundle on Android, otherwise the zoneinfo directory.
  static TzifSystemTimeZones ForHost() {
    return _forHost ??= _Create();
  }

  static TzifSystemTimeZones _Create() {
    if (Platform.isAndroid) {
      for (final path in _AndroidBundlePaths) {
        try {
          final file = File(path);
          if (!file.existsSync()) {
            continue;
          }
          return TzifSystemTimeZones._(path, _AndroidTzdataBundle.Parse(file.readAsBytesSync()));
        } catch (_) {
          // Unreadable or malformed; try the next location.
        }
      }
    }
    String? tzDir;
    try {
      tzDir = Platform.environment['TZDIR'];
    } catch (_) {
      tzDir = null;
    }
    final candidates = [
      if (tzDir != null && tzDir.isNotEmpty) tzDir.endsWith('/') ? tzDir : '$tzDir/',
      ..._ZoneInfoDirectories,
    ];
    for (final directory in candidates) {
      try {
        if (Directory(directory).existsSync()) {
          return TzifSystemTimeZones._(directory, null);
        }
      } catch (_) {
        // Unreadable; try the next one.
      }
    }
    // No zones at all: only UTC (below).
    return TzifSystemTimeZones._(_ZoneInfoDirectories[0], null);
  }

  @override
  SystemTimeZoneBackend get Backend => 'tzif';

  /// `TZif: version (path)`: the tzdata version from the Android bundle, tzdata.zi or +VERSION, else "unknown".
  @override
  String get VersionId {
    final path = Path.endsWith('/') ? Path.substring(0, Path.length - 1) : Path;
    return 'TZif: ${_DataVersion() ?? 'unknown'} ($path)';
  }

  String? _DataVersion() {
    final bundle = _bundle;
    if (bundle != null) {
      return bundle.Version;
    }
    // tzdata.zi starts with e.g. "# version 2025b"; macOS has +VERSION.
    try {
      final zi = File('${Path}tzdata.zi');
      if (zi.existsSync()) {
        for (final line in zi.readAsLinesSync().take(5)) {
          final match = RegExp(r'^#\s*version\s+(\S+)').firstMatch(line);
          if (match != null) {
            return match.group(1);
          }
        }
      }
      final version = File('$Path+VERSION');
      if (version.existsSync()) {
        final text = version.readAsStringSync().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    } catch (_) {
      // Unreadable; no version.
    }
    return null;
  }

  /// The IDs of the zone files, plus the host default's if missing ("Etc/UTC" when there are none).
  @override
  List<String> GetIds() {
    final ids = <String>{..._GetFileIds()};
    final local = GetSystemDefaultId();
    if (local != null && _FindZoneId(local) != null) {
      ids.add(local);
    }
    return ids.toList();
  }

  /// The zone with the given ID (matched ignoring case; it keeps the ID asked for), or null. "Etc/UTC" always exists.
  @override
  SystemDateTimeZone? ForId(String id) {
    final fileId = _FindZoneId(id);
    if (fileId == null) {
      return null;
    }
    final bytes = _ReadZone(fileId);
    if (bytes == null) {
      return fileId == _EtcUtc ? SystemDateTimeZone.FromTzifUtc(id) : null;
    }
    try {
      return SystemDateTimeZone.FromTzif(id, bytes);
    } on FormatException {
      return null;
    }
  }

  /// The zone file ID [id] names (exact, else ignoring case), "Etc/UTC" (even without a file), or null.
  String? _FindZoneId(String id) {
    final ids = _GetFileIds();
    if (ids.contains(id)) {
      return id;
    }
    final byUpperCase = _idsByUpperCase ??= {for (final fileId in ids) fileId.toUpperCase(): fileId};
    return byUpperCase[id.toUpperCase()] ?? (id.toUpperCase() == _EtcUtc.toUpperCase() ? _EtcUtc : null);
  }

  /// The current zone's ID: TZ's (resolved by [ResolveId]; "Etc/UTC" if it names no zone), else the host's; or null.
  @override
  String? GetSystemDefaultId() {
    final tz = GetTZEnvironmentVariable();
    if (tz != null) {
      // A TZ naming no zone means UTC, as for Node, glibc and .NET on Unix.
      return ResolveId(tz) ?? ResolveId(_EtcUtc) ?? _EtcUtc;
    }
    return GetHostLocalId();
  }

  /// The ID in [GetIds] an ID names, or null. Unlike glibc, a path or POSIX TZ string isn't a zone.
  @override
  String? ResolveId(String id) {
    return _FindZoneId(id);
  }

  /// The host's default zone (cached while it doesn't change), or null if there isn't one.
  @override
  SystemDateTimeZone? ForSystemDefault() {
    final id = GetSystemDefaultId();
    if (id == null) {
      return null;
    }
    var current = _systemDefault;
    if (current?.Id != id) {
      current = ForId(id);
      _systemDefault = current;
    }
    return current;
  }

  /// The host's zone, ignoring TZ: Android's persist.sys.timezone, else /etc/localtime's (by link target or contents).
  @internal
  String? GetHostLocalId() {
    try {
      if (Platform.isAndroid) {
        final result = Process.runSync('getprop', ['persist.sys.timezone']);
        if (result.exitCode == 0) {
          final id = (result.stdout as String).trim();
          return id.isEmpty ? null : _FindZoneId(id);
        }
        return null;
      }
      if (_bundle != null) {
        return null;
      }
      for (final path in ['/etc/localtime', '${Path}localtime']) {
        final id = _IdForFile(path);
        if (id != null) {
          return id;
        }
      }
    } catch (_) {
      // No way to find out.
    }
    return null;
  }

  /// The zone ID for a zoneinfo file: by symlink target, then path, then contents; or null.
  String? _IdForFile(String path) {
    final known = _GetFileIds().toSet();

    // Prefer the symlink target, as .NET does. Unlike .NET, a dangling link (e.g. on an image without tzdata) still
    // counts if the zone it names is known.
    final link = Link(path);
    if (link.existsSync()) {
      var target = link.targetSync();
      if (!target.startsWith('/')) {
        target = '${File(path).parent.path}/$target';
      }
      final id = _KnownId(_ZoneIdFromPath(target), known);
      if (id != null) {
        return id;
      }
    }

    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }

    // A file in the zoneinfo directory itself.
    final direct = _KnownId(_ZoneIdFromPath(path), known);
    if (direct != null) {
      return direct;
    }

    // A copy rather than a link: find the zone file with the same contents (canonical zones first).
    final contents = file.readAsBytesSync();
    for (final id in _CanonicalFirst(_GetFileIds())) {
      try {
        final candidate = File('$Path$id');
        if (candidate.lengthSync() == contents.length && _BytesEqual(candidate.readAsBytesSync(), contents)) {
          return id;
        }
      } catch (_) {
        // Unreadable candidate; keep looking.
      }
    }
    return null;
  }

  /// The zone ID for a path in a zoneinfo directory ("Europe/Berlin"), or null.
  String? _ZoneIdFromPath(String path) {
    final normalized = _Normalize(path);
    if (normalized.startsWith(Path)) {
      return normalized.substring(Path.length);
    }
    const marker = '/zoneinfo/';
    final index = normalized.lastIndexOf(marker);
    if (index < 0) {
      return null;
    }
    final id = normalized.substring(index + marker.length);
    return id.isEmpty ? null : id;
  }

  /// [id] if known, else [id] without a "posix/" or "right/" prefix if that's known.
  static String? _KnownId(String? id, Set<String> known) {
    if (id == null) {
      return null;
    }
    if (known.contains(id)) {
      return id;
    }
    for (final prefix in const ['posix/', 'right/']) {
      if (id.startsWith(prefix) && known.contains(id.substring(prefix.length))) {
        return id.substring(prefix.length);
      }
    }
    return null;
  }

  /// Orders [ids] canonical zones first (tzdata.zi, else zone1970.tab/zone.tab), so content matching prefers them.
  List<String> _CanonicalFirst(List<String> ids) {
    final canonical = <String>{};
    try {
      final zi = File('${Path}tzdata.zi');
      if (zi.existsSync()) {
        for (final line in zi.readAsLinesSync()) {
          if (line.startsWith('Z ')) {
            final parts = line.split(' ');
            if (parts.length > 1) {
              canonical.add(parts[1]);
            }
          }
        }
      }
      if (canonical.isEmpty) {
        for (final name in ['zone1970.tab', 'zone.tab']) {
          final tab = File('$Path$name');
          if (!tab.existsSync()) {
            continue;
          }
          for (final line in tab.readAsLinesSync()) {
            if (line.startsWith('#')) {
              continue;
            }
            final parts = line.split('\t');
            if (parts.length > 2) {
              canonical.add(parts[2]);
            }
          }
        }
      }
    } catch (_) {
      // Fall back to ordinal order.
    }
    return [...ids.where(canonical.contains), ...ids.where((id) => !canonical.contains(id))];
  }

  /// The zone files' IDs, in ordinal order.
  List<String> _GetFileIds() {
    var ids = _ids;
    if (ids == null) {
      final bundle = _bundle;
      ids = bundle != null ? bundle.Ids : _Scan();
      _ids = ids;
    }
    return ids;
  }

  /// The TZif data of a zone file, or null.
  Uint8List? _ReadZone(String id) {
    final bundle = _bundle;
    if (bundle != null) {
      return bundle.TzifData(id);
    }
    try {
      return File('$Path$id').readAsBytesSync();
    } on FileSystemException {
      return null;
    }
  }

  List<String> _Scan() {
    final ids = <String>[];
    try {
      final root = Directory(Path);
      if (!root.existsSync()) {
        return ids;
      }
      _Walk(root, '', <String>[], ids);
    } catch (_) {
      // Treat an unreadable directory as having no zones.
    }
    ids.sort();
    return ids;
  }

  void _Walk(Directory dir, String prefix, List<String> ancestors, List<String> ids) {
    String resolved;
    List<FileSystemEntity> entries;
    try {
      resolved = dir.resolveSymbolicLinksSync();
      // A symlink back to an ancestor (e.g. posix -> .) would loop.
      if (ancestors.contains(resolved)) {
        return;
      }
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      return;
    }
    final path = [...ancestors, resolved];
    final dirPath = dir.path;
    for (final entry in entries) {
      var name = entry.path.substring(dirPath.length);
      while (name.startsWith('/')) {
        name = name.substring(1);
      }
      if (name.isEmpty || name.startsWith('.')) {
        continue;
      }
      if (prefix.isEmpty && _ExcludedTopLevel.contains(name)) {
        continue;
      }
      final id = '$prefix$name';
      try {
        final type = FileSystemEntity.typeSync(entry.path);
        if (type == FileSystemEntityType.directory) {
          _Walk(Directory(entry.path), '$id/', path, ids);
        } else if (type == FileSystemEntityType.file && _StartsWithTzifMagic(entry.path)) {
          ids.add(id);
        }
      } catch (_) {
        // Skip entries we can't read.
      }
    }
  }

  static bool _StartsWithTzifMagic(String path) {
    final file = File(path).openSync();
    try {
      return HasTzifMagic(file.readSync(4));
    } finally {
      file.closeSync();
    }
  }
}

bool _BytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// Resolves "." and ".." segments and duplicate slashes.
String _Normalize(String path) {
  final segments = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (segments.isNotEmpty) {
        segments.removeLast();
      }
    } else {
      segments.add(segment);
    }
  }
  return '/${segments.join('/')}';
}

/// A parsed Android tzdata bundle: a 12-byte header ("tzdata" + version + NUL), big-endian int32 offsets of the index,
/// data and final section, 52-byte index entries (40-byte zone ID, int32 start, length, unused), then the TZif data.
final class _AndroidTzdataBundle {
  final String Version;
  final Uint8List _bytes;
  final int _dataOffset;
  final Map<String, (int, int)> _entries;

  /// The zone IDs, in ordinal order.
  final List<String> Ids;

  _AndroidTzdataBundle._(this.Version, this._bytes, this._dataOffset, this._entries, this.Ids);

  /// Parses a bundle. Throws a [FormatException] if it's malformed.
  factory _AndroidTzdataBundle.Parse(Uint8List bytes) {
    if (bytes.length < 24 ||
        ascii.decode(Uint8List.sublistView(bytes, 0, 6), allowInvalid: true) != 'tzdata' ||
        bytes[11] != 0) {
      throw const FormatException('Not an Android tzdata bundle');
    }
    final version = ascii.decode(Uint8List.sublistView(bytes, 6, 11), allowInvalid: true);
    final data = ByteData.sublistView(bytes);
    final indexOffset = data.getInt32(12);
    final dataOffset = data.getInt32(16);
    if (indexOffset < 24 ||
        dataOffset < indexOffset ||
        dataOffset > bytes.length ||
        (dataOffset - indexOffset) % 52 != 0) {
      throw const FormatException('Bad Android tzdata offsets');
    }
    final entries = <String, (int, int)>{};
    for (var entry = indexOffset; entry < dataOffset; entry += 52) {
      final nameBytes = Uint8List.sublistView(bytes, entry, entry + 40);
      final nameEnd = nameBytes.indexOf(0);
      final name = ascii.decode(nameEnd < 0 ? nameBytes : Uint8List.sublistView(nameBytes, 0, nameEnd),
          allowInvalid: true);
      final start = data.getInt32(entry + 40);
      final length = data.getInt32(entry + 44);
      if (name.isEmpty || start < 0 || length <= 0 || dataOffset + start + length > bytes.length) {
        throw FormatException('Bad Android tzdata entry for "$name"');
      }
      entries[name] = (start, length);
    }
    final ids = entries.keys.toList()..sort();
    return _AndroidTzdataBundle._(version, bytes, dataOffset, entries, ids);
  }

  /// The TZif data for [id], or null if the bundle doesn't have it.
  Uint8List? TzifData(String id) {
    final entry = _entries[id];
    if (entry == null) {
      return null;
    }
    final (start, length) = entry;
    return Uint8List.sublistView(_bytes, _dataOffset + start, _dataOffset + start + length);
  }
}
