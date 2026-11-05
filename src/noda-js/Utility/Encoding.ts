// noda-js: UTF-8 and base64 decoding, for reading NZD (tzdb) data. 
// Uses the host's TextDecoder / Uint8Array.fromBase64 / atob when it has them, and plain JavaScript otherwise,
// so the library also runs on engines without those web APIs

let utf8Decoder: TextDecoder | undefined;

/** Decodes UTF-8 bytes to a string. */
export function DecodeUtf8(bytes: Uint8Array): string {
  if (typeof TextDecoder === "function") {
    return (utf8Decoder ??= new TextDecoder("utf-8")).decode(bytes);
  }
  return DecodeUtf8Fallback(bytes);
}

/**
 * Decodes UTF-8 bytes to a string in plain JavaScript.
 * Matches TextDecoder's result for valid UTF-8; an invalid lead byte becomes U+FFFD.
 * @internal
 */
export function DecodeUtf8Fallback(bytes: Uint8Array): string {
  const codePoints: number[] = [];
  let result = "";
  for (let i = 0; i < bytes.length;) {
    const lead = bytes[i++]!;
    let codePoint: number;
    if (lead < 0x80) {
      codePoint = lead;
    } else if (lead >= 0xc0 && lead < 0xe0) {
      codePoint = ((lead & 0x1f) << 6) | (bytes[i++]! & 0x3f);
    } else if (lead >= 0xe0 && lead < 0xf0) {
      codePoint = ((lead & 0x0f) << 12) | ((bytes[i++]! & 0x3f) << 6) | (bytes[i++]! & 0x3f);
    } else if (lead >= 0xf0 && lead < 0xf8) {
      codePoint = ((lead & 0x07) << 18) | ((bytes[i++]! & 0x3f) << 12) | ((bytes[i++]! & 0x3f) << 6) | (bytes[i++]! & 0x3f);
    } else {
      codePoint = 0xfffd;
    }
    codePoints.push(codePoint);
    // String.fromCodePoint takes arguments, so convert in chunks (engines limit the argument count).
    if (codePoints.length === 4096) {
      result += String.fromCodePoint(...codePoints);
      codePoints.length = 0;
    }
  }
  return result + String.fromCodePoint(...codePoints);
}

/** Decodes base64 text to bytes. */
export function DecodeBase64(text: string): Uint8Array {
  // eslint-disable-next-line es-x/no-uint8array-frombase64 -- feature-detected, with fallbacks below
  const fromBase64 = (Uint8Array as unknown as { fromBase64?: (text: string) => Uint8Array }).fromBase64;
  if (typeof fromBase64 === "function") {
    return fromBase64.call(Uint8Array, text);
  }
  if (typeof atob === "function") {
    const binary = atob(text);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  }
  return DecodeBase64Fallback(text);
}

const Base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
let base64Values: Int8Array | undefined;

/**
 * Decodes (padded or unpadded) base64 text to bytes in plain JavaScript.
 * @internal
 */
export function DecodeBase64Fallback(text: string): Uint8Array {
  if (base64Values === undefined) {
    base64Values = new Int8Array(128).fill(-1);
    for (let i = 0; i < Base64Alphabet.length; i++) {
      base64Values[Base64Alphabet.charCodeAt(i)] = i;
    }
  }
  let length = text.length;
  while (length > 0 && text.charCodeAt(length - 1) === 61 /* = */) {
    length--;
  }
  const bytes = new Uint8Array(Math.floor((length * 3) / 4));
  let buffer = 0;
  let bits = 0;
  let output = 0;
  for (let i = 0; i < length; i++) {
    const code = text.charCodeAt(i);
    const value = code < 128 ? base64Values[code]! : -1;
    if (value < 0) {
      throw new TypeError(`Invalid base64 character at position ${i}.`);
    }
    buffer = (buffer << 6) | value;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      bytes[output++] = (buffer >> bits) & 0xff;
    }
  }
  return bytes;
}
