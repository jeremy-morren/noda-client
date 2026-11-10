// Runs noda_dart's system time zone tests in each of this OS's zones from dart/scripts/test/time-zones.json, one after
// another, then restores the machine's zone. Changes the machine's time zone (Windows: administrator; else sudo): for CI.
// Usage: node dart/scripts/test/test-time-zones.ts [--only "AUS Eastern" India]
import { capture, core, fail, isWindows, platformLabel, program, readJson, run, runScript, tempPath } from "noda-scripts/ci";

/** A configured time zone (time-zones.json). */
interface Variant {
  /** The variant's label. */
  name: string;
  /** Windows: the zone tzutil sets. */
  tz?: string;
  /** Windows: DST adjustment off. */
  dstOff?: boolean;
  /** Windows: a localized standard name. */
  standardName?: string;
  /** Windows: a localized daylight name. */
  daylightName?: string;
  /** Linux, macOS: a shell command configuring /etc/localtime. */
  setup?: string;
  /** TZ for the tests ("" = empty; absent = unset). */
  envTz?: string;
  /** The tzdb provider's expected system default. */
  expected: string;
  /** The system source's expected default, when not tz, envTz or (with setup) expected. */
  system?: string;
  /** Why the system's UTC offset may differ from the zone's. */
  offsetMayDiffer?: string;
  /** A regex of test names that fail here for reasons outside noda_dart. */
  exclude?: string;
}

const { only } = program
  .description("Runs noda_dart's system tests in each configured time zone (changes the machine's zone).")
  .option("--only <names...>", "only these variants")
  .parse().opts<{ only?: string[] }>();
const os = platformLabel().split("-")[0]!;
const variants = (readJson<Record<string, Variant[]>>("dart/scripts/test/time-zones.json")[os] ?? []).filter((v) => !only || only.includes(v.name));
const localtimeBackup = tempPath(`noda-localtime-${process.pid}`);

/** Restores /etc/localtime from the backup (-P: a symlink stays one). */
function restoreLocaltime(): void {
  run("sudo", ["rm", "-f", "/etc/localtime"]);
  run("sudo", ["cp", "-P", localtimeBackup, "/etc/localtime"]);
}

/** Configures the machine for a variant. */
function configure(variant: Variant): void {
  if (isWindows) {
    // tzutil's own syntax for a zone with DST adjustment off.
    run("tzutil", ["/s", variant.dstOff ? `${variant.tz}_dstoff` : variant.tz!]);
    if (variant.standardName) {
      runScript("scripts/time-zones/set-windows-time-zone-names.ts", ["--standard", variant.standardName, "--daylight", variant.daylightName!]);
    }
    console.log(`Windows time zone: ${capture("tzutil", ["/g"])}`);
  } else {
    restoreLocaltime();
    if (variant.setup) {
      run("bash", ["-c", variant.setup]);
    }
    console.log(`/etc/localtime: ${capture("ls", ["-l", "/etc/localtime"])}`);
  }
}

/** Runs the local zone check and the system tests for a variant; returns whether both passed. */
function test(variant: Variant): boolean {
  const system = variant.system || variant.envTz || variant.tz || (variant.setup ? variant.expected : undefined);
  const env = {
    TZ: variant.envTz,
    NODA_EXPECT_SYSTEM_TIME_ZONE: system,
    NODA_EXPECT_LOCALIZED_WINDOWS: variant.standardName ? "1" : "",
    OFFSET_MAY_DIFFER: variant.offsetMayDiffer,
  };
  const checked = run("dart", ["run", "tool/check_local_zone.dart", variant.expected], { cwd: "dart/noda_dart", env, check: false }) === 0;
  if (!checked) {
    core.error(`${variant.name}: the detected local zone isn't ${variant.expected}`);
  }
  const testArgs = ["--platform", "vm", "--tags", "system", "--variant", variant.name];
  if (variant.exclude) testArgs.push("--exclude", variant.exclude);
  const tested = runScript("dart/scripts/test/test.ts", testArgs, { env, check: false }) === 0;
  return checked && tested;
}

if (variants.length === 0) {
  console.log(`No time zone variants for ${os}.`);
  process.exit(0);
}
const originalWindowsZone = isWindows ? capture("tzutil", ["/g"]) : undefined;
if (!isWindows) {
  run("sudo", ["cp", "-P", "/etc/localtime", localtimeBackup]);
}
const failed: string[] = [];
try {
  for (const variant of variants) {
    core.startGroup(variant.name);
    try {
      configure(variant);
      if (!test(variant)) failed.push(variant.name);
    } catch (error) {
      core.error(`${variant.name}: ${String(error)}`);
      failed.push(variant.name);
    } finally {
      core.endGroup();
    }
  }
} finally {
  if (isWindows) {
    run("tzutil", ["/s", originalWindowsZone!]);
  } else {
    restoreLocaltime();
    run("sudo", ["rm", "-f", localtimeBackup]);
  }
}

console.log(`Time zone variants on ${os}: ${variants.length}, failed: ${failed.length}.`);
if (failed.length > 0) fail(`noda_dart's system tests failed in: ${failed.join(", ")}.`);
