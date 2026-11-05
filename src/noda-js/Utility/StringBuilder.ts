// noda-js: minimal equivalent of System.Text.StringBuilder, so ported code can stay close to the C#.

import { PadEnd } from "./StringPadding.ts";

/**
 * noda-js's stand-in for System.Text.StringBuilder (IPattern.AppendFormat takes one).
 *
 * Not part of the public API (no entry point exports it), but deliberately not tagged internal: public declarations refer to it,
 * so it must stay in the published type declarations.
 */
export class StringBuilder {
  private _value: string;

  constructor(value: string = "") {
    this._value = value;
  }

  get Length(): number {
    return this._value.length;
  }

  /** Truncates (or pads with NUL, as .NET does) to the given length. */
  set Length(length: number) {
    this._value = length <= this._value.length ? this._value.substring(0, length) : PadEnd(this._value, length, "\0");
  }

  /** Appends text. Like .NET's Append(char, int), an optional repeat count is supported. */
  Append(text: string | number, repeatCount: number = 1): this {
    const s = typeof text === "number" ? String(text) : text;
    this._value += repeatCount === 1 ? s : s.repeat(repeatCount);
    return this;
  }

  Insert(index: number, text: string): this {
    this._value = this._value.substring(0, index) + text + this._value.substring(index);
    return this;
  }

  CharAt(index: number): string {
    return this._value.charAt(index);
  }

  SetCharAt(index: number, ch: string): void {
    this._value = this._value.substring(0, index) + ch + this._value.substring(index + 1);
  }

  Clear(): this {
    this._value = "";
    return this;
  }

  toString(): string {
    return this._value;
  }
}
