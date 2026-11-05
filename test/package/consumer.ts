// A consumer of the *built* packages (resolved through node_modules and each package's "exports", so through dist/),
// type-checked with skipLibCheck off by `npm run check:package`: the published declarations must be complete and valid
// (e.g. nothing they reference may be stripped as @internal).
import * as core from "noda-js";
import * as tzdbReader from "noda-js/tzdb";
import * as tzdbBundled from "noda-js/tzdb/bundled";
import * as browser from "noda-js/browser";
import * as windows from "noda-js/windows";
import * as cultures from "noda-js/cultures";
import * as testing from "noda-js/testing";
import * as linq from "noda-js/linq";
import NodaZ from "noda-js-zod";

export const entryPoints = [core, tzdbReader, tzdbBundled, browser, windows, cultures, testing, linq, NodaZ];

// A few uses, so the declarations are exercised rather than just loaded.
const date: core.LocalDate = new core.LocalDate(2024, 3, 1).PlusDays(30);
const text: string = core.LocalDatePattern.Create("d MMMM uuuu", cultures.enAU).Format(date);
const zoned: core.ZonedDateTime = core.Instant.FromUtc(2024, 3, 31, 12, 0).InZone(tzdbBundled.tzdb.get("Australia/Sydney"));
const order: number = linq.DurationComparer(core.Duration.FromHours(1), core.Duration.Zero);
const parsed: core.Instant = NodaZ.Instant.parse("2024-03-31T12:00:00Z");
const zonedSchema = NodaZ.ZonedDateTime(tzdbBundled.tzdb);
export const used = [text, zoned, order, parsed, zonedSchema];
