// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/BclDateTimeZoneSource.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: NodaTime's BclDateTimeZoneSource: Windows' zones through the TimeZoneInfo port, or the host's Intl zones.

import { IsNodaError, NewArgumentException, SystemDateTimeZone, TimeZoneInfoInterceptor } from "../internal.ts";
import type { ArgumentException, IDateTimeZoneSource, InvalidOperationException, ITimeZoneInfoShim } from "../internal.ts";
import { IntlSystemTimeZones } from "../System/IntlSystemTimeZones.ts";
import type { SystemTimeZoneBackend } from "../System/Windows/WindowsTimeZoneApi.ts";

/**
 * Provides an implementation of {@link IDateTimeZoneSource} that loads data from the host system's time zones
 * (NodaTime's BclDateTimeZoneSource, which loads them from the BCL `TimeZoneInfo` class).
 *
 * All calls to {@link SystemDateTimeZoneSource.ForId} return instances of {@link SystemDateTimeZone}, including for
 * fixed-offset IDs (i.e. "UTC" and "UTC+/-Offset").
 *
 * noda-js: on Windows with FFI (Node 26+, Bun, Deno) or the native addon, Windows' zones and IDs, read as .NET reads
 * them ({@link SystemDateTimeZoneSource.ForId} also accepts IANA IDs). Otherwise the host's Intl zones, with CLDR's
 * Windows IDs on Windows and IANA IDs elsewhere.
 *
 * See docs/Timezones.md.
 *
 * This type maintains no state, and all members are thread-safe. See the thread safety section of the user guide for more information.
 */
export class SystemDateTimeZoneSource implements IDateTimeZoneSource {
  /** noda-js: TimeZoneInfo on this host, or null if it has none (then _intl is set). */
  private readonly _shim: ITimeZoneInfoShim | null;
  private readonly _intl: IntlSystemTimeZones | null;

  /**
   * Constructs a new instance. This is rarely useful in application code, as this class has no state of its own.
   * Most application code should use `SystemDateTimeZoneProvider` (from noda-js/system).
   *
   * noda-js: picks where the zones come from (see above).
   * @throws {InvalidOperationException} The host can't read Windows' time zones and has no Intl.DateTimeFormat.
   */
  constructor() {
    this._shim = TimeZoneInfoInterceptor.Shim;
    this._intl = this._shim === null ? IntlSystemTimeZones.ForHost() : null;
  }

  /**
   * noda-js: a source over the given Intl zones (for tests).
   * @internal
   */
  static NewIntl(intl: IntlSystemTimeZones): SystemDateTimeZoneSource {
    const source = Object.create(SystemDateTimeZoneSource.prototype) as { _shim: ITimeZoneInfoShim | null; _intl: IntlSystemTimeZones | null };
    source._shim = null;
    source._intl = intl;
    return source as unknown as SystemDateTimeZoneSource;
  }

  /**
   * noda-js: "addon" or "ffi" (Windows' zones, read as .NET does), or "intl" (the host's Intl).
   * @internal
   */
  get Backend(): SystemTimeZoneBackend {
    return this._shim === null ? "intl" : this._shim.Backend;
  }

  /**
   * Returns the IDs of all system time zones.
   * @returns The IDs available from this source.
   */
  GetIds(): readonly string[] {
    if (this._intl !== null) {
      return this._intl.GetIds();
    }
    // Always include the local time zone, since Mono may not include it in the list of system time zones, even
    // though it allows the Id to be passed to FindSystemTimeZoneById().
    // See https://github.com/nodatime/nodatime/issues/235.
    const ids = new Set<string>(this._shim!.GetSystemTimeZones().map(zone => zone.Id));
    for (const id of this.GetTimeZoneInfoLocalIdOrEmpty()) {
      ids.add(id);
    }
    return [...ids];
  }

  /**
   * Returns an enumerable containing a singleton element of the Id of the local time zone
   * (`TimeZoneInfo.Local.Id`), unless the local time zone is not available, or not a system time zone, in
   * which case returns an empty enumerable.
   */
  private GetTimeZoneInfoLocalIdOrEmpty(): readonly string[] {
    // This complexity is entirely to handle Mono, which fails quite badly at this in some cases.
    try {
      // May throw TimeZoneNotFoundException, particularly on Mono/Windows.
      // See https://bugzilla.xamarin.com/show_bug.cgi?id=11817
      const local = this._shim!.Local;

      if (local !== null) { // https://github.com/nodatime/nodatime/issues/235#issuecomment-80932079
        // Make sure we can look it up again, as there are legitimate cases where the local time zone is not
        // a system time zone.  If not, this also throws TimeZoneNotFoundException.
        this._shim!.FindSystemTimeZoneById(local.Id);

        return [local.Id];
      }
    } catch (e) {
      if (!IsNodaError(e, "TimeZoneNotFoundException")) {
        throw e;
      }
    }
    return [];
  }

  /**
   * This source returns a string such as "TimeZoneInfo: 3.5.0.0" corresponding to the version of the assembly
   * containing TimeZoneInfo.
   *
   * noda-js: e.g. "TimeZoneInfo: Windows (node:ffi)", or "Intl: 2025b" ("Intl: unknown"), followed on Windows by the
   * CLDR mapping's version.
   */
  get VersionId(): string {
    return this._intl !== null ? this._intl.VersionId : `TimeZoneInfo: Windows (${this._shim!.Description})`;
  }

  /**
   * Creates a new instance of {@link SystemDateTimeZone} from the TimeZoneInfo with the given
   * ID. The ID must be a known system time zone ID.
   * @param id The ID of the system time zone to convert
   * @throws {ArgumentException} The given zone doesn't exist.
   * @returns The Noda Time representation of the given BCL time zone
   */
  ForId(id: string): SystemDateTimeZone {
    if (this._intl !== null) {
      const zone = this._intl.ForId(id);
      if (zone === null) {
        throw NewArgumentException(id + " is not a system time zone ID", "id");
      }
      return zone;
    }
    try {
      const zone = this._shim!.FindSystemTimeZoneById(id);
      return SystemDateTimeZone.FromTimeZoneInfo(zone);
    } catch (e) {
      if (IsNodaError(e, "TimeZoneNotFoundException")) {
        throw NewArgumentException(id + " is not a system time zone ID", "id", { cause: e });
      }
      throw e;
    }
  }

  // Note: if TimeZoneInfo.Local returns a null reference, we'll return a null reference here as well.
  // However, we *don't* attempt to validate that a non-null reference has a valid ID that can be looked up.
  // We'll let the DateTimeZoneCache do that for us. (We get a DateTimeZoneNotFoundException either way.)

  /**
   * @inheritdoc
   *
   * noda-js: the ID of the zone TZ names, if set (UTC's if it names none); otherwise TimeZoneInfo.Local's, or the host's
   * Intl default. Null if there's no zone. {@link SystemDateTimeZone.ForSystemDefault} agrees.
   */
  GetSystemDefaultId(): string | null {
    return this._intl !== null ? this._intl.GetSystemDefaultId() : GetTimeZoneInfoSystemDefaultId(this._shim!);
  }
}

/**
 * noda-js: TimeZoneInfo.Local's ID (which honours TZ); shared so GetSystemDefaultId and ForSystemDefault agree.
 * @internal
 */
export function GetTimeZoneInfoSystemDefaultId(shim: ITimeZoneInfoShim): string | null {
  return shim.Local?.Id ?? null;
}

// For doc comments.
export type { ArgumentException as _SystemArgumentException, InvalidOperationException as _SystemInvalidOperationException };
