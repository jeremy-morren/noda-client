// The next release's version, as the step output "version": version.txt's MAJOR.MINOR and one more than the highest
// published (non-draft) patch, or 0.
// Usage: node scripts/release/next-version.ts
import { majorMinor, program, semver, setOutput } from "noda-scripts/ci";
import { releases } from "noda-scripts/gh";

program.description("Sets the step output \"version\" to the next release's version.").parse();
const published = releases().filter((r) => !r.isDraft).map((r) => semver.clean(r.tagName)).filter((v) => v !== null);
const latest = semver.maxSatisfying(published, `~${majorMinor()}.0`);
setOutput("version", latest ? semver.inc(latest, "patch")! : `${majorMinor()}.0`);
