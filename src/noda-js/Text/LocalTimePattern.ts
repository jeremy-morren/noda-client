// Ported from NodaTime 3.3.0: src/NodaTime/Text/LocalTimePattern.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { CompositePatternBuilder, LocalTime, LocalTimePatternParser, NodaFormatInfo, PatternBclSupport, Preconditions } from "../internal.ts";
import type { NodaCultureInfo, IPartialPattern, IPattern, ParseResult, StringBuilder } from "../internal.ts";

const DefaultFormatPattern = "T"; // Long

let bclSupport: PatternBclSupport<LocalTime> | undefined;
let extendedIsoPatternImpl: LocalTimePattern | undefined;
let longExtendedIsoPatternImpl: LocalTimePattern | undefined;
let generalIsoPatternImpl: LocalTimePattern | undefined;
let hourIsoPatternImpl: LocalTimePattern | undefined;
let hourMinuteIsoPatternImpl: LocalTimePattern | undefined;
let variablePrecisionIsoPatternImpl: IPattern<LocalTime> | undefined;

/**
 * Class whose existence is solely to avoid type initialization order issues, most of which stem
 * from needing NodaFormatInfo.InvariantInfo...
 * (C#: LocalTimePattern.Patterns)
 * @internal
 */
export class LocalTimePatternPatterns {
  private constructor() {}

  static get ExtendedIsoPatternImpl(): LocalTimePattern {
    return (extendedIsoPatternImpl ??= LocalTimePattern.CreateWithInvariantCulture("HH':'mm':'ss;FFFFFFFFF"));
  }
  static get LongExtendedIsoPatternImpl(): LocalTimePattern {
    return (longExtendedIsoPatternImpl ??= LocalTimePattern.CreateWithInvariantCulture("HH':'mm':'ss;fffffffff"));
  }
  static get GeneralIsoPatternImpl(): LocalTimePattern {
    return (generalIsoPatternImpl ??= LocalTimePattern.CreateWithInvariantCulture("HH':'mm':'ss"));
  }
  static get HourIsoPatternImpl(): LocalTimePattern {
    return (hourIsoPatternImpl ??= LocalTimePattern.CreateWithInvariantCulture("HH"));
  }
  static get HourMinuteIsoPatternImpl(): LocalTimePattern {
    return (hourMinuteIsoPatternImpl ??= LocalTimePattern.CreateWithInvariantCulture("HH':'mm"));
  }
  static get VariablePrecisionIsoPatternImpl(): IPattern<LocalTime> {
    if (variablePrecisionIsoPatternImpl === undefined) {
      const builder = new CompositePatternBuilder<LocalTime>();
      builder.Add(LocalTimePatternPatterns.ExtendedIsoPatternImpl, (time) => true);
      builder.Add(LocalTimePatternPatterns.HourMinuteIsoPatternImpl, (time) => time.Second === 0 && time.NanosecondOfSecond === 0);
      builder.Add(LocalTimePatternPatterns.HourIsoPatternImpl, (time) => time.Minute === 0 && time.Second === 0 && time.NanosecondOfSecond === 0);
      variablePrecisionIsoPatternImpl = builder.Build();
    }
    return variablePrecisionIsoPatternImpl;
  }
}

/**
 * Represents a pattern for parsing and formatting {@link LocalTime} values.
 */
export class LocalTimePattern implements IPattern<LocalTime> {
  /**
   * Gets an invariant local time pattern which is ISO-8601 compatible, providing up to 9 decimal places.
   * (These digits are omitted when unnecessary.)
   * This corresponds to the text pattern "HH':'mm':'ss;FFFFFFFFF".
   *
   * This pattern corresponds to the 'o' standard pattern.
   */
  static get ExtendedIso(): LocalTimePattern {
    return LocalTimePatternPatterns.ExtendedIsoPatternImpl;
  }

  /**
   * Gets an invariant local time pattern which is ISO-8601 compatible, providing exactly 9 decimal places.
   * This corresponds to the text pattern "HH':'mm':'ss;fffffffff".
   *
   * This pattern corresponds to the 'O' standard pattern.
   */
  static get LongExtendedIso(): LocalTimePattern {
    return LocalTimePatternPatterns.LongExtendedIsoPatternImpl;
  }

  /**
   * Gets an invariant local time pattern which is ISO-8601 compatible, with precision of just seconds.
   * This corresponds to the text pattern "HH':'mm':'ss".
   */
  static get GeneralIso(): LocalTimePattern {
    return LocalTimePatternPatterns.GeneralIsoPatternImpl;
  }

  /**
   * Gets an invariant local time pattern which is ISO-8601 compatible, with precision of just minutes.
   * This corresponds to the text pattern "HH':'mm".
   */
  static get HourMinuteIso(): LocalTimePattern {
    return LocalTimePatternPatterns.HourMinuteIsoPatternImpl;
  }

  /**
   * Gets an invariant local time pattern which is ISO-8601 compatible, with a precision of just hours.
   * This corresponds to the text pattern "HH".
   */
  static get HourIso(): LocalTimePattern {
    return LocalTimePatternPatterns.HourIsoPatternImpl;
  }

  /**
   * Gets an invariant local time pattern which can parse any ISO-8601 compatible value
   * (in extended format, that is, with separators), regardless of precision.
   * Valid values include "just hours", "hours and minutes", "hours, minutes and seconds",
   * and values with fractions of seconds (as far as nanoseconds).
   *
   * This is expressed as an {@link IPattern} rather than a {@link LocalTimePattern},
   * as it has no single pattern text.
   */
  static get VariablePrecisionIso(): IPattern<LocalTime> {
    return LocalTimePatternPatterns.VariablePrecisionIsoPatternImpl;
  }

  /** @internal */
  static get BclSupport(): PatternBclSupport<LocalTime> {
    return (bclSupport ??= new PatternBclSupport<LocalTime>(DefaultFormatPattern, (fi) => fi.LocalTimePatternParser));
  }

  /**
   * Class whose existence is solely to avoid type initialization order issues.
   * @internal
   */
  static readonly Patterns = LocalTimePatternPatterns;

  /**
   * Returns the pattern that this object delegates to. Mostly useful to avoid this public class
   * implementing an internal interface.
   * @internal
   */
  readonly UnderlyingPattern: IPartialPattern<LocalTime>;

  private readonly _patternText: string;

  /** Gets the pattern text for this pattern, as supplied on creation. */
  get PatternText(): string {
    return this._patternText;
  }

  /** Gets the localization information used in this pattern. */
  private readonly _formatInfo: NodaFormatInfo;

  private readonly _templateValue: LocalTime;

  /**
   * Gets the value used as a template for parsing: any field values unspecified
   * in the pattern are taken from the template.
   */
  get TemplateValue(): LocalTime {
    return this._templateValue;
  }

  private constructor(patternText: string, formatInfo: NodaFormatInfo, templateValue: LocalTime, pattern: IPartialPattern<LocalTime>) {
    this._patternText = patternText;
    this._formatInfo = formatInfo;
    this._templateValue = templateValue;
    this.UnderlyingPattern = pattern;
  }

  /**
   * Parses the given text value according to the rules of this pattern.
   *
   * This method never throws an exception (barring a bug in Noda Time itself). Even errors such as
   * the argument being null are wrapped in a parse result.
   * @param text The text value to parse.
   * @returns The result of parsing, which may be successful or unsuccessful.
   */
  Parse(text: string): ParseResult<LocalTime> {
    return this.UnderlyingPattern.Parse(text);
  }

  /**
   * Formats the given local time as text according to the rules of this pattern.
   * @param value The local time to format.
   * @returns The local time formatted according to this pattern.
   */
  Format(value: LocalTime): string {
    return this.UnderlyingPattern.Format(value);
  }

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: LocalTime, builder: StringBuilder): StringBuilder {
    return this.UnderlyingPattern.AppendFormat(value, builder);
  }

  /**
   * Creates a pattern for the given pattern text, culture, and template value.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @param templateValue Template value to use for unspecified fields; defaults to midnight.
   * @returns A pattern for parsing and formatting local times.
   * @throws {InvalidPatternError} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo, templateValue?: LocalTime): LocalTimePattern;
  /**
   * Creates a pattern for the given pattern text, format info, and template value.
   * @param patternText Pattern text to create the pattern for
   * @param formatInfo The format info to use in the pattern
   * @param templateValue Template value to use for unspecified fields
   * @returns A pattern for parsing and formatting local times.
   * @throws {InvalidPatternError} The pattern text was invalid.
   * @internal
   */
  static Create(patternText: string, formatInfo: NodaFormatInfo, templateValue: LocalTime): LocalTimePattern;
  static Create(patternText: string, cultureOrFormatInfo: NodaCultureInfo | NodaFormatInfo, templateValue?: LocalTime): LocalTimePattern {
    if (!(cultureOrFormatInfo instanceof NodaFormatInfo)) {
      return LocalTimePattern.Create(patternText, NodaFormatInfo.GetFormatInfo(cultureOrFormatInfo), templateValue ?? LocalTime.Midnight);
    }
    const formatInfo = cultureOrFormatInfo;
    Preconditions.CheckNotNull(patternText, "patternText");
    Preconditions.CheckNotNull(formatInfo, "formatInfo");
    // Use the "fixed" parser for the common case of the default template value.
    let pattern: IPattern<LocalTime> = templateValue!.Equals(LocalTime.Midnight)
      ? formatInfo.LocalTimePatternParser.ParsePattern(patternText)
      : new LocalTimePatternParser(templateValue!).ParsePattern(patternText, formatInfo);
    // If ParsePattern returns a standard pattern instance, we need to get the underlying partial pattern.
    // (Alternatively, we could just return it directly, instead of creating a new object.)
    pattern = pattern instanceof LocalTimePattern ? pattern.UnderlyingPattern : pattern;
    const partialPattern = pattern as IPartialPattern<LocalTime>;
    return new LocalTimePattern(patternText, formatInfo, templateValue!, partialPattern);
  }

  // Not ported: CreateWithCurrentCulture (there is no current culture in JavaScript)

  /**
   * Creates a pattern for the given pattern text in the invariant culture.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @returns A pattern for parsing and formatting local times.
   * @throws {InvalidPatternError} The pattern text was invalid.
   */
  static CreateWithInvariantCulture(patternText: string): LocalTimePattern {
    return LocalTimePattern.Create(patternText, NodaFormatInfo.InvariantInfo, LocalTime.Midnight);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * localization information.
   * @param formatInfo The localization information to use in the new pattern.
   * @returns A new pattern with the given localization information.
   */
  private WithFormatInfo(formatInfo: NodaFormatInfo): LocalTimePattern {
    return LocalTimePattern.Create(this.PatternText, formatInfo, this.TemplateValue);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * culture.
   * @param cultureInfo The culture to use in the new pattern.
   * @returns A new pattern with the given culture.
   */
  WithCulture(cultureInfo: NodaCultureInfo): LocalTimePattern {
    return this.WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));
  }

  /**
   * Creates a pattern like this one, but with the specified template value.
   * @param newTemplateValue The template value for the new pattern, used to fill in unspecified fields.
   * @returns A new pattern with the given template value.
   */
  WithTemplateValue(newTemplateValue: LocalTime): LocalTimePattern {
    return LocalTimePattern.Create(this.PatternText, this._formatInfo, newTemplateValue);
  }
}
