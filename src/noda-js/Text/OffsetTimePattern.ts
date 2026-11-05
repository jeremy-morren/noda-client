// Ported from NodaTime 3.3.7: src/NodaTime/Text/OffsetTimePattern.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { LocalTime, NodaFormatInfo, Offset, OffsetTimePatternParser, PatternBclSupport, Preconditions } from "../internal.ts";
import type { NodaCultureInfo, IPattern, OffsetTime, ParseResult, StringBuilder } from "../internal.ts";

let defaultTemplateValue: OffsetTime | undefined;
let generalIsoPatternImpl: OffsetTimePattern | undefined;
let extendedIsoPatternImpl: OffsetTimePattern | undefined;
let rfc3339PatternImpl: OffsetTimePattern | undefined;
let bclSupport: PatternBclSupport<OffsetTime> | undefined;

/**
 * Class whose existence is solely to avoid type initialization order issues, most of which stem
 * from needing NodaFormatInfo.InvariantInfo...
 * @internal
 */
export class OffsetTimePatternPatterns {
  static get GeneralIsoPatternImpl(): OffsetTimePattern {
    return (generalIsoPatternImpl ??= OffsetTimePattern.Create("HH':'mm':'sso<G>", NodaFormatInfo.InvariantInfo, OffsetTimePattern.DefaultTemplateValue));
  }
  static get ExtendedIsoPatternImpl(): OffsetTimePattern {
    return (extendedIsoPatternImpl ??= OffsetTimePattern.Create("HH':'mm':'ss;FFFFFFFFFo<G>", NodaFormatInfo.InvariantInfo, OffsetTimePattern.DefaultTemplateValue));
  }
  static get Rfc3339PatternImpl(): OffsetTimePattern {
    return (rfc3339PatternImpl ??= OffsetTimePattern.Create("HH':'mm':'ss;FFFFFFFFFo<Z+HH:mm>", NodaFormatInfo.InvariantInfo, OffsetTimePattern.DefaultTemplateValue));
  }
  static get BclSupport(): PatternBclSupport<OffsetTime> {
    return (bclSupport ??= new PatternBclSupport<OffsetTime>("G", fi => fi.OffsetTimePatternParser));
  }
}

/**
 * Represents a pattern for parsing and formatting {@link OffsetTime} values.
 *
 * Thread safety: When used with a read-only {@link NodaCultureInfo}, this type is immutable and instances
 * may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
 * not currently enforced.
 */
export class OffsetTimePattern implements IPattern<OffsetTime> {
  /** @internal */
  static get DefaultTemplateValue(): OffsetTime {
    return (defaultTemplateValue ??= LocalTime.Midnight.WithOffset(Offset.Zero));
  }

  /**
   * Gets an invariant offset time pattern based on ISO-8601 (down to the second), including offset from UTC.
   *
   * This corresponds to a custom pattern of "HH':'mm':'sso<G>". It is available as the "G"
   * standard pattern (even though it is invariant).
   */
  static get GeneralIso(): OffsetTimePattern {
    return OffsetTimePatternPatterns.GeneralIsoPatternImpl;
  }

  /**
   * Gets an invariant offset time pattern based on ISO-8601 (down to the nanosecond), including offset from UTC.
   *
   * This corresponds to a custom pattern of "HH':'mm':'ss;FFFFFFFFFo<G>".
   * This will round-trip all values, and is available as the "o" standard pattern.
   */
  static get ExtendedIso(): OffsetTimePattern {
    return OffsetTimePatternPatterns.ExtendedIsoPatternImpl;
  }

  /**
   * Gets an invariant offset time pattern based on RFC 3339 (down to the nanosecond), including offset from UTC
   * as hours and minutes only.
   *
   * The minutes part of the offset is always included, but any sub-minute component
   * of the offset is lost. An offset of zero is formatted as 'Z', but all of 'Z', '+00:00' and '-00:00' are parsed
   * the same way. The RFC 3339 meaning of '-00:00' is not supported by Noda Time.
   * Note that parsing is case-sensitive (so 'T' and 'Z' must be upper case).
   * This pattern corresponds to a custom pattern of
   * "HH':'mm':'ss;FFFFFFFFFo<Z+HH:mm>".
   */
  static get Rfc3339(): OffsetTimePattern {
    return OffsetTimePatternPatterns.Rfc3339PatternImpl;
  }

  /** @internal */
  static readonly Patterns = OffsetTimePatternPatterns;

  /** @internal Equivalent of OffsetTimePattern.Patterns.BclSupport. */
  static get BclSupport(): PatternBclSupport<OffsetTime> {
    return OffsetTimePatternPatterns.BclSupport;
  }

  private readonly _pattern: IPattern<OffsetTime>;

  private readonly _patternText: string;

  /** Gets the pattern text for this pattern, as supplied on creation. */
  get PatternText(): string {
    return this._patternText;
  }

  // Visible for testing
  /**
   * Gets the localization information used in this pattern.
   * @internal
   */
  readonly FormatInfo: NodaFormatInfo;

  private readonly _templateValue: OffsetTime;

  /**
   * Gets the value used as a template for parsing: any field values unspecified
   * in the pattern are taken from the template.
   */
  get TemplateValue(): OffsetTime {
    return this._templateValue;
  }

  private constructor(patternText: string, formatInfo: NodaFormatInfo, templateValue: OffsetTime,
    pattern: IPattern<OffsetTime>) {
    this._patternText = patternText;
    this.FormatInfo = formatInfo;
    this._templateValue = templateValue;
    this._pattern = pattern;
  }

  /**
   * Parses the given text value according to the rules of this pattern.
   *
   * This method never throws an exception (barring a bug in Noda Time itself). Even errors such as
   * the argument being null are wrapped in a parse result.
   * @param text The text value to parse.
   * @returns The result of parsing, which may be successful or unsuccessful.
   */
  Parse(text: string): ParseResult<OffsetTime> {
    return this._pattern.Parse(text);
  }

  /**
   * Formats the given offset time as text according to the rules of this pattern.
   * @param value The offset time to format.
   * @returns The offset time formatted according to this pattern.
   */
  Format(value: OffsetTime): string {
    return this._pattern.Format(value);
  }

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: OffsetTime, builder: StringBuilder): StringBuilder {
    return this._pattern.AppendFormat(value, builder);
  }

  /**
   * Creates a pattern for the given pattern text, culture, and template value.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @param templateValue Template value to use for unspecified fields
   * @returns A pattern for parsing and formatting local times.
   * @throws {InvalidPatternException} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo, templateValue: OffsetTime): OffsetTimePattern;
  /**
   * Creates a pattern for the given pattern text, format info, and template value.
   * @param patternText Pattern text to create the pattern for
   * @param formatInfo The format info to use in the pattern
   * @param templateValue Template value to use for unspecified fields
   * @returns A pattern for parsing and formatting offset times.
   * @throws {InvalidPatternException} The pattern text was invalid.
   * @internal
   */
  static Create(patternText: string, formatInfo: NodaFormatInfo, templateValue: OffsetTime): OffsetTimePattern;
  static Create(patternText: string, cultureOrFormatInfo: NodaCultureInfo | NodaFormatInfo, templateValue: OffsetTime): OffsetTimePattern {
    if (cultureOrFormatInfo instanceof NodaFormatInfo) {
      const formatInfo = cultureOrFormatInfo;
      Preconditions.CheckNotNull(patternText, "patternText");
      Preconditions.CheckNotNull(formatInfo, "formatInfo");
      const pattern = new OffsetTimePatternParser(templateValue).ParsePattern(patternText, formatInfo);
      return new OffsetTimePattern(patternText, formatInfo, templateValue, pattern);
    }
    return OffsetTimePattern.Create(patternText, NodaFormatInfo.GetFormatInfo(cultureOrFormatInfo), templateValue);
  }

  /**
   * Creates a pattern for the given pattern text in the invariant culture, using the default
   * template value of midnight January 1st 2000 at an offset of 0.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @returns A pattern for parsing and formatting local times.
   * @throws {InvalidPatternException} The pattern text was invalid.
   */
  static CreateWithInvariantCulture(patternText: string): OffsetTimePattern {
    return OffsetTimePattern.Create(patternText, NodaFormatInfo.InvariantInfo, OffsetTimePattern.DefaultTemplateValue);
  }

  // Not ported: CreateWithCurrentCulture (there is no current culture in JavaScript; use create with an explicit culture)

  /**
   * Creates a pattern for the same original localization information as this pattern, but with the specified
   * pattern text.
   * @param patternText The pattern text to use in the new pattern.
   * @returns A new pattern with the given pattern text.
   */
  WithPatternText(patternText: string): OffsetTimePattern {
    return OffsetTimePattern.Create(patternText, this.FormatInfo, this.TemplateValue);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * localization information.
   * @param formatInfo The localization information to use in the new pattern.
   * @returns A new pattern with the given localization information.
   */
  private WithFormatInfo(formatInfo: NodaFormatInfo): OffsetTimePattern {
    return OffsetTimePattern.Create(this.PatternText, formatInfo, this.TemplateValue);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * culture.
   * @param cultureInfo The culture to use in the new pattern.
   * @returns A new pattern with the given culture.
   */
  WithCulture(cultureInfo: NodaCultureInfo): OffsetTimePattern {
    return this.WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));
  }

  /**
   * Creates a pattern for the same original pattern text and culture as this pattern, but with
   * the specified template value.
   * @param newTemplateValue The template value to use in the new pattern.
   * @returns A new pattern with the given template value.
   */
  WithTemplateValue(newTemplateValue: OffsetTime): OffsetTimePattern {
    return OffsetTimePattern.Create(this.PatternText, this.FormatInfo, newTemplateValue);
  }
}
