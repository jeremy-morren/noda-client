// Regenerates every generated file of both ports with tools/NodaJs.Tools.
// Usage: node tools/generate.ts [--only all|data|cldr|scenarios] [--tzdb compile|latest|embedded] [--tzdata <url|path>] [--cldr <path>]
import { nodaJsTools, Option, program } from "noda-scripts/ci";

const { only, tzdb, tzdata, cldr } = program
  .description("Regenerates both ports' generated files.")
  .addOption(new Option("--only <command>", "one NodaJs.Tools command").choices(["all", "data", "cldr", "scenarios"]).default("all"))
  .addOption(new Option("--tzdb <source>", "compile tzdata, or bundle nodatime.org's latest or the pinned NodaTime's embedded NZD").choices(["compile", "latest", "embedded"]).default("compile"))
  .option("--tzdata <url|path>", "the IANA tzdata tarball to compile (default: the latest release)")
  .option("--cldr <path>", "a windowsZones.xml file (default: the one NodaTime picks from its data/cldr)")
  .parse().opts<{ only: string; tzdb: string; tzdata?: string; cldr?: string }>();

const args: string[] = [];
if (only === "all" || only === "data") {
  args.push("--tzdb", tzdb);
  if (tzdata) args.push("--tzdata", tzdata);
}
if (only !== "scenarios" && cldr) args.push("--cldr", cldr);
nodaJsTools(only, ...args);
