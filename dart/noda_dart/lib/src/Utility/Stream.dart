// noda_dart: new code. Minimal System.IO.Stream and MemoryStream, for the NZD reading and writing code.

import 'dart:typed_data';

import 'package:meta/meta.dart';

/// `System.IO.Stream`, with only the members NodaTime's NZD code uses.
@internal
abstract class Stream {
  /// Reads up to [count] bytes into [buffer] at [offset], returning the number of bytes read
  /// (0 at the end of the stream).
  int Read(Uint8List buffer, int offset, int count);

  /// Writes [count] bytes from [buffer], starting at [offset], to the stream.
  void Write(Uint8List buffer, int offset, int count);

  /// Reads a byte from the stream, or returns -1 at the end of the stream.
  int ReadByte() {
    final oneByteArray = Uint8List(1);
    return Read(oneByteArray, 0, 1) == 0 ? -1 : oneByteArray[0];
  }

  /// Writes a byte (the low 8 bits of [value]) to the stream.
  void WriteByte(int value) {
    Write(Uint8List.fromList([value & 0xff]), 0, 1);
  }
}

/// `System.IO.MemoryStream`: growable when created empty, fixed-length over a given buffer.
@internal
final class MemoryStream extends Stream {
  Uint8List _data;
  int _length;
  int _position = 0;
  final bool _expandable;
  final bool _writable;

  /// `new MemoryStream()`, `new MemoryStream(byte[] buffer)` and `new MemoryStream(byte[] buffer, bool writable)`.
  MemoryStream([Uint8List? buffer, bool writable = true])
      : _data = buffer ?? Uint8List(256),
        _length = buffer?.length ?? 0,
        _expandable = buffer == null,
        _writable = writable;

  /// The length of the stream in bytes.
  int get Length => _length;

  /// The current position within the stream.
  int get Position => _position;

  set Position(int value) {
    if (value < 0) {
      throw RangeError.value(value, 'value', 'Non-negative number required.');
    }
    _position = value;
  }

  /// Reads a byte from the stream, or returns -1 at the end of the stream.
  @override
  int ReadByte() => _position < _length ? _data[_position++] : -1;

  /// Reads up to [count] bytes into [buffer] at [offset], returning the number of bytes read
  /// (0 at the end of the stream).
  @override
  int Read(Uint8List buffer, int offset, int count) {
    final available = _length - _position;
    final n = count < available ? count : available;
    if (n <= 0) {
      return 0;
    }
    buffer.setRange(offset, offset + n, _data, _position);
    _position += n;
    return n;
  }

  /// Writes a byte (the low 8 bits of [value]) to the stream at the current position.
  @override
  void WriteByte(int value) {
    _EnsureWritable();
    _EnsureCapacity(_position + 1);
    _data[_position++] = value & 0xff;
    if (_position > _length) {
      _length = _position;
    }
  }

  /// Writes [count] bytes from [buffer], starting at [offset], to the stream at the current position.
  @override
  void Write(Uint8List buffer, int offset, int count) {
    _EnsureWritable();
    final end = _position + count;
    _EnsureCapacity(end);
    _data.setRange(_position, end, buffer, offset);
    _position = end;
    if (end > _length) {
      _length = end;
    }
  }

  /// Writes the entire contents of this stream (regardless of its position) to another stream.
  void WriteTo(Stream stream) {
    stream.Write(_data, 0, _length);
  }

  /// Returns a copy of the stream's contents (regardless of its position).
  Uint8List ToArray() => Uint8List.fromList(Uint8List.sublistView(_data, 0, _length));

  void _EnsureWritable() {
    if (!_writable) {
      throw UnsupportedError('Stream does not support writing.');
    }
  }

  void _EnsureCapacity(int capacity) {
    if (capacity <= _data.length) {
      return;
    }
    if (!_expandable) {
      throw UnsupportedError('Memory stream is not expandable.');
    }
    final newData = Uint8List(capacity > _data.length * 2 ? capacity : _data.length * 2);
    newData.setRange(0, _length, _data);
    _data = newData;
  }
}
