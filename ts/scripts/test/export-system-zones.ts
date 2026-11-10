// Exports what NodaTime's BclDateTimeZoneSource sees on this machine, for both ports' WindowsComparison tests
// (meaningful on Windows only).
// Usage: npm run test:export-system-zones [-- --output <file>]
import { nodaJsTools, program, resolvePath } from "noda-scripts/ci";

const { output } = program
  .description("Exports NodaTime's view of this machine's time zones.")
  .option("--output <file>", "the repo-relative JSON file to write", "testdata/system-zones.json")
  .parse().opts<{ output: string }>();
nodaJsTools("system-zones", "--output", resolvePath(output));
