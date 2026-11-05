// noda-js: new code, modelled on NodaTime 3.3.7: src/NodaTime/TimeZones/BclDateTimeZoneSource.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { BrowserDateTimeZone } from "../internal.ts";
import type { IDateTimeZoneSource } from "../internal.ts";
import { NewInvalidOperationException, type ArgumentException, type InvalidOperationException } from "../internal.ts";

// Node's process object, where present (declared here as the build has no Node types).
declare const process: { versions?: { tz?: unknown } } | undefined;

/**
 * Time zone source based on the host's `Intl` implementation (the counterpart of NodaTime's
 * `BclDateTimeZoneSource`). Zones are {@link BrowserDateTimeZone} instances.
 *
 * This type is immutable reference type. See the thread safety section of the user guide for more information.
 */
export class BrowserDateTimeZoneSource implements IDateTimeZoneSource {
  /**
   * Constructs a source for the host's time zones.
   * @throws {InvalidOperationException} Intl (with time zone support) is not available.
   */
  constructor() {
    if (typeof Intl === "undefined" || typeof Intl.DateTimeFormat !== "function") {
      throw NewInvalidOperationException(
        "noda-js/browser needs the host's Intl.DateTimeFormat (with time zone support), which is not available. " +
          "Use the bundled tzdb (noda-js/tzdb/bundled) instead.",
      );
    }
  }

  /**
   * @inheritdoc
   *
   * This is `Intl.supportedValuesOf("timeZone")`, plus the host's default time zone ID if that isn't
   * listed but can be used (hosts typically list "UTC" as neither).
   */
  GetIds(): readonly string[] {
    // Always include the local time zone, since the host may not include it in the list of supported time zones,
    // even though it accepts it.
    const ids = new Set<string>(GetSupportedTimeZones());
    for (const id of GetLocalIdOrEmpty()) {
      ids.add(id);
    }
    return [...ids];
  }

  /**
   * @inheritdoc
   *
   * This is "Intl: " followed by the host's time zone data version, where the host exposes it (e.g. Node's
   * `process.versions.tz`), or "unknown".
   */
  get VersionId(): string {
    // (Not globalThis, which is ES2020.)
    const versions = typeof process !== "undefined" ? process?.versions : undefined;
    const tz = typeof versions?.tz === "string" ? versions.tz : "unknown";
    return `Intl: ${tz}`;
  }

  /**
   * Creates a new instance of {@link BrowserDateTimeZone} from the host time zone
   * with the given ID.
   * @param id The ID of the host time zone to convert
   * @throws {ArgumentException} The given zone doesn't exist in the host.
   * @returns A {@link BrowserDateTimeZone} wrapping the host time zone with the given ID.
   */
  ForId(id: string): BrowserDateTimeZone {
    return BrowserDateTimeZone.FromId(id);
  }

  // Note: if the host has no default time zone, we'll return null here as well.
  // However, we *don't* attempt to validate that a non-null ID can be looked up.
  // We'll let the DateTimeZoneCache do that for us. (We get a DateTimeZoneNotFoundException either way.)

  /** @inheritdoc */
  GetSystemDefaultId(): string | null {
    return GetLocalId();
  }
}

function GetSupportedTimeZones(): readonly string[] {
  // eslint-disable-next-line es-x/no-intl-supportedvaluesof -- feature-detected; without it the list is just the local zone
  return typeof Intl !== "undefined" && typeof Intl.supportedValuesOf === "function" ? Intl.supportedValuesOf("timeZone") : [];
}

function GetLocalId(): string | null {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone ?? null;
  } catch {
    return null;
  }
}

function GetLocalIdOrEmpty(): readonly string[] {
  const local = GetLocalId();
  if (local !== null) {
    try {
      // Make sure the host accepts it: this throws a RangeError otherwise.
      new Intl.DateTimeFormat("en-US", { timeZone: local });
      return [local];
    } catch {
      // Fall through
    }
  }
  return [];
}
