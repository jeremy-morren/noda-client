// Gives the current Windows time zone localized display names (as on non-English Windows), keeping its ID and rules.
// Needs SeTimeZonePrivilege (an administrator). Windows only.
// Usage: node scripts/time-zones/set-windows-time-zone-names.ts --standard "Mitteleuropäische Zeit" --daylight "Mitteleuropäische Sommerzeit" [--dry-run]
import { dlopen } from "node:ffi";
import { fail, program } from "noda-scripts/ci";

const { standard, daylight, dryRun } = program
  .description("Sets the current Windows time zone's display names (administrator).")
  .requiredOption("--standard <name>", "the standard time name")
  .requiredOption("--daylight <name>", "the daylight time name")
  .option("--dry-run", "only show the current names")
  .parse().opts<{ standard: string; daylight: string; dryRun?: boolean }>();

const kernel32 = dlopen("kernel32.dll", {
  GetCurrentProcess: { arguments: [], return: "pointer" },
  GetLastError: { arguments: [], return: "uint32" },
  GetDynamicTimeZoneInformation: { arguments: ["pointer"], return: "uint32" },
  SetDynamicTimeZoneInformation: { arguments: ["pointer"], return: "int32" },
}).functions;
const advapi32 = dlopen("advapi32.dll", {
  OpenProcessToken: { arguments: ["pointer", "uint32", "pointer"], return: "int32" },
  LookupPrivilegeValueW: { arguments: ["pointer", "pointer", "pointer"], return: "int32" },
  AdjustTokenPrivileges: { arguments: ["pointer", "int32", "pointer", "uint32", "pointer", "pointer"], return: "int32" },
}).functions;

/** A null-terminated UTF-16 string. */
function wide(value: string): Buffer {
  return Buffer.from(value + "\0", "utf16le");
}

/** Reads a UTF-16 string of at most chars characters, up to its null. */
function readWide(buffer: Buffer, offset: number, chars: number): string {
  return buffer.toString("utf16le", offset, offset + 2 * chars).replace(/\0.*$/s, "");
}

// DYNAMIC_TIME_ZONE_INFORMATION: StandardName at 4 and DaylightName at 88 (32 chars each), TimeZoneKeyName at 172.
/** The current DYNAMIC_TIME_ZONE_INFORMATION. */
function read(): Buffer {
  const info = Buffer.alloc(432);
  kernel32.GetDynamicTimeZoneInformation(info);
  return info;
}

/** The zone's ID and display names. */
function describe(info: Buffer): string {
  return `Time zone ${readWide(info, 172, 128)}: '${readWide(info, 4, 32)}' / '${readWide(info, 88, 32)}'`;
}

const info = read();
console.log(describe(info));
if (dryRun) {
  console.log(`Would set '${standard}' / '${daylight}'.`);
  process.exit(0);
}

// TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY; TOKEN_PRIVILEGES { Count = 1, LUID, SE_PRIVILEGE_ENABLED }.
const token = Buffer.alloc(8);
advapi32.OpenProcessToken(kernel32.GetCurrentProcess(), 0x28, token);
const luid = Buffer.alloc(8);
advapi32.LookupPrivilegeValueW(null, wide("SeTimeZonePrivilege"), luid);
const privileges = Buffer.alloc(16);
privileges.writeUInt32LE(1, 0);
luid.copy(privileges, 4);
privileges.writeUInt32LE(2, 12);
advapi32.AdjustTokenPrivileges(token.readBigUInt64LE(0), 0, privileges, 0, null, null);

info.fill(0, 4, 68).write(standard.slice(0, 31), 4, "utf16le");
info.fill(0, 88, 152).write(daylight.slice(0, 31), 88, "utf16le");
if (!kernel32.SetDynamicTimeZoneInformation(info)) {
  fail(`SetDynamicTimeZoneInformation failed: ${kernel32.GetLastError()}`);
}
const applied = read();
console.log(describe(applied));
if (readWide(applied, 4, 32) !== standard) {
  fail("The display names were not applied.");
}
