// Checks that a release's assets (those matching --pattern) are byte-identical to the files this build made.
// Usage: node scripts/release/compare-release-assets.ts --tag v3.3.1 --built ts/artifacts artifacts [--pattern "noda_dart-*.tar.gz"]
import { rmSync } from "node:fs";
import path from "node:path";
import { fail, glob, program, sha256, tempDir } from "noda-scripts/ci";
import { downloadReleaseAssets } from "noda-scripts/gh";

const { tag, built, pattern } = program
  .description("Checks a release's assets against this build's files.")
  .requiredOption("--tag <tag>", "the release tag")
  .requiredOption("--built <dirs...>", "repo-relative directories holding the built assets (the files directly in them)")
  .option("--pattern <glob>", "only the assets matching this", "*")
  .parse().opts<{ tag: string; built: string[]; pattern: string }>();

const files = new Map(built.flatMap((dir) => glob(dir, pattern).map((name) => [name, `${dir}/${name}`] as const)));
const released = tempDir("noda-release-");
downloadReleaseAssets(tag, pattern, released);
try {
  const builtNames = [...files.keys()].sort().join(", ");
  const releasedNames = glob(released, pattern).join(", ");
  if (builtNames !== releasedNames) {
    fail(`The release's assets (${releasedNames}) aren't the ones this build makes (${builtNames}).`);
  }
  for (const [name, file] of files) {
    const [a, b] = [sha256(file), sha256(path.join(released, name))];
    console.log(`${name}: built ${a}, released ${b}`);
    if (a !== b) fail(`${name} built here differs from the one attached to the release.`);
  }
  console.log(`All ${files.size} assets of ${tag} match this build.`);
} finally {
  rmSync(released, { recursive: true, force: true });
}
