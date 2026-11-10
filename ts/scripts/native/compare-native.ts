// Checks the native addon returns what node:ffi does for every registry zone, and rejects bad arguments (run by
// build-native.ts; needs noda-js built). Windows only.
// Usage: node ts/scripts/native/compare-native.ts <repo-relative path to time-zones.node>
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";
import { isDeepStrictEqual } from "node:util";
import { Argument, program, resolvePath } from "noda-scripts/ci";

type Api = Record<string, (...args: unknown[]) => unknown>;

const [addonPath] = program
  .description("Compares the native addon with node:ffi.")
  .addArgument(new Argument("<addon>", "the repo-relative time-zones.node"))
  .parse().processedArgs as [string];
const addon = createRequire(import.meta.url)(resolvePath(addonPath)) as Api;
// Untyped: @internal (not in the declarations), and dist may not be built when this is type-checked.
const ffiModule = pathToFileURL(resolvePath("ts/src/noda-js/dist/System/Windows/FfiWindowsTimeZoneApi.js")).href;
const { FfiWindowsTimeZoneApi } = await import(ffiModule) as { FfiWindowsTimeZoneApi: { TryCreate(): Api | null } };
const ffi = FfiWindowsTimeZoneApi.TryCreate();
if (ffi === null) {
  console.log("node:ffi isn't available: skipping the comparison with it.");
  process.exit(0);
}

let checks = 0;
const failures: string[] = [];

/** Calls the operation on both implementations and records a difference. */
function Compare(operation: string, ...args: unknown[]): unknown {
  const fromAddon = addon[operation]!(...args);
  const fromFfi = ffi![operation]!(...args);
  checks++;
  if (!isDeepStrictEqual(Normalize(fromAddon), Normalize(fromFfi))) {
    failures.push(`${operation}(${args.map(a => JSON.stringify(a)).join(", ")}): addon ${JSON.stringify(Normalize(fromAddon))}, ffi ${JSON.stringify(Normalize(fromFfi))}`);
  }
  return fromAddon;
}

/** Uint8Arrays compare by content, whatever their buffer. */
function Normalize(value: unknown): unknown {
  return value instanceof Uint8Array ? Array.from(value) : value;
}

const timeZones = "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Time Zones";
Compare("GetDynamicTimeZoneInformation");
Compare("GetSystemDirectory");
Compare("GetUserPreferredUILanguages");
Compare("RegistryKeyExists", timeZones);
Compare("RegistryKeyExists", `${timeZones}\\No Such Zone`);
Compare("GetRegistrySubKeyNames", `${timeZones}\\No Such Zone`);
Compare("GetRegistryValue", timeZones, "No such value");
const systemDirectory = addon["GetSystemDirectory"]!() as string;
Compare("FileExists", `${systemDirectory}\\tzres.dll`);
Compare("FileExists", systemDirectory);
Compare("FileExists", `${systemDirectory}\\no-such-file.dll`);

const ids = Compare("GetRegistrySubKeyNames", timeZones) as string[];
for (const id of ids) {
  const key = `${timeZones}\\${id}`;
  for (const name of ["Display", "Std", "Dlt", "MUI_Display", "MUI_Std", "MUI_Dlt", "TZI"]) {
    const value = Compare("GetRegistryValue", key, name);
    // The MUI names are "@tzres.dll,-<id>": load each string through both.
    if (typeof value === "string" && value.startsWith("@")) {
      const match = /^@(.*),-(\d+)$/.exec(value);
      if (match !== null) {
        Compare("LoadString", `${systemDirectory}\\${match[1]}`, Number(match[2]));
      }
    }
  }
  const dynamic = `${key}\\Dynamic DST`;
  if (Compare("RegistryKeyExists", dynamic) === true) {
    Compare("GetRegistrySubKeyNames", dynamic);
    const first = Compare("GetRegistryValue", dynamic, "FirstEntry");
    const last = Compare("GetRegistryValue", dynamic, "LastEntry");
    if (typeof first === "number" && typeof last === "number") {
      for (let year = first; year <= last; year++) {
        Compare("GetRegistryValue", dynamic, String(year));
      }
    }
  }
}
Compare("LoadString", `${systemDirectory}\\no-such-file.dll`, 1);

/** Records a failure unless the addon's operation throws errorType with message. */
function ExpectThrows(errorType: ErrorConstructor, message: string, operation: string, ...args: unknown[]): void {
  checks++;
  try {
    addon[operation]!(...args);
    failures.push(`${operation}: expected ${errorType.name} "${message}"`);
  } catch (e) {
    if (!(e instanceof errorType) || e.message !== message) {
      failures.push(`${operation}: expected ${errorType.name} "${message}", got ${String(e)}`);
    }
  }
}

ExpectThrows(TypeError, "Missing string argument", "RegistryKeyExists");
ExpectThrows(TypeError, "Expected a string argument", "FileExists", 1);
ExpectThrows(RangeError, "String argument too long", "GetRegistrySubKeyNames", "x".repeat(32768));
ExpectThrows(TypeError, "Missing string argument", "GetRegistryValue", timeZones);
ExpectThrows(TypeError, "Expected a resource ID", "LoadString", `${systemDirectory}\\tzres.dll`);

console.log(`${checks} checks over ${ids.length} time zones; ${failures.length} differences.`);
for (const failure of failures.slice(0, 20)) {
  console.log(failure);
}
process.exit(failures.length === 0 ? 0 : 1);
