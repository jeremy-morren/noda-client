// noda-js: new code. The host's zone, standing in for TimeZoneInfo.Local in TzdbDateTimeZoneSource.MapTimeZoneInfoId.

import { Offset } from "../internal.ts";
import type { Instant } from "../internal.ts";
import { GetTZEnvironmentVariable } from "../Utility/TimeZoneEnvironment.ts";

/** The parts of a TimeZoneInfo that MapTimeZoneInfoId uses. @internal */
export interface IHostTimeZone {
  /** The zone's ID: a Windows ID, a tzdb ID, or "Local" when the host can't name it. */
  readonly Id: string;
  /** Whether the ID is TZ's (an unmapped TZ means UTC rather than a guess). */
  readonly FromEnvironment: boolean;
  /** TimeZoneInfo.GetUtcOffset for an instant. */
  GetUtcOffset(instant: Instant): Offset;
}

/** The ID Mono's TimeZoneInfo.Local has when it can't name the zone; also noda-js's, without Intl. */
const LocalId = "Local";

/** The host's zone: named by TZ, else Intl (else "Local"), with Date's offsets. @internal */
export function GetHostTimeZone(): IHostTimeZone {
  const tz = GetTZEnvironmentVariable();
  const id = tz ?? GetIntlLocalId() ?? LocalId;
  return {
    Id: id,
    FromEnvironment: tz !== null,
    GetUtcOffset: DateUtcOffset,
  };
}

/** The host's local UTC offset at an instant, from Date (to the second). */
function DateUtcOffset(instant: Instant): Offset {
  const minutes = new Date(instant.ToUnixTimeMilliseconds()).getTimezoneOffset();
  return Offset.FromSeconds(-Math.round(minutes * 60));
}

function GetIntlLocalId(): string | null {
  try {
    return typeof Intl !== "undefined" ? (Intl.DateTimeFormat().resolvedOptions().timeZone ?? null) : null;
  } catch {
    return null;
  }
}
