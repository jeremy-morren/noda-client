// noda-js: new code. The error type for every exception NodaTime throws; see docs/porting-conventions.md ("Exceptions").

import type { AmbiguousTimeException } from "../AmbiguousTimeException.ts";
import type { SkippedTimeException } from "../SkippedTimeException.ts";
import type { InvalidPatternException } from "../Text/InvalidPatternException.ts";
import type { UnparsableValueException } from "../Text/UnparsableValueException.ts";
import type { DateTimeZoneNotFoundException } from "../TimeZones/DateTimeZoneNotFoundException.ts";
import type { InvalidDateTimeZoneSourceException } from "../TimeZones/InvalidDateTimeZoneSourceException.ts";
import type { InvalidNodaDataException } from "./InvalidNodaDataException.ts";
import type { ArgumentException, ArgumentNullException, ArgumentOutOfRangeException, HttpRequestException } from "./SystemExceptions.ts";

/** Each .NET exception type's base types, nearest first, excluding Exception. */
const BaseCodesByCode = {
  SystemException: [],
  ArgumentException: ["SystemException"],
  ArgumentNullException: ["ArgumentException", "SystemException"],
  ArgumentOutOfRangeException: ["ArgumentException", "SystemException"],
  ArithmeticException: ["SystemException"],
  DivideByZeroException: ["ArithmeticException", "SystemException"],
  OverflowException: ["ArithmeticException", "SystemException"],
  FormatException: ["SystemException"],
  IndexOutOfRangeException: ["SystemException"],
  InvalidCastException: ["SystemException"],
  InvalidOperationException: ["SystemException"],
  KeyNotFoundException: ["SystemException"],
  NotImplementedException: ["SystemException"],
  NotSupportedException: ["SystemException"],
  InvalidDataException: ["SystemException"],
  HttpRequestException: [],
  TimeZoneNotFoundException: [],
  InvalidTimeZoneException: [],

  AmbiguousTimeException: ["ArgumentOutOfRangeException", "ArgumentException", "SystemException"],
  SkippedTimeException: ["ArgumentOutOfRangeException", "ArgumentException", "SystemException"],
  InvalidPatternException: ["FormatException", "SystemException"],
  UnparsableValueException: ["FormatException", "SystemException"],
  DateTimeZoneNotFoundException: ["TimeZoneNotFoundException"],
  InvalidDateTimeZoneSourceException: [],
  InvalidNodaDataException: [],
  MissingTokenException: [],
  DebugPreconditionException: [],
} as const;

/** The name of a .NET exception type that a {@link NodaError} can be (the first of its {@link NodaError.Codes}). */
export type NodaErrorCode = keyof typeof BaseCodesByCode;

/** The codes of exception type `TCode` as a literal tuple: `TCode`, then its base types, nearest first. */
export type NodaErrorCodes<TCode extends NodaErrorCode> =
  TCode extends NodaErrorCode ? readonly [TCode, ...(typeof BaseCodesByCode)[TCode]] : never;

/** The codes of the exception type `TCode` and the types derived from it (as a C# catch clause catches them). */
export type NodaErrorCodeOrDerived<TCode extends NodaErrorCode> = {
  [TOther in NodaErrorCode]: TCode extends NodaErrorCodes<TOther>[number] ? TOther : never;
}[NodaErrorCode];

/** Each code's {@link NodaErrorCodes}, made on first use (frozen: errors of a type share them). */
const codesByCode = new Map<NodaErrorCode, readonly NodaErrorCode[]>();

/** `code`, then its base types, nearest first. @internal */
export function GetNodaErrorCodes<TCode extends NodaErrorCode>(code: TCode): NodaErrorCodes<TCode> {
  let codes = codesByCode.get(code);
  if (codes === undefined) {
    codes = Object.freeze([code, ...(BaseCodesByCode[code] as readonly NodaErrorCode[])]);
    codesByCode.set(code, codes);
  }
  return codes as unknown as NodaErrorCodes<TCode>;
}

/** Every code (for the tests). @internal */
export function GetAllNodaErrorCodes(): readonly NodaErrorCode[] {
  return Object.keys(BaseCodesByCode) as NodaErrorCode[];
}

/**
 * An error thrown by noda-js: one of the .NET exceptions NodaTime throws, named by {@link Codes}.
 *
 * ```ts
 * try {
 *   LocalDatePattern.Iso.Parse(text).Value;
 * } catch (e) {
 *   if (IsNodaError(e, "FormatException")) { ... } // e.Codes[0] is "UnparsableValueException"
 *   throw e;
 * }
 * ```
 */
export class NodaError<TCode extends NodaErrorCode = NodaErrorCode> extends Error {
  /** The .NET exception type's name, then its base types', nearest first (without Exception). */
  readonly Codes: NodaErrorCodes<TCode>;

  /**
   * Creates an error.
   * @param code The name of the .NET exception type.
   * @param message The message.
   * @param options The error's cause, if any.
   */
  constructor(code: TCode, message: string, options?: { cause?: unknown }) {
    super(message, options);
    this.Codes = GetNodaErrorCodes(code);
    this.name = code;
  }
}

/** The first of the error's Codes if it's a NodaError (from any copy of noda-js), else undefined. */
function CodeOf(value: unknown): NodaErrorCode | undefined {
  if (!(value instanceof Error)) {
    return undefined;
  }
  const codes = (value as { Codes?: unknown }).Codes;
  const code = Array.isArray(codes) ? codes[0] as unknown : undefined;
  return typeof code === "string" && Object.prototype.hasOwnProperty.call(BaseCodesByCode, code) ? code as NodaErrorCode : undefined;
}

/**
 * Whether the value is a {@link NodaError} (from any copy of noda-js) of `code` or a type derived from it, as a C# catch clause.
 * @param value The value to check.
 * @param code The .NET exception type's name; omitted for any NodaError.
 */
export function IsNodaError<TCode extends NodaErrorCode>(value: unknown, code: TCode): value is NodaErrorType<TCode>;
export function IsNodaError(value: unknown): value is NodaError;
export function IsNodaError(value: unknown, code?: NodaErrorCode): boolean {
  const own = CodeOf(value);
  return own !== undefined && (code === undefined || (GetNodaErrorCodes(own) as readonly NodaErrorCode[]).indexOf(code) !== -1);
}

/** What {@link IsNodaError} narrows to, with the type's own members (e.g. `ParamName`). */
export type NodaErrorType<TCode extends NodaErrorCode> =
  TCode extends keyof NodaErrorTypeMap ? NodaErrorTypeMap[TCode] : NodaError<NodaErrorCodeOrDerived<TCode>>;

/** The error types with members beyond {@link NodaError}'s, by code. */
export interface NodaErrorTypeMap {
  ArgumentException: ArgumentException;
  ArgumentNullException: ArgumentNullException;
  ArgumentOutOfRangeException: ArgumentOutOfRangeException;
  HttpRequestException: HttpRequestException;
  AmbiguousTimeException: AmbiguousTimeException;
  SkippedTimeException: SkippedTimeException;
  InvalidPatternException: InvalidPatternException;
  UnparsableValueException: UnparsableValueException;
  DateTimeZoneNotFoundException: DateTimeZoneNotFoundException;
  InvalidDateTimeZoneSourceException: InvalidDateTimeZoneSourceException;
  InvalidNodaDataException: InvalidNodaDataException;
}
