// Boots an iPhone in the iOS Simulator (macOS with Xcode): the named device, else the highest-numbered "iPhone <n>" of
// the newest iOS runtime. For the ios-safari test project, opens a warm-up WebDriver session (warming up Safari's Intl
// data) through a safaridriver left running for the tests (unless --no-safari). Sets NODA_TEST_IOS_UDID,
// NODA_TEST_LABEL and NODA_TEST_SAFARIDRIVER_PORT for later GitHub Actions steps. safaridriver must be enabled once:
// sudo safaridriver --enable.
// Usage: npm run test:start-ios-simulator [-- "iPhone 16"]
//        node scripts/devices/start-ios-simulator.ts --no-safari --time-zone Australia/Sydney
import { spawn } from "node:child_process";
import { openSync, readFileSync } from "node:fs";
import path from "node:path";
import os from "node:os";
import { capture, core, fail, glob, pRetry, program, run, runScript, semver, setEnv, sleep, tempPath } from "noda-scripts/ci";

/** A simulator device, as simctl lists it. */
interface Device {
  /** The device type's name ("iPhone 16"). */
  name: string;
  /** The device's id. */
  udid: string;
  /** "Booted", "Shutdown", ... */
  state: string;
}

program
  .description("Boots an iPhone simulator (and opens a warm-up WebDriver session on it).")
  .argument("[device]", "the device name (default: the highest-numbered iPhone)", "")
  .option("--no-safari", "skip the warm-up WebDriver session (when not testing Safari)")
  .option("--time-zone <zone>", "set the Mac's zone first (the Simulator takes it when it boots; sudo)")
  .parse();
const [wanted] = program.processedArgs as [string];
const { safari, timeZone } = program.opts<{ safari: boolean; timeZone?: string }>();
const port = 47321;
const base = `http://127.0.0.1:${port}`;

/** A runtime key's iOS version (com.apple.CoreSimulator.SimRuntime.iOS-18-5 → "18.5"), or undefined if not iOS. */
function runtimeVersion(key: string): string | undefined {
  return key.match(/\.iOS-([0-9-]+)$/)?.[1]!.replaceAll("-", ".");
}

/** Sends a WebDriver request; returns the response's value, or undefined on failure. */
async function webDriver(method: string, url: string, body: unknown, seconds: number): Promise<any> {
  try {
    const response = await fetch(`${base}${url}`, {
      method,
      headers: { "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(seconds * 1000),
    });
    const { value } = await response.json() as { value: any };
    if (response.ok)
      return value;
    console.log(`${method} ${url}: HTTP ${response.status} ${value?.error ?? ""}: ${value?.message ?? ""}`);
    return undefined;
  } catch (error) {
    console.log(`${method} ${url}: ${String(error)}`);
    return undefined;
  }
}

/** Runs Intl over every time zone and the golden tests' cultures in the session: Safari's first use of each is slow. */
async function warmUpIntl(session: string): Promise<void> {
  const locales = [...new Set(glob("ts/test/golden", "{formatting,compare}/*.generated.ts")
    .map((f) => path.posix.basename(f, ".generated.ts")))].sort();
  const script = `var locales = arguments[0], start = Date.now();
var zones = typeof Intl.supportedValuesOf === "function" ? Intl.supportedValuesOf("timeZone") : [];
zones.forEach(function (zone) {
  new Intl.DateTimeFormat("en-US", { timeZone: zone, timeZoneName: "longGeneric" }).formatToParts(0);
});
locales.forEach(function (locale) {
  try {
    new Intl.Collator(locale, { sensitivity: "accent" }).compare("a", "A");
    new Intl.DateTimeFormat(locale, { dateStyle: "full", timeStyle: "full" }).format(0);
  } catch (e) {
    // Not a locale tag ("invariant").
  }
});
return zones.length + " zones, " + locales.length + " locales in " + (Date.now() - start) + " ms";`;
  await webDriver("POST", `/session/${session}/timeouts`, { script: 600000 }, 30);
  const result = await webDriver("POST", `/session/${session}/execute/sync`, { script, args: [locales] }, 660);
  if (result === undefined) {
    core.warning("Couldn't warm up Intl in Safari on the simulator.");
  } else {
    console.log(`Warmed up Intl: ${String(result)}`);
  }
}

/** Opens and closes one WebDriver session on the device, leaving safaridriver running for the tests; throws on failure. */
async function warmUp(udid: string): Promise<void> {
  const logFile = tempPath("safaridriver.log");
  const log = openSync(logFile, "a");
  const driver = spawn("safaridriver", ["--port", String(port)], { stdio: ["ignore", log, log], detached: true });
  for (let i = 0; i < 60 && await webDriver("GET", "/status", undefined, 5) === undefined; i++) {
    await sleep(1000);
  }
  const created = await webDriver("POST", "/session", {
    capabilities: { alwaysMatch: { browserName: "safari", platformName: "iOS", "safari:useSimulator": true, "safari:deviceUDID": udid } },
  }, 600);
  const session = created?.sessionId as string | undefined;
  if (!session) {
    driver.kill();
    console.log(readFileSync(logFile, "utf8").split("\n").slice(-30).join("\n"));
    throw new Error(`Could not open a WebDriver session on ${udid}.`);
  }
  await warmUpIntl(session);
  await webDriver("DELETE", `/session/${session}`, undefined, 120);
  driver.unref();
}

const devices = (JSON.parse(capture("xcrun", ["simctl", "list", "devices", "available", "--json"])) as { devices: Record<string, Device[]> }).devices;
/** A runtime's iPhones. */
function iphones(key: string): Device[] {
  return devices[key]!.filter((d) => d.name.startsWith("iPhone"));
}
const runtime = Object.keys(devices)
  .filter((key) => runtimeVersion(key) && iphones(key).length > 0)
  .sort((a, b) => semver.compare(semver.coerce(runtimeVersion(a))!, semver.coerce(runtimeVersion(b))!))
  .pop() ?? fail("No iOS Simulator runtime with an iPhone is installed (xcrun simctl list devices available).");
const candidates = iphones(runtime);
const numbered = candidates.filter((d) => /^iPhone [0-9]+$/.test(d.name))
  .sort((a, b) => Number(a.name.slice(7)) - Number(b.name.slice(7)));
const iphone = (wanted ? candidates.find((d) => d.name === wanted) : numbered.pop() ?? candidates[0])
  ?? fail(`No available '${wanted}' in ${runtime} (has: ${candidates.map((d) => d.name).join(", ")}).`);

const version = runtimeVersion(runtime)!;
const label = `${iphone.name} (iOS ${version}, ${os.machine()})`;
if (timeZone) {
  runScript("scripts/time-zones/set-system-time-zone.ts", [timeZone]);
}
console.log(`Booting ${iphone.name} (iOS ${version}), ${iphone.udid}`);
if (iphone.state !== "Booted") {
  run("xcrun", ["simctl", "boot", iphone.udid]);
}
run("xcrun", ["simctl", "bootstatus", iphone.udid, "-b"]);
if (safari) {
  await pRetry(async (attempt) => {
    console.log(`Opening a warm-up WebDriver session (attempt ${attempt})`);
    await warmUp(iphone.udid);
  }, { retries: 2, minTimeout: 10_000, factor: 1 });
  setEnv("NODA_TEST_SAFARIDRIVER_PORT", String(port));
}

setEnv("NODA_TEST_IOS_UDID", iphone.udid);
setEnv("NODA_TEST_LABEL", label);
