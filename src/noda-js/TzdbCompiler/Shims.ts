// noda-js: equivalents of the .NET library members the tzdb compiler (NodaTime.TzdbCompiler) uses that the
// core doesn't need: System.IO.InvalidDataException, System.NotImplementedException, and the parsing/text
// helpers (Int32.Parse, Double.Parse, char.IsWhiteSpace, char.IsLetter, string.TrimEnd, Path.GetFileName,
// the dictionary indexer and Dictionary.Add) with .NET's semantics.

import { NewArgumentException, NewFormatException, NewKeyNotFoundException, NewOverflowException, type ArgumentException, type FormatException, type InvalidDataException, type KeyNotFoundException, type NotImplementedException, type OverflowException } from "../internal.ts";



/** The characters .NET's NumberStyles.AllowLeadingWhite/AllowTrailingWhite accept: U+0009-U+000D and U+0020. */
const NumberWhite = "[\\t\\n\\v\\f\\r ]*";
const IntegerRegex = new RegExp(`^${NumberWhite}([+-]?)([0-9]+)${NumberWhite}$`);
const UnsignedIntegerRegex = new RegExp(`^${NumberWhite}()([0-9]+)${NumberWhite}$`);
const DecimalRegex = new RegExp(`^${NumberWhite}([0-9]*(?:\\.[0-9]*)?)${NumberWhite}$`);

/**
 * int.Parse(text, style, CultureInfo.InvariantCulture), for NumberStyles.Integer (`allowSign` true: leading/trailing
 * white space and a leading sign) or NumberStyles.AllowLeadingWhite | NumberStyles.AllowTrailingWhite (`allowSign`
 * false).
 * @throws {FormatException} The text isn't in the expected format.
 * @throws {OverflowException} The value is outside the range of an int.
 */
export function ParseInt32(text: string, allowSign: boolean = true): number {
  const match = (allowSign ? IntegerRegex : UnsignedIntegerRegex).exec(text);
  if (match === null) {
    throw NewFormatException(`The input string '${text}' was not in a correct format.`);
  }
  const value = Number(match[2]!) * (match[1] === "-" ? -1 : 1);
  if (value < -2147483648 || value > 2147483647) {
    throw NewOverflowException("Value was either too large or too small for an Int32.");
  }
  return value + 0;
}

/**
 * int.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out value): the value, or null if the text
 * can't be parsed.
 */
export function TryParseInt32(text: string): number | null {
  try {
    return ParseInt32(text);
  } catch {
    return null;
  }
}

/**
 * double.Parse(text, NumberStyles.AllowLeadingWhite | NumberStyles.AllowTrailingWhite | NumberStyles.AllowDecimalPoint,
 * CultureInfo.InvariantCulture).
 * @throws {FormatException} The text isn't in the expected format.
 */
export function ParseDecimalDouble(text: string): number {
  const match = DecimalRegex.exec(text);
  if (match === null || !/[0-9]/.test(match[1]!)) {
    throw NewFormatException(`The input string '${text}' was not in a correct format.`);
  }
  return Number(match[1]!);
}

/** char.IsWhiteSpace(c): Unicode white space (JS `\s` without U+FEFF, which .NET doesn't count as white space). */
export function IsWhiteSpace(c: string): boolean {
  return c !== "﻿" && /^\s$/.test(c);
}

/** string.TrimEnd(): removes trailing white space, as {@link IsWhiteSpace} defines it. */
export function TrimEnd(text: string): string {
  let end = text.length;
  while (end > 0 && IsWhiteSpace(text.charAt(end - 1))) {
    end--;
  }
  return text.substring(0, end);
}

/** string.Trim(): removes leading and trailing white space, as {@link IsWhiteSpace} defines it. */
export function Trim(text: string): string {
  let start = 0;
  while (start < text.length && IsWhiteSpace(text.charAt(start))) {
    start++;
  }
  return TrimEnd(text.substring(start));
}

/**
 * char.IsLetter(c), for a single UTF-16 code unit. (ES2015 has no Unicode property escapes: a character is taken
 * to be a letter if it is an ASCII letter, or has distinct upper and lower case forms, or is in one of the main
 * caseless letter blocks. The compiler only checks the last character of a time such as "2:00s".)
 */
export function IsLetter(c: string): boolean {
  if (/^[A-Za-z]$/.test(c)) {
    return true;
  }
  const code = c.charCodeAt(0);
  if (code < 0x80) {
    return false;
  }
  return c.toLowerCase() !== c.toUpperCase() || /^[ªºƻǀ-ǃʔא-תؠ-يぁ-ヿ㐀-䶿一-鿿가-힣]$/.test(c);
}

/**
 * Path.GetFileName(path): the part of the path after the last directory separator ('/' or '\\').
 */
export function GetFileName(path: string): string {
  const index = Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\"));
  return path.substring(index + 1);
}

/** The dictionary indexer's getter, `dictionary[key]`: throws {@link KeyNotFoundException} if the key is missing. */
export function GetValue<K, V>(dictionary: ReadonlyMap<K, V>, key: K): V {
  if (!dictionary.has(key)) {
    throw NewKeyNotFoundException(`The given key '${String(key)}' was not present in the dictionary.`);
  }
  return dictionary.get(key)!;
}

/** Dictionary.Add(key, value): throws {@link ArgumentException} if the key is already present. */
export function AddValue<K, V>(dictionary: Map<K, V>, key: K, value: V): void {
  if (dictionary.has(key)) {
    throw NewArgumentException(`An item with the same key has already been added. Key: ${String(key)}`);
  }
  dictionary.set(key, value);
}

/**
 * string.CompareOrdinal(a, b) as a sort comparison (StringComparer.Ordinal): compares UTF-16 code units, which is
 * what JS's relational operators on strings do.
 */
export function CompareOrdinal(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}
