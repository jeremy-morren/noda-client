// noda_dart: new code. The tzdb compiler's file system and HTTP access, per platform.

export 'FileSystem_stub.dart'
    if (dart.library.io) 'FileSystem_io.dart'
    if (dart.library.js_interop) 'FileSystem_web.dart';
