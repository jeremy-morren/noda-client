// Runs the Flutter app's system time zone checks on a booted Android emulator, with a time limit per attempt (a hang is
// retried once; a test failure isn't), writing test-results/flutter-android@Android-API-<level>-<abi>.json and the
// device log to test-results/logcat.txt.
// Usage: node dart/scripts/flutter/android.ts --expected America/New_York [--device emulator-5554] [--minutes 15]
import { capture, core, pRetry, program, run, start, writeFile } from "noda-scripts/ci";
import { app, testArgs } from "./app.ts";

const { device, minutes, expected } = program
  .description("Runs the Flutter app's system time zone checks on an Android emulator, retrying a hang once.")
  .requiredOption("--expected <id>", "the emulator's zone (IANA ID)")
  .option("--device <id>", "the emulator's adb device id", "emulator-5554")
  .option("--minutes <n>", "the time limit per attempt", Number, 15)
  .parse().opts<{ device: string; minutes: number; expected: string }>();

/** A system property of the device. */
function getprop(name: string): string {
  return capture("adb", ["-s", device, "shell", "getprop", name]).trim();
}

const label = `Android-API-${getprop("ro.build.version.sdk")}-${getprop("ro.product.cpu.abi")}`;
console.log(`${device} (${label}): persist.sys.timezone=${getprop("persist.sys.timezone")}`);
const args = ["test", "integration_test", "--device-id", device, ...testArgs("android", label, expected)];

/** Runs flutter test once; throws if it timed out. */
async function attempt(): Promise<number> {
  const result = await start("flutter", args, {
    cwd: app, stdio: "inherit", reject: false, timeout: minutes * 60_000, forceKillAfterDelay: 30_000,
  });
  if (result.timedOut) throw new Error(`flutter test didn't finish within ${minutes} minutes`);
  return result.exitCode ?? 1;
}

run("adb", ["-s", device, "logcat", "-c"], { check: false });
try {
  process.exitCode = await pRetry(attempt, {
    retries: 1,
    minTimeout: 0,
    onFailedAttempt: ({ attemptNumber }) => {
      core.warning(`flutter test didn't finish within ${minutes} minutes on ${device} (attempt ${attemptNumber} of 2)`);
      run("adb", ["-s", device, "shell", "am", "force-stop", "dev.nodadart.system_source_test_app"], { check: false });
    },
  }).catch(() => 1);
} finally {
  const logcat = `${app}/test-results/logcat.txt`;
  writeFile(logcat, (await start("adb", ["-s", device, "logcat", "-d"], { all: true, reject: false })).all ?? "");
  console.log(`Device log: ${logcat}`);
}
