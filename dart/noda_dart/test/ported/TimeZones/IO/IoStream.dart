// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/IO/IoStream.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: our Stream has only Read, Write, ReadByte and WriteByte.

import 'dart:typed_data';

import 'package:noda_dart/src/Utility/Stream.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';

import '../../../helpers/Assertions.dart';

/// Provides a simple, fixed-size, pipe-like stream that has a writer and a reader.
///
/// When the buffer fills up an exception is thrown and currently the buffer is fixed at 4096. The write
/// pointer does not wrap so only a total of 4096 bytes can ever be written to the stream. This is designed
/// for testing purposes and not real-world uses.
class IoStream {
  final Uint8List _buffer = Uint8List(4096);
  int _readIndex = 0;
  Stream? _readStream;
  int _writeIndex = 0;
  Stream? _writeStream;

  /// Returns the next byte from the stream if there is one.
  ///
  /// Returns the next byte.
  ///
  /// Throws [IOException] There are no more bytes in the buffer.
  int _GetByte() {
    if (_readIndex >= _writeIndex) {
      throw IOException('IoStream buffer empty in GetByte()');
    }
    return _buffer[_readIndex++];
  }

  void AssertEndOfStream() {
    Assert.AreEqual(_readIndex, _writeIndex);
  }

  void AssertUnreadContents(List<int> expected) {
    Assert.AreEqual(expected.length, _writeIndex - _readIndex);
    var actual = Uint8List(expected.length);
    actual.setRange(0, _writeIndex - _readIndex, _buffer, _readIndex);
    Assert.AreEqual(expected, actual);
    _readIndex = _writeIndex;
  }

  /// Returns a [Stream] that can be used to read from the buffer.
  ///
  /// This can only be called once for each instance i.e. only one reader is permitted per buffer.
  ///
  /// Returns the read-only [Stream].
  ///
  /// Throws [StateError] A reader was already requested.
  Stream GetReadStream() {
    if (_readStream != null) {
      throw StateError('Cannot call GetReadStream() twice on the same object.');
    }
    _readStream = _ReadStreamImpl(this);
    return _readStream!;
  }

  /// Returns a [Stream] that can be used to write to the buffer.
  ///
  /// This can only be called once for each instance i.e. only one writer is permitted per buffer.
  ///
  /// Returns the write-only [Stream].
  ///
  /// Throws [StateError] A writer was already requested.
  Stream GetWriteStream() {
    if (_writeStream != null) {
      throw StateError('Cannot call GetWriteStream() twice on the same object.');
    }
    _writeStream = _WriteStreamImpl(this);
    return _writeStream!;
  }

  /// Adds a byte to the buffer.
  ///
  /// [value]: The byte to add.
  ///
  /// Throws [IOException] The buffer has been filled.
  void _PutByte(int value) {
    if (_writeIndex >= _buffer.length) {
      throw IOException('Exceeded the IoStream buffer size of ${_buffer.length}');
    }
    _buffer[_writeIndex++] = value;
  }

  /// Resets the stream to be empty.
  void Reset() {
    _writeIndex = 0;
    _readIndex = 0;
  }
}

// #region Nested type: ReadStreamImpl
/// Provides a read-only [Stream] implementation for reading from the buffer.
class _ReadStreamImpl extends Stream {
  final IoStream _ioStream;

  /// Initializes a new instance of the [_ReadStreamImpl] class.
  ///
  /// [stream]: The [IoStream] to read from.
  _ReadStreamImpl(IoStream stream) : _ioStream = stream;

  // Not ported: CanRead, CanSeek, CanWrite, Length, Position, Flush (noda_dart's Stream doesn't have them).

  @override
  int Read(Uint8List buffer, int offset, int count) {
    count = count < _ioStream._writeIndex - _ioStream._readIndex ? count : _ioStream._writeIndex - _ioStream._readIndex;
    for (int i = 0; i < count; i++) {
      buffer[i + offset] = _ioStream._GetByte();
    }
    return count;
  }

  // Not ported: Seek, SetLength (noda_dart's Stream doesn't have them).

  @override
  void Write(Uint8List buffer, int offset, int count) {
    throw UnsupportedError('');
  }
}
// #endregion

// #region Nested type: WriteStreamImpl
/// Provides a write-only [Stream] implementation for writing to the buffer.
class _WriteStreamImpl extends Stream {
  final IoStream _ioStream;

  /// Initializes a new instance of the [_WriteStreamImpl] class.
  ///
  /// [stream]: The [IoStream] to write to.
  _WriteStreamImpl(IoStream stream) : _ioStream = stream;

  // Not ported: CanRead, CanSeek, CanWrite, Length, Position, Flush (noda_dart's Stream doesn't have them).

  @override
  int Read(Uint8List buffer, int offset, int count) {
    throw UnsupportedError('');
  }

  // Not ported: Seek, SetLength (noda_dart's Stream doesn't have them).

  @override
  void Write(Uint8List buffer, int offset, int count) {
    if (count > _ioStream._buffer.length - _ioStream._writeIndex) {
      throw StateError('The I/O buffer is full');
    }
    for (int i = 0; i < count; i++) {
      _ioStream._PutByte(buffer[i + offset]);
    }
  }
}
// #endregion
