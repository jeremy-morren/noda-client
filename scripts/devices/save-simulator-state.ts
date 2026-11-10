// Saves the booted iOS Simulator's screen and Safari's WebDriver logs, for diagnosing a failed run (missing ones are
// skipped). macOS with Xcode.
// Usage: node scripts/devices/save-simulator-state.ts --out ts/test-results/ios
import { mkdirSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { program, resolvePath, run } from "noda-scripts/ci";

const { out } = program
  .description("Saves the booted iOS Simulator's screen and WebDriver logs.")
  .requiredOption("--out <dir>", "the repo-relative directory to save them in")
  .parse().opts<{ out: string }>();
const dir = resolvePath(out);
mkdirSync(dir, { recursive: true });
run("xcrun", ["simctl", "io", "booted", "screenshot", path.join(dir, "screen.png")], { check: false });
run("cp", ["-R", path.join(os.homedir(), "Library/Logs/com.apple.WebDriver"), dir], { check: false });
