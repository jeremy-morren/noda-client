// noda-js/windows: WindowsIdDateTimeZoneProvider, a provider that also accepts Windows (BCL) zone IDs, mapping each to
// its CLDR primary tzdb zone. (A noda-js addition: NodaTime's BclDateTimeZoneSource has no JS equivalent.)

import { beforeAll, describe, expect, it } from "vitest";
import { DateTimeZoneNotFoundError, type IDateTimeZoneProvider, ZonedDateTime } from "noda-js";
import { WindowsIdDateTimeZoneProvider } from "noda-js/windows";
import { loadTzdbProvider } from "./helpers/decode.ts";

describe("WindowsIdDateTimeZoneProvider", () => {
  let tzdb: IDateTimeZoneProvider;
  let provider: WindowsIdDateTimeZoneProvider;
  beforeAll(async () => {
    tzdb = await loadTzdbProvider();
    provider = new WindowsIdDateTimeZoneProvider(tzdb);
  });

  it("maps a Windows ID to its CLDR primary tzdb zone, and keeps tzdb IDs working", () => {
    expect(provider.GetZoneOrNull("AUS Eastern Standard Time")).toBe(tzdb.Get("Australia/Sydney"));
    expect(provider.Get("GMT Standard Time")).toBe(tzdb.Get("Europe/London"));
    expect(provider.Get("Europe/London")).toBe(tzdb.Get("Europe/London"));
    expect(provider.GetZoneOrNull("Not A Zone")).toBeNull();
    expect(() => provider.Get("Not A Zone")).toThrow(DateTimeZoneNotFoundError);
  });

  it("advertises the Windows IDs it accepts as well as the wrapped provider's, in ordinal order", () => {
    const ids = provider.Ids;
    expect(ids).toContain("AUS Eastern Standard Time");
    expect(ids).toContain("Australia/Sydney");
    for (const id of tzdb.Ids) {
      expect(ids).toContain(id);
    }
    expect([...ids].sort()).toEqual([...ids]);
    expect(new Set(ids).size).toBe(ids.length);
    expect(provider.Ids).toBe(ids);
  });

  it("lets patterns parse a Windows zone ID (as written by .NET apps using BclDateTimeZone)", () => {
    const value = ZonedDateTime.fromJSON("2024-04-01T01:30:00+11 AUS Eastern Standard Time", provider);
    expect(value.Zone).toBe(tzdb.Get("Australia/Sydney"));
    expect(value.toJSON()).toBe("2024-04-01T01:30:00+11 Australia/Sydney");
  });

  it("finds the Windows ID for a tzdb ID", () => {
    expect(provider.WindowsIdForTzdbId("Australia/Sydney")).toBe("AUS Eastern Standard Time");
    expect(provider.WindowsIdForTzdbId("Not/A_Zone")).toBeNull();
  });
});
