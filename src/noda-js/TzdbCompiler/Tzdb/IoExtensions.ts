// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Tzdb/IoExtensions.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { DecodeUtf8 } from "../../Utility/Encoding.ts";
import { FileSource } from "../internal.ts";

/**
 * IO-related extension methods
 *
 * noda-js: merges NodaTime's ReadLines overloads. A stream is a byte array, decoded as UTF-8 as a StreamReader
 * does by default (skipping a leading byte order mark); a TextReader is the text itself, as a string; the
 * `Func<TextReader>` overload (only used to implement the FileSource one) isn't needed.
 * Lines are split as TextReader.ReadLine splits them: at "\r\n", "\n" or "\r".
 * @internal
 */
export function ReadLines(source: FileSource, name: string): Iterable<string>;
/** @internal */
export function ReadLines(input: Uint8Array | string): Iterable<string>;
export function ReadLines(input: FileSource | Uint8Array | string, name?: string): Iterable<string> {
  if (input instanceof FileSource) {
    return ReadLines(input.Open(name!));
  }
  return ReadTextLines(typeof input === "string" ? input : DecodeStream(input));
}

/** new StreamReader(stream).ReadToEnd(), for a stream holding the given bytes. */
function DecodeStream(bytes: Uint8Array): string {
  const text = DecodeUtf8(bytes);
  return text.charCodeAt(0) === 0xFEFF ? text.substring(1) : text;
}

function* ReadTextLines(text: string): Iterable<string> {
  let start = 0;
  while (start < text.length) {
    let end = start;
    while (end < text.length && text.charAt(end) !== "\r" && text.charAt(end) !== "\n") {
      end++;
    }
    yield text.substring(start, end);
    if (end < text.length && text.charAt(end) === "\r" && end + 1 < text.length && text.charAt(end + 1) === "\n") {
      end++;
    }
    start = end + 1;
  }
}
