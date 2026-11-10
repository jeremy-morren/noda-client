// Fails if HEAD is tagged with a release version other than the given one.
// Usage: node scripts/release/check-head-tag.ts --version 3.3.1
import { checkVersion, fail, git, program, semver } from "noda-scripts/ci";

const { version } = program
  .description("Fails if HEAD is tagged with another release version.")
  .requiredOption("--version <version>", "the version HEAD is released as", checkVersion)
  .parse().opts<{ version: string }>();
const tag = await git().tag();

const others = tag.split("\n")
  .filter(tag => semver.valid(tag) && semver.clean(tag) !== version);
if (others.length > 0) {
  fail(`HEAD is tagged ${others.join(", ")}, so it can't be released as v${version}.`);
}
console.log("HEAD isn't tagged with another version.");
