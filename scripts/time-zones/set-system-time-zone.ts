// Sets the machine's time zone: Windows with tzutil (an administrator), Linux and macOS by linking /etc/localtime to
// the zone's TZif file (sudo). Changes the machine: for CI.
// Usage: node scripts/time-zones/set-system-time-zone.ts <zone>   (a Windows ID on Windows, else an IANA ID)
import { capture, isWindows, program, run } from "noda-scripts/ci";

program
  .description("Sets the machine's time zone (administrator or sudo).")
  .argument("<zone>", "a Windows ID on Windows, else an IANA ID")
  .parse();
const [zone] = program.processedArgs as [string];

if (isWindows) {
  run("tzutil", ["/s", zone]);
  console.log(`Windows time zone: ${capture("tzutil", ["/g"])}`);
} else {
  const zoneinfo = process.platform === "darwin" ? "/var/db/timezone/zoneinfo" : "/usr/share/zoneinfo";
  run("sudo", ["ln", "-sf", `${zoneinfo}/${zone}`, "/etc/localtime"]);
  console.log(`/etc/localtime: ${capture("ls", ["-l", "/etc/localtime"])}`);
}
