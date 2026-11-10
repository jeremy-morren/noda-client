// Ported from NodaTime 3.3.7: src/NodaTime/Calendars/Era.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

let common: Era | undefined;
let beforeCommon: Era | undefined;
let annoMartyrum: Era | undefined;
let annoHegirae: Era | undefined;
let annoMundi: Era | undefined;
let annoPersico: Era | undefined;
let bahai: Era | undefined;

/**
 * Represents an era used in a calendar.
 *
 * All the built-in calendars in Noda Time use the values specified by the static
 * read-only fields in this class. These may be compared for reference equality to check for specific
 * eras.
 *
 * This type is immutable reference type. See the thread safety section of the user guide for more information.
 */
export class Era {
  /**
   * The "Common" era (CE), also known as Anno Domini (AD). This is used in the ISO, Gregorian and Julian calendars.
   */
  static get Common(): Era {
    return (common ??= Era.NewNameResourceIdentifier("CE", "Eras_Common"));
  }

  /**
   * The "before common" era (BCE), also known as Before Christ (BC). This is used in the ISO, Gregorian and Julian calendars.
   */
  static get BeforeCommon(): Era {
    return (beforeCommon ??= Era.NewNameResourceIdentifier("BCE", "Eras_BeforeCommon"));
  }

  /**
   * The "Anno Martyrum" or "Era of the Martyrs". This is the sole era used in the Coptic calendar.
   */
  static get AnnoMartyrum(): Era {
    return (annoMartyrum ??= Era.NewNameResourceIdentifier("AM", "Eras_AnnoMartyrum"));
  }

  /**
   * The "Anno Hegira" era. This is the sole era used in the Hijri (Islamic) calendar.
   */
  static get AnnoHegirae(): Era {
    return (annoHegirae ??= Era.NewNameResourceIdentifier("EH", "Eras_AnnoHegirae"));
  }

  /**
   * The "Anno Mundi" era. This is the sole era used in the Hebrew calendar.
   */
  static get AnnoMundi(): Era {
    return (annoMundi ??= Era.NewNameResourceIdentifier("AM", "Eras_AnnoMundi"));
  }

  /**
   * The "Anno Persico" era. This is the sole era used in the Persian calendar.
   */
  static get AnnoPersico(): Era {
    return (annoPersico ??= Era.NewNameResourceIdentifier("AP", "Eras_AnnoPersico"));
  }

  /**
   * The "Bahá'í" era. This is the sole era used in the Badi calendar.
   */
  static get Bahai(): Era {
    return (bahai ??= Era.NewNameResourceIdentifier("BE", "Eras_Bahai"));
  }

  /** @internal */
  readonly ResourceIdentifier: string;

  private readonly _name: string;

  /**
   * Returns the name of this era, e.g. "CE" or "BCE".
   */
  get Name(): string {
    return this._name;
  }

  private constructor(name: string, resourceIdentifier: string) {
    this._name = name;
    this.ResourceIdentifier = resourceIdentifier;
  }

  /**
   * C#: `internal Era(string name, string resourceIdentifier)`
   * @internal
   */
  static NewNameResourceIdentifier(name: string, resourceIdentifier: string): Era {
    return new Era(name, resourceIdentifier);
  }

  /**
   * Returns the name of this era.
   * @returns The name of this era.
   */
  toString(): string {
    return this.Name;
  }
}
