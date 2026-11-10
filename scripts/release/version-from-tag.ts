// The version a release tag vMAJOR.MINOR.PATCH publishes, as the step output "version" (must be in version.txt's MAJOR.MINOR).
// Usage: node scripts/release/version-from-tag.ts --tag v3.3.1
import { checkVersion, fail, majorMinor, program, semver, setOutput } from "noda-scripts/ci";

const { tag } = program
  .description("Sets the step output \"version\" from a release tag.")
  .requiredOption("--tag <tag>", "the release tag (vMAJOR.MINOR.PATCH)")
  .parse().opts<{ tag: string }>();
const version = checkVersion(semver.clean(tag) ?? tag);
if (`${semver.major(version)}.${semver.minor(version)}` !== majorMinor()) {
  fail(`The tag ${tag} isn't in version.txt's major.minor (${majorMinor()}).`);
}
setOutput("version", version);
