// The Flutter app the scripts beside this run the system time zone checks in.
import { safeFileName } from "noda-scripts/ci";

/** The app's directory. */
export const app = "dart/test_apps/system_source_flutter";

/** flutter test arguments: results in test-results/flutter-<device>@<label>.json, and the zone the app expects. */
export function testArgs(device: string, label: string, expected: string): string[] {
  return ["--reporter", "expanded", "--file-reporter", `json:test-results/flutter-${device}@${safeFileName(label)}.json`,
    `--dart-define=NODA_EXPECT_SYSTEM_TIME_ZONE=${expected}`];
}
