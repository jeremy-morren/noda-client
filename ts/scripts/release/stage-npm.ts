// Stages a release's npm tarballs on npm (npm stage publish; live once a maintainer approves them).
// Usage: node ts/scripts/release/stage-npm.ts --tag v3.3.1
import { rmSync } from "node:fs";
import path from "node:path";
import { glob, program, run, tempDir } from "noda-scripts/ci";
import { downloadReleaseAssets } from "noda-scripts/gh";

const { tag } = program
  .description("Stages a release's npm tarballs on npm.")
  .requiredOption("--tag <tag>", "the release tag")
  .parse().opts<{ tag: string }>();

const work = tempDir("noda-js-npm-");
try {
  downloadReleaseAssets(tag, "*.tgz", work);
  // A path, not "dir/file.tgz", which npm reads as a GitHub repository.
  for (const tarball of glob(work, "*.tgz")) run("npm", ["stage", "publish", path.join(work, tarball)]);
} finally {
  rmSync(work, { recursive: true, force: true });
}
