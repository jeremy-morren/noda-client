// Runs the Flutter app's system time zone checks on the booted iOS Simulator (scripts/devices/start-ios-simulator.ts),
// writing test-results/flutter-ios@<label>.json, up to 3 attempts when Flutter fails to start the tests: it hangs
// waiting for the app's VM service (https://github.com/flutter/flutter/issues/181771; seen as QUIET_LIMIT_SECONDS,
// default 120, of silence after "Xcode build done"), or reports "Unable to start the app on the device". A test
// failure isn't retried.
// Usage: node dart/scripts/flutter/ios-simulator.ts --expected Australia/Sydney [--udid <udid>] [--label <label>]
import { core, pRetry, program, run, start } from "noda-scripts/ci";
import { app, testArgs } from "./app.ts";

const { udid, label, expected } = program
  .description("Runs the Flutter app's system time zone checks on an iOS Simulator, retrying when they don't start.")
  .requiredOption("--expected <id>", "the Simulator's zone (IANA ID)")
  .requiredOption("--udid <udid>", "the booted simulator (default: NODA_TEST_IOS_UDID)", process.env["NODA_TEST_IOS_UDID"])
  .requiredOption("--label <label>", "where it ran (default: NODA_TEST_LABEL)", process.env["NODA_TEST_LABEL"])
  .parse().opts<{ udid: string; label: string; expected: string }>();
const bundleId = "dev.nodadart.systemSourceTestApp";
const attempts = 3;
const quietLimit = Number(process.env["QUIET_LIMIT_SECONDS"] || 120) * 1000;

/** Runs flutter test once, echoing its output; throws if it didn't start the tests. */
async function attempt(): Promise<number> {
  const subprocess = start("flutter", ["test", "integration_test", "--device-id", udid, ...testArgs("ios", label, expected)], {
    cwd: app, all: true, stdout: ["pipe", "inherit"], stderr: ["pipe", "inherit"], reject: false,
  });
  let log = "";
  let lastOutput = Date.now();
  subprocess.all.on("data", (chunk: Buffer) => {
    log += chunk.toString();
    lastOutput = Date.now();
  });
  let hung = false;
  const watch = setInterval(() => {
    if (log.includes("Xcode build done") && Date.now() - lastOutput >= quietLimit) {
      hung = true;
      subprocess.kill();
    }
  }, 5000);
  const result = await subprocess;
  clearInterval(watch);
  if (hung) throw new Error("flutter test hung waiting for the app's VM service");
  if (result.exitCode !== 0 && log.includes("Unable to start the app on the device")) {
    throw new Error("flutter test couldn't start the app");
  }
  return result.exitCode ?? 1;
}

process.exitCode = await pRetry(attempt, {
  retries: attempts - 1,
  minTimeout: 0,
  onFailedAttempt: ({ error, attemptNumber }) => {
    core.warning(`${error.message} (attempt ${attemptNumber} of ${attempts})`);
    run("xcrun", ["simctl", "terminate", udid, bundleId], { check: false });
  },
}).catch(() => {
  core.error(`flutter test didn't start the tests in ${attempts} attempts`);
  return 1;
});
