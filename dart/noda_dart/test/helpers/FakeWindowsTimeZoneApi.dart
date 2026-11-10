// noda_dart: new code. An IWindowsTimeZoneApi over an in-memory registry (as noda-js's FakeWindowsTimeZoneApi.ts).

import 'dart:typed_data';

import 'package:noda_dart/src/System/Windows/IWindowsTimeZoneApi.dart';
import 'package:noda_dart/src/System/Windows/WindowsTimeZoneApi.dart';
import 'package:noda_dart/src/TimeZones/TimeZoneInfoInterceptor.dart';

/// A SYSTEMTIME as [year, month, dayOfWeek, day, hour, minute, second, milliseconds]; all zero for "none".
typedef SystemTimeTuple = List<int>;

const SystemTimeTuple NoDate = [0, 0, 0, 0, 0, 0, 0, 0];

/// A REG_TZI_FORMAT. Biases are minutes, UTC = local + bias.
final class FakeTzi {
  final int Bias;
  final int StandardBias;
  final int DaylightBias;

  final SystemTimeTuple StandardDate;

  final SystemTimeTuple DaylightDate;

  const FakeTzi({
    required this.Bias,
    this.StandardBias = 0,
    this.DaylightBias = 0,
    this.StandardDate = NoDate,
    this.DaylightDate = NoDate,
  });
}

/// The "Dynamic DST" subkey of a zone.
final class FakeDynamicDst {
  /// FirstEntry: an int (REG_DWORD), or a string to give invalid data.
  final Object First;
  final int Last;
  final Map<int, FakeTzi> Years;

  const FakeDynamicDst({required this.First, required this.Last, required this.Years});
}

final class FakeZone {
  final String Id;
  final String? Display;
  final String? Std;
  final String? Dlt;
  final String? MuiDisplay;
  final String? MuiStd;
  final String? MuiDlt;

  final FakeTzi? Tzi;

  /// The TZI value as raw bytes (to give invalid data), instead of [Tzi].
  final Uint8List? TziBytes;

  final FakeDynamicDst? Dynamic;

  const FakeZone({
    required this.Id,
    this.Display,
    this.Std,
    this.Dlt,
    this.MuiDisplay,
    this.MuiStd,
    this.MuiDlt,
    this.Tzi,
    this.TziBytes,
    this.Dynamic,
  });

  FakeZone With({String? Id, FakeDynamicDst? Dynamic}) => FakeZone(
        Id: Id ?? this.Id,
        Display: Display,
        Std: Std,
        Dlt: Dlt,
        MuiDisplay: MuiDisplay,
        MuiStd: MuiStd,
        MuiDlt: MuiDlt,
        Tzi: Tzi,
        TziBytes: TziBytes,
        Dynamic: Dynamic ?? this.Dynamic,
      );
}

final class FakeWindowsOptions {
  /// Null: TIME_ZONE_ID_INVALID. [LocalSet] false: none set.
  final WindowsDynamicTimeZoneInformation? Local;
  final bool LocalSet;
  final List<String>? Languages;
  final String? SystemDirectory;

  /// By MUI file path (case-insensitive) and resource ID.
  final Map<String, Map<int, String>>? MuiFiles;

  const FakeWindowsOptions({this.Local, this.LocalSet = false, this.Languages, this.SystemDirectory, this.MuiFiles});

  const FakeWindowsOptions.WithLocal(this.Local, {this.Languages, this.SystemDirectory, this.MuiFiles}) : LocalSet = true;
}

const String _Hive = 'SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Time Zones';

WindowsSystemTime SystemTime(SystemTimeTuple tuple) =>
    WindowsSystemTime(tuple[0], tuple[1], tuple[2], tuple[3], tuple[4], tuple[5], tuple[6], tuple[7]);

/// The 44 bytes of a REG_TZI_FORMAT.
Uint8List EncodeTzi(FakeTzi tzi) {
  final bytes = Uint8List(44);
  final view = ByteData.sublistView(bytes);
  view.setInt32(0, tzi.Bias, Endian.little);
  view.setInt32(4, tzi.StandardBias, Endian.little);
  view.setInt32(8, tzi.DaylightBias, Endian.little);
  for (var i = 0; i < 8; i++) {
    view.setUint16(12 + 2 * i, tzi.StandardDate[i], Endian.little);
    view.setUint16(28 + 2 * i, tzi.DaylightDate[i], Endian.little);
  }
  return bytes;
}

WindowsDynamicTimeZoneInformation DynamicInformation(FakeZone zone,
    {String? KeyName, bool DynamicDaylightTimeDisabled = false, int? Year}) {
  var tzi = zone.Tzi!;
  final dynamic_ = zone.Dynamic;
  if (dynamic_ != null && Year != null) {
    final first = dynamic_.First is int ? dynamic_.First as int : int.parse(dynamic_.First as String);
    final year = Year.clamp(first, dynamic_.Last);
    tzi = dynamic_.Years[year]!;
  }
  return WindowsDynamicTimeZoneInformation(
    tzi.Bias,
    zone.Std ?? '',
    SystemTime(tzi.StandardDate),
    tzi.StandardBias,
    zone.Dlt ?? '',
    SystemTime(tzi.DaylightDate),
    tzi.DaylightBias,
    KeyName ?? zone.Id,
    DynamicDaylightTimeDisabled,
  );
}

final class _Key {
  final String Name;
  final Map<String, Object> Values = {};
  final List<_Key> SubKeys = [];

  _Key(this.Name);
}

final class FakeWindowsTimeZoneApi implements IWindowsTimeZoneApi {
  final Map<String, _Key> _keys = {};
  final FakeWindowsOptions _options;

  final Map<String, int> Calls = {};

  FakeWindowsTimeZoneApi(List<FakeZone> zones, [this._options = const FakeWindowsOptions()]) {
    final hive = _AddKey(_Hive);
    for (final zone in zones) {
      final key = _AddKey('$_Hive\\${zone.Id}', hive);
      void set(String name, Object? value) {
        if (value != null) {
          key.Values[name.toUpperCase()] = value;
        }
      }

      set('Display', zone.Display);
      set('Std', zone.Std);
      set('Dlt', zone.Dlt);
      set('MUI_Display', zone.MuiDisplay);
      set('MUI_Std', zone.MuiStd);
      set('MUI_Dlt', zone.MuiDlt);
      set('TZI', zone.TziBytes ?? (zone.Tzi == null ? null : EncodeTzi(zone.Tzi!)));
      final dynamic_ = zone.Dynamic;
      if (dynamic_ != null) {
        final dynamicKey = _AddKey('$_Hive\\${zone.Id}\\Dynamic DST', key);
        dynamicKey.Values['FIRSTENTRY'] = dynamic_.First;
        dynamicKey.Values['LASTENTRY'] = dynamic_.Last;
        for (final year in dynamic_.Years.keys) {
          dynamicKey.Values['$year'] = EncodeTzi(dynamic_.Years[year]!);
        }
      }
    }
  }

  TimeZoneInfoInterceptorITimeZoneInfoShim CreateShim([String description = 'fake']) =>
      CreateWindowsTimeZoneInfoShim(WindowsTimeZoneApiBackend('ffi', description, this));

  @override
  WindowsDynamicTimeZoneInformation? GetDynamicTimeZoneInformation() {
    _Count('GetDynamicTimeZoneInformation');
    if (!_options.LocalSet) {
      return DynamicInformation(const FakeZone(Id: '', Tzi: FakeTzi(Bias: 0)));
    }
    return _options.Local;
  }

  @override
  List<String>? GetRegistrySubKeyNames(String keyPath) {
    _Count('GetRegistrySubKeyNames');
    final key = _keys[keyPath.toUpperCase()];
    return key?.SubKeys.map((subKey) => subKey.Name).toList();
  }

  @override
  bool RegistryKeyExists(String keyPath) {
    _Count('RegistryKeyExists');
    return _keys.containsKey(keyPath.toUpperCase());
  }

  @override
  Object? GetRegistryValue(String keyPath, String valueName) {
    _Count('GetRegistryValue');
    return _keys[keyPath.toUpperCase()]?.Values[valueName.toUpperCase()];
  }

  @override
  String GetSystemDirectory() => _options.SystemDirectory ?? 'C:\\Windows\\system32';

  @override
  List<String> GetUserPreferredUILanguages() => _options.Languages ?? const ['en-US'];

  @override
  bool FileExists(String path) => _FindMuiFile(path) != null;

  @override
  String LoadString(String filePath, int resourceId) {
    _Count('LoadString');
    return _FindMuiFile(filePath)?[resourceId] ?? '';
  }

  Map<int, String>? _FindMuiFile(String path) {
    final files = _options.MuiFiles ?? const {};
    for (final name in files.keys) {
      if (name.toUpperCase() == path.toUpperCase()) {
        return files[name];
      }
    }
    return null;
  }

  _Key _AddKey(String path, [_Key? parent]) {
    final key = _Key(path.substring(path.lastIndexOf('\\') + 1));
    _keys[path.toUpperCase()] = key;
    parent?.SubKeys.add(key);
    return key;
  }

  void _Count(String name) {
    Calls[name] = (Calls[name] ?? 0) + 1;
  }
}

// #region Zones (their data as in Windows' registry)

const FakeZone UtcZone = FakeZone(
  Id: 'UTC',
  Display: '(UTC) Coordinated Universal Time',
  Std: 'Coordinated Universal Time',
  Dlt: 'Coordinated Universal Time',
  MuiDisplay: '@tzres.dll,-930',
  MuiStd: '@tzres.dll,-932',
  MuiDlt: '@tzres.dll,-931',
  Tzi: FakeTzi(Bias: 0),
);

const FakeZone UtcMinus02Zone = FakeZone(
  Id: 'UTC-02',
  Display: '(UTC-02:00) Coordinated Universal Time-02',
  Std: 'UTC-02',
  Dlt: 'UTC-02',
  MuiDisplay: '@tzres.dll,-1160',
  MuiStd: '@tzres.dll,-1162',
  MuiDlt: '@tzres.dll,-1161',
  Tzi: FakeTzi(Bias: 120),
);

const FakeZone SaWesternZone = FakeZone(
  Id: 'SA Western Standard Time',
  Display: '(UTC-04:00) Georgetown, La Paz, Manaus, San Juan',
  Std: 'SA Western Standard Time',
  Dlt: 'SA Western Summer Time',
  Tzi: FakeTzi(Bias: 240),
);

const FakeZone AusEasternZone = FakeZone(
  Id: 'AUS Eastern Standard Time',
  Display: '(UTC+10:00) Canberra, Melbourne, Sydney',
  Std: 'AUS Eastern Standard Time',
  Dlt: 'AUS Eastern Summer Time',
  MuiDisplay: '@tzres.dll,-670',
  MuiStd: '@tzres.dll,-672',
  MuiDlt: '@tzres.dll,-671',
  Tzi: FakeTzi(Bias: -600, DaylightBias: -60, StandardDate: [0, 4, 0, 1, 3, 0, 0, 0], DaylightDate: [0, 10, 0, 1, 2, 0, 0, 0]),
  Dynamic: FakeDynamicDst(
    First: 2007,
    Last: 2008,
    Years: {
      2007: FakeTzi(Bias: -600, DaylightBias: -60, StandardDate: [0, 3, 0, 5, 3, 0, 0, 0], DaylightDate: [0, 10, 0, 5, 2, 0, 0, 0]),
      2008: FakeTzi(Bias: -600, DaylightBias: -60, StandardDate: [0, 4, 0, 1, 3, 0, 0, 0], DaylightDate: [0, 10, 0, 1, 2, 0, 0, 0]),
    },
  ),
);

/// Brazil: DST transitions at 24:00, which Windows writes as 23:59:59.999.
const FakeZone ESouthAmericaZone = FakeZone(
  Id: 'E. South America Standard Time',
  Display: '(UTC-03:00) Brasilia',
  Std: 'E. South America Standard Time',
  Dlt: 'E. South America Daylight Time',
  Tzi: FakeTzi(Bias: 180, DaylightBias: -60),
  Dynamic: FakeDynamicDst(
    First: 2010,
    Last: 2020,
    Years: {
      2010: FakeTzi(Bias: 180, DaylightBias: -60, StandardDate: [0, 2, 6, 3, 23, 59, 59, 999], DaylightDate: [0, 10, 6, 3, 23, 59, 59, 999]),
      2011: FakeTzi(Bias: 180, DaylightBias: -60, StandardDate: [0, 2, 6, 3, 23, 59, 59, 999], DaylightDate: [0, 10, 6, 3, 23, 59, 59, 999]),
      2012: FakeTzi(Bias: 180, DaylightBias: -60, StandardDate: [0, 2, 6, 4, 23, 59, 59, 999], DaylightDate: [0, 10, 6, 3, 23, 59, 59, 999]),
      2013: FakeTzi(Bias: 180, DaylightBias: -60, StandardDate: [0, 2, 6, 3, 23, 59, 59, 999], DaylightDate: [0, 10, 6, 3, 23, 59, 59, 999]),
      2014: FakeTzi(Bias: 180, DaylightBias: -60, StandardDate: [0, 2, 6, 3, 23, 59, 59, 999], DaylightDate: [0, 10, 6, 3, 23, 59, 59, 999]),
      2015: FakeTzi(Bias: 180, DaylightBias: -60, StandardDate: [0, 2, 6, 3, 23, 59, 59, 999], DaylightDate: [0, 10, 6, 3, 23, 59, 59, 999]),
      2016: FakeTzi(Bias: 180, DaylightBias: -60, StandardDate: [0, 2, 6, 3, 23, 59, 59, 999], DaylightDate: [0, 10, 6, 3, 23, 59, 59, 999]),
      2017: FakeTzi(Bias: 180, DaylightBias: -60, StandardDate: [0, 2, 6, 3, 23, 59, 59, 999], DaylightDate: [0, 10, 6, 2, 23, 59, 59, 999]),
      2018: FakeTzi(Bias: 180, DaylightBias: -60, StandardDate: [0, 2, 6, 3, 23, 59, 59, 999], DaylightDate: [0, 11, 6, 1, 23, 59, 59, 999]),
      2019: FakeTzi(Bias: 180, DaylightBias: -60, StandardDate: [0, 2, 0, 3, 0, 0, 0, 0], DaylightDate: [0, 1, 2, 1, 0, 0, 0, 0]),
      2020: FakeTzi(Bias: 180, DaylightBias: -60),
    },
  ),
);

/// Samoa: crossed the date line at the end of 2011 (UTC-11 → UTC+13), so its rules have their own base offsets.
const FakeZone SamoaZone = FakeZone(
  Id: 'Samoa Standard Time',
  Display: '(UTC+13:00) Samoa',
  Std: 'Samoa Standard Time',
  Dlt: 'Samoa Daylight Time',
  Tzi: FakeTzi(Bias: -780, DaylightBias: -60),
  Dynamic: FakeDynamicDst(
    First: 2009,
    Last: 2022,
    Years: {
      2009: FakeTzi(Bias: 660, DaylightBias: -60),
      2010: FakeTzi(Bias: 660, DaylightBias: -60, StandardDate: [0, 1, 5, 1, 0, 0, 0, 0], DaylightDate: [0, 9, 0, 5, 0, 0, 0, 0]),
      2011: FakeTzi(Bias: 660, DaylightBias: -60, StandardDate: [0, 4, 6, 1, 4, 0, 0, 0], DaylightDate: [0, 9, 6, 4, 3, 0, 0, 0]),
      2012: FakeTzi(Bias: -780, DaylightBias: -60, StandardDate: [0, 4, 0, 1, 4, 0, 0, 0], DaylightDate: [0, 9, 0, 5, 3, 0, 0, 0]),
      2013: FakeTzi(Bias: -780, DaylightBias: -60, StandardDate: [0, 4, 0, 1, 4, 0, 0, 0], DaylightDate: [0, 9, 0, 5, 3, 0, 0, 0]),
      2014: FakeTzi(Bias: -780, DaylightBias: -60, StandardDate: [0, 4, 0, 1, 4, 0, 0, 0], DaylightDate: [0, 9, 0, 5, 3, 0, 0, 0]),
      2015: FakeTzi(Bias: -780, DaylightBias: -60, StandardDate: [0, 4, 0, 1, 4, 0, 0, 0], DaylightDate: [0, 9, 0, 5, 3, 0, 0, 0]),
      2016: FakeTzi(Bias: -780, DaylightBias: -60, StandardDate: [0, 4, 0, 1, 4, 0, 0, 0], DaylightDate: [0, 9, 0, 5, 3, 0, 0, 0]),
      2017: FakeTzi(Bias: -780, DaylightBias: -60, StandardDate: [0, 4, 0, 1, 4, 0, 0, 0], DaylightDate: [0, 9, 0, 5, 3, 0, 0, 0]),
      2018: FakeTzi(Bias: -780, DaylightBias: -60, StandardDate: [0, 4, 0, 1, 4, 0, 0, 0], DaylightDate: [0, 9, 0, 5, 3, 0, 0, 0]),
      2019: FakeTzi(Bias: -780, DaylightBias: -60, StandardDate: [0, 4, 0, 1, 4, 0, 0, 0], DaylightDate: [0, 9, 0, 5, 3, 0, 0, 0]),
      2020: FakeTzi(Bias: -780, DaylightBias: -60, StandardDate: [0, 4, 0, 1, 4, 0, 0, 0], DaylightDate: [0, 9, 0, 5, 3, 0, 0, 0]),
      2021: FakeTzi(Bias: -780, DaylightBias: -60, StandardDate: [0, 4, 0, 1, 4, 0, 0, 0], DaylightDate: [0, 1, 5, 1, 0, 0, 0, 0]),
      2022: FakeTzi(Bias: -780, DaylightBias: -60),
    },
  ),
);

// #endregion

const List<FakeZone> FakeZones = [UtcZone, UtcMinus02Zone, SaWesternZone, AusEasternZone, ESouthAmericaZone, SamoaZone];
