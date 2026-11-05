// Ported from NodaTime 3.3.0: src/NodaTime/Text/AnnualDatePattern.cs
// Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { AnnualDate, AnnualDatePatternParser, NodaFormatInfo, PatternBclSupport, Preconditions } from "../internal.ts";
import type { NodaCultureInfo, IPartialPattern, IPattern, ParseResult, StringBuilder } from "../internal.ts";

let defaultTemplateValue: AnnualDate | undefined;
let bclSupport: PatternBclSupport<AnnualDate> | undefined;
let isoPatternImpl: AnnualDatePattern | undefined;

const DefaultFormatPattern = "G"; // General, ISO-like

/**
 * Class whose existence is solely to avoid type initialization order issues, most of which stem
 * from needing NodaFormatInfo.InvariantInfo...
 */
class AnnualDatePatternPatterns {
  static get IsoPatternImpl(): AnnualDatePattern {
    return (isoPatternImpl ??= AnnualDatePattern.CreateWithInvariantCulture("MM'-'dd"));
  }
}

/**
 * Represents a pattern for parsing and formatting {@link AnnualDate} values.
 *
 * Thread safety: When used with a read-only {@link NodaCultureInfo}, this type is immutable and instances
 * may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
 * not currently enforced.
 */
export class AnnualDatePattern implements IPattern<AnnualDate> {
  /** @internal */
  static get DefaultTemplateValue(): AnnualDate {
    return (defaultTemplateValue ??= new AnnualDate(1, 1));
  }

  /** @internal */
  static get BclSupport(): PatternBclSupport<AnnualDate> {
    return (bclSupport ??= new PatternBclSupport<AnnualDate>(DefaultFormatPattern, fi => fi.AnnualDatePatternParser));
  }

  /**
   * Gets an invariant annual date pattern which is compatible with the month/day part of ISO-8601.
   * This corresponds to the text pattern "MM'-'dd".
   */
  static get Iso(): AnnualDatePattern {
    return AnnualDatePatternPatterns.IsoPatternImpl;
  }

  /**
   * Returns the pattern that this object delegates to. Mostly useful to avoid this public class
   * implementing an internal interface.
   * @internal
   */
  readonly UnderlyingPattern: IPartialPattern<AnnualDate>;

  private readonly _patternText: string;

  /** Gets the pattern text for this pattern, as supplied on creation. */
  get PatternText(): string {
    return this._patternText;
  }

  /** Returns the localization information used in this pattern. */
  private readonly _formatInfo: NodaFormatInfo;

  private readonly _templateValue: AnnualDate;

  /**
   * Gets the value used as a template for parsing: any field values unspecified
   * in the pattern are taken from the template.
   */
  get TemplateValue(): AnnualDate {
    return this._templateValue;
  }

  private constructor(patternText: string, formatInfo: NodaFormatInfo, templateValue: AnnualDate, pattern: IPartialPattern<AnnualDate>) {
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
  Parse(text: string): ParseResult<AnnualDate> {
    return this.UnderlyingPattern.Parse(text);
  }

  /**
   * Formats the given annual date as text according to the rules of this pattern.
   * @param value The annual date to format.
   * @returns The annual date formatted according to this pattern.
   */
  Format(value: AnnualDate): string {
    return this.UnderlyingPattern.Format(value);
  }

  /**
   * Formats the given value as text according to the rules of this pattern,
   * appending to the given {@link StringBuilder}.
   * @param value The value to format.
   * @param builder The `StringBuilder` to append to.
   * @returns The builder passed in as `builder`.
   */
  AppendFormat(value: AnnualDate, builder: StringBuilder): StringBuilder {
    return this.UnderlyingPattern.AppendFormat(value, builder);
  }

  /**
   * Creates a pattern for the given pattern text, culture, and template value.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @param templateValue Template value to use for unspecified fields
   * @returns A pattern for parsing and formatting annual dates.
   * @throws {InvalidPatternError} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo, templateValue: AnnualDate): AnnualDatePattern;
  /**
   * Creates a pattern for the given pattern text and culture, with a template value of 2000-01-01.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @param cultureInfo The culture to use in the pattern
   * @returns A pattern for parsing and formatting annual dates.
   * @throws {InvalidPatternError} The pattern text was invalid.
   */
  static Create(patternText: string, cultureInfo: NodaCultureInfo): AnnualDatePattern;
  /**
   * Creates a pattern for the given pattern text, format info, and template value.
   * @param patternText Pattern text to create the pattern for
   * @param formatInfo The format info to use in the pattern
   * @param templateValue Template value to use for unspecified fields
   * @returns A pattern for parsing and formatting annual dates.
   * @throws {InvalidPatternError} The pattern text was invalid.
   * @internal
   */
  static Create(patternText: string, formatInfo: NodaFormatInfo, templateValue: AnnualDate): AnnualDatePattern;
  static Create(patternText: string, cultureOrFormatInfo: NodaCultureInfo | NodaFormatInfo, templateValue?: AnnualDate): AnnualDatePattern {
    if (cultureOrFormatInfo instanceof NodaFormatInfo) {
      const formatInfo = cultureOrFormatInfo;
      Preconditions.CheckNotNull(patternText, "patternText");
      Preconditions.CheckNotNull(formatInfo, "formatInfo");
      // Use the "fixed" parser for the common case of the default template value.
      let pattern: IPattern<AnnualDate> = templateValue!.Equals(AnnualDatePattern.DefaultTemplateValue)
        ? formatInfo.AnnualDatePatternParser.ParsePattern(patternText)
        : new AnnualDatePatternParser(templateValue!).ParsePattern(patternText, formatInfo);
      // If ParsePattern returns a standard pattern instance, we need to get the underlying partial pattern.
      pattern = pattern instanceof AnnualDatePattern ? pattern.UnderlyingPattern : pattern;
      const partialPattern = pattern as IPartialPattern<AnnualDate>;
      return new AnnualDatePattern(patternText, formatInfo, templateValue!, partialPattern);
    }
    return AnnualDatePattern.Create(patternText, NodaFormatInfo.GetFormatInfo(cultureOrFormatInfo), templateValue ?? AnnualDatePattern.DefaultTemplateValue);
  }

  // Not ported: CreateWithCurrentCulture (there is no current culture in JavaScript; use create with an explicit culture)

  /**
   * Creates a pattern for the given pattern text in the invariant culture.
   *
   * See the user guide for the available pattern text options.
   * @param patternText Pattern text to create the pattern for
   * @returns A pattern for parsing and formatting annual dates.
   * @throws {InvalidPatternError} The pattern text was invalid.
   */
  static CreateWithInvariantCulture(patternText: string): AnnualDatePattern {
    return AnnualDatePattern.Create(patternText, NodaFormatInfo.InvariantInfo, AnnualDatePattern.DefaultTemplateValue);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * localization information.
   * @param formatInfo The localization information to use in the new pattern.
   * @returns A new pattern with the given localization information.
   */
  private WithFormatInfo(formatInfo: NodaFormatInfo): AnnualDatePattern {
    return AnnualDatePattern.Create(this.PatternText, formatInfo, this.TemplateValue);
  }

  /**
   * Creates a pattern for the same original pattern text as this pattern, but with the specified
   * culture.
   * @param cultureInfo The culture to use in the new pattern.
   * @returns A new pattern with the given culture.
   */
  WithCulture(cultureInfo: NodaCultureInfo): AnnualDatePattern {
    return this.WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));
  }

  /**
   * Creates a pattern like this one, but with the specified template value.
   * @param newTemplateValue The template value for the new pattern, used to fill in unspecified fields.
   * @returns A new pattern with the given template value.
   */
  WithTemplateValue(newTemplateValue: AnnualDate): AnnualDatePattern {
    return AnnualDatePattern.Create(this.PatternText, this._formatInfo, newTemplateValue);
  }
}
