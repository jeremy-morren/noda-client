// Runs the android-chrome test project in Chrome on the connected Android emulator or device, through Appium
// (with its UiAutomator2 driver, on PATH), labelled with the Android version, ABI and Chrome version.
// Usage: npm run test:android [-- <port>]   (default 23400: Vitest's browser server, forwarded with adb reverse)
import { mkdirSync } from "node:fs";
import { AbortError, capture, fail, pRetry, program, resolvePath, run, runScript, start } from "noda-scripts/ci";

program
  .description("Runs the android-chrome tests on the connected Android device.")
  .argument("[port]", "Vitest's browser server port", "23400")
  .parse();
const [port] = program.processedArgs as [string];

/** Runs adb shell and returns its trimmed output. */
function adbShell(...args: string[]): string {
  return capture("adb", ["shell", ...args]).replace(/\r/g, "").trim();
}

run("adb", ["wait-for-device"]);
if (!adbShell("pm", "list", "packages", "com.android.chrome").split("\n").includes("package:com.android.chrome")) {
  fail("Chrome (com.android.chrome) is not installed on the device; use a Google APIs system image.");
}
const chrome = /versionName=([0-9.]*)/.exec(adbShell("dumpsys", "package", "com.android.chrome"))?.[1] ?? "";
const label = `Android ${adbShell("getprop", "ro.build.version.release")} (${adbShell("getprop", "ro.product.cpu.abi")}), Chrome ${chrome.split(".")[0]}`;
console.log(`Device: ${label} (${chrome})`);

// Chrome reads this command line as the debug app: no first-run or default-browser screens over the page.
adbShell("echo '_ --disable-fre --no-default-browser-check --no-first-run' > /data/local/tmp/chrome-command-line");
adbShell("am", "set-debug-app", "--persistent", "com.android.chrome");
run("adb", ["reverse", `tcp:${port}`, `tcp:${port}`]);

mkdirSync(resolvePath("ts/test-results"), { recursive: true });
const appium = start("appium", ["--address", "127.0.0.1", "--port", "4723", "--allow-insecure", "uiautomator2:chromedriver_autodownload"], {
  stdout: { file: resolvePath("ts/test-results/appium.log") }, stderr: { file: resolvePath("ts/test-results/appium-error.log") }, reject: false,
});
let appiumExited = false;
void appium.then(() => (appiumExited = true));
try {
  await pRetry(async () => {
    if (appiumExited) throw new AbortError("Appium exited; see test-results/appium*.log.");
    const status = await fetch("http://127.0.0.1:4723/status", { signal: AbortSignal.timeout(5000) }).then((r) => r.json());
    if (!(status as { value?: { ready?: boolean } }).value?.ready) throw new Error("Appium isn't ready");
  }, { retries: 60, minTimeout: 2000, factor: 1, maxRetryTime: 120_000 });
  runScript("ts/scripts/test/test-blob.ts", ["--project", "android-chrome", "--label", label], { env: { NODA_TEST_API_PORT: port } });
} finally {
  appium.kill();
  run("adb", ["reverse", "--remove-all"], { check: false });
}
