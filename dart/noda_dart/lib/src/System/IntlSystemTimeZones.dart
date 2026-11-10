// noda_dart: new code (noda-js's IntlSystemTimeZones.ts). The web's system zones: the host's Intl zones (IANA IDs).
// UseWindowsIds (noda-js on Windows without FFI) is never true in noda_dart, but kept as in noda-js.

import 'package:meta/meta.dart';

import '../TimeZones/SystemDateTimeZone.dart';
import '../Utility/TimeZoneEnvironment.dart';
import 'Host.dart' as host;
import 'IHostSystemTimeZones.dart';
import 'IntlTimeZone.dart';
import 'Windows/WindowsTimeZoneApi.dart';
import 'WindowsIdMapping.dart';

IntlSystemTimeZones? _forHost;

/// The host's Intl time zones, with Windows or IANA IDs.
@internal
final class IntlSystemTimeZones implements IHostSystemTimeZones {
  /// Whether zones have Windows IDs (mapped from the host's IANA zones with CLDR's mapping).
  final bool UseWindowsIds;
  List<String>? _windowsIds;
  SystemDateTimeZone? _systemDefault;

  /// Throws [StateError] if the host has no Intl.DateTimeFormat.
  IntlSystemTimeZones(this.UseWindowsIds) {
    if (!IsIntlAvailable()) {
      throw StateError(
        "noda_dart's system time zones need the host's Intl.DateTimeFormat (with time zone support) on the web, or "
        "Windows' or the TZif time zone data elsewhere, and none is available. Use the bundled tzdb "
        '(package:noda_dart/tzdb_bundled.dart) instead.',
      );
    }
  }

  /// The zones for this host: Windows IDs on a Windows runtime, IANA IDs elsewhere. Throws [StateError] without Intl.
  static IntlSystemTimeZones ForHost() {
    return _forHost ??= IntlSystemTimeZones(host.IsWindowsRuntime());
  }

  @override
  SystemTimeZoneBackend get Backend => 'intl';

  /// `Intl: tz version`, e.g. "Intl: 2025b", plus the CLDR mapping's version where IDs are Windows IDs.
  @override
  String get VersionId {
    final version = 'Intl: ${GetIntlTimeZoneVersion()}';
    return UseWindowsIds ? '$version (Windows IDs from CLDR windowsZones ${GetWindowsIdMappingVersion()})' : version;
  }

  /// The supported IDs (with Windows IDs, those CLDR maps to a supported zone), plus the host default's if missing.
  @override
  List<String> GetIds() {
    final ids = <String>{...(UseWindowsIds ? _GetWindowsIds() : _GetSupportedIds())};
    final local = GetSystemDefaultId();
    if (local != null && _FindZoneIds(local) != null) {
      ids.add(local);
    }
    return ids.toList();
  }

  /// The zone with the given ID, or null. With Windows IDs, Windows IDs match case-insensitively and mapped IANA IDs
  /// keep the ID asked for; otherwise any ID Intl accepts.
  @override
  SystemDateTimeZone? ForId(String id) {
    final ids = _FindZoneIds(id);
    return ids == null ? null : SystemDateTimeZone.FromIntl(ids.Id, ids.IanaId);
  }

  /// What [ForId] would make its zone from (its ID and IANA ID), without sampling Intl; null if there's none.
  ({String Id, String IanaId})? _FindZoneIds(String id) {
    if (!UseWindowsIds) {
      return IsIntlTimeZoneId(id) ? (Id: id, IanaId: id) : null;
    }
    final windows = TryConvertWindowsIdToIanaId(id);
    if (windows != null && _GetWindowsIds().contains(windows.WindowsId)) {
      return (Id: windows.WindowsId, IanaId: windows.IanaId);
    }
    if (IsIntlTimeZoneId(id) && (TryConvertIanaIdToWindowsId(id) != null || id == GetSystemDefaultId())) {
      return (Id: id, IanaId: id);
    }
    return null;
  }

  /// The current zone's ID: TZ's (resolved by [ResolveId]; UTC if it names no zone), else the host default's.
  @override
  String? GetSystemDefaultId() {
    final tz = GetTZEnvironmentVariable();
    if (tz != null) {
      // A TZ naming no zone means UTC, as for Node, glibc and .NET on Unix.
      return ResolveId(tz) ?? ResolveId(UseWindowsIds ? 'UTC' : 'Etc/UTC') ?? (UseWindowsIds ? null : 'Etc/UTC');
    }
    final local = GetIntlLocalId();
    if (local == null || !UseWindowsIds) {
      return local;
    }
    final windowsId = TryConvertIanaIdToWindowsId(local);
    return windowsId != null && _GetWindowsIds().contains(windowsId) ? windowsId : local;
  }

  /// The ID in [GetIds] an ID (such as TZ's) names: a Windows ID, or an IANA ID canonicalized by the host; or null.
  @override
  String? ResolveId(String id) {
    if (UseWindowsIds) {
      final windows = TryConvertWindowsIdToIanaId(id);
      if (windows != null && _GetWindowsIds().contains(windows.WindowsId)) {
        return windows.WindowsId;
      }
      final windowsId = IsIntlTimeZoneId(id) ? TryConvertIanaIdToWindowsId(id) : null;
      return windowsId != null && _GetWindowsIds().contains(windowsId) ? windowsId : null;
    }
    if (!IsIntlTimeZoneId(id)) {
      return null;
    }
    // (Etc/UTC as is: hosts canonicalize it to "UTC", or list neither.)
    return _GetSupportedIds().contains(id) || id == 'Etc/UTC' ? id : IntlCanonicalTimeZoneId(id);
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

  /// The Windows IDs whose primary IANA zone the host supports.
  List<String> _GetWindowsIds() {
    var windowsIds = _windowsIds;
    if (windowsIds == null) {
      windowsIds = <String>[];
      for (final windowsId in GetMappedWindowsIds()) {
        final mapping = TryConvertWindowsIdToIanaId(windowsId);
        if (mapping != null && IsIntlTimeZoneId(mapping.IanaId)) {
          windowsIds.add(windowsId);
        }
      }
      _windowsIds = windowsIds;
    }
    return windowsIds;
  }
}

List<String> _GetSupportedIds() {
  return GetIntlSupportedTimeZones();
}
