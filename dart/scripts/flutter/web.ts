// Runs the Flutter app's system time zone checks in a browser with flutter drive, in release mode (the code that
// ships), through the browser's WebDriver started on port 4444 (its log: driver.log in the app). The expected zone is
// TZ, except in Safari, which ignores it. Safari's driver must be enabled once: sudo safaridriver --enable.
// Usage: node dart/scripts/flutter/web.ts --browser chrome [--expected Europe/Berlin]
import path from "node:path";
import { core, fail, Option, program, readFile, resolvePath, sleep, start, writeFile } from "noda-scripts/ci";
import { app } from "./app.ts";

const { browser, expected } = program
  .description("Runs the Flutter app's system time zone checks in a browser.")
  .addOption(new Option("--browser <browser>", "the browser").choices(["chrome", "firefox", "safari"]).makeOptionMandatory())
  .option("--expected <id>", "the expected zone ID (default: TZ; none in Safari)")
  .parse().opts<{ browser: string; expected?: string }>();
const port = 4444;
// flutter drive can hang with no output after serving the app.
const attemptMinutes = 10;
const driverLog = `${app}/driver.log`;

/** The browser's WebDriver command (GitHub's runners name the drivers' directories in CHROMEWEBDRIVER, GECKOWEBDRIVER). */
function driverCommand(): [string, string[]] {
  switch (browser) {
    case "chrome": return [path.join(process.env["CHROMEWEBDRIVER"] ?? "", "chromedriver"), [`--port=${port}`]];
    case "firefox": return [path.join(process.env["GECKOWEBDRIVER"] ?? "", "geckodriver"), ["--port", String(port)]];
    default: return ["safaridriver", ["--port", String(port)]];
  }
}

/** Waits until the WebDriver answers. */
async function waitForDriver(): Promise<void> {
  for (let i = 0; i < 60; i++) {
    if (await fetch(`http://127.0.0.1:${port}/status`).then((r) => r.ok, () => false)) return;
    await sleep(1000);
  }
  fail(`The ${browser} WebDriver didn't start on port ${port}.`);
}

/** One attempt with a fresh WebDriver (geckodriver takes one session at a time); returns whether the checks passed. */
async function drive(): Promise<boolean> {
  const log = { file: resolvePath(driverLog), append: true };
  const [command, args] = driverCommand();
  const driver = start(command, args, { stdin: "ignore", stdout: log, stderr: log, reject: false });
  try {
    await waitForDriver();
    const result = await start("flutter", ["drive", "-d", "web-server", `--browser-name=${browser}`, "--release",
      "--driver=test_driver/integration_test.dart", "--target=integration_test/system_source_test.dart",
      `--dart-define=NODA_EXPECT_SYSTEM_TIME_ZONE=${expected ?? (browser === "safari" ? "" : process.env["TZ"] ?? "")}`,
    ], { cwd: app, stdio: "inherit", reject: false, timeout: attemptMinutes * 60_000 });
    if (result.timedOut) console.log(`flutter drive was stopped after ${attemptMinutes} minutes.`);
    return result.exitCode === 0;
  } finally {
    driver.kill();
    await driver;
  }
}

writeFile(driverLog, "");
let passed = await drive();
if (!passed) {
  core.warning(`flutter drive failed in ${browser}; retrying once.`);
  passed = await drive();
}
if (!passed) {
  console.log(`${driverLog}:\n${readFile(driverLog)}`);
  process.exitCode = 1;
}
