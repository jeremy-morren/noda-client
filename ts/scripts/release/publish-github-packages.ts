// Publishes a release's npm tarballs to GitHub Packages as @<owner>/<name> (its npm registry only takes the owner's scope).
// npm authenticates with setup-node's .npmrc.
// Usage: node ts/scripts/release/publish-github-packages.ts --tag v3.3.1 --owner jeremy-morren [--dry-run]
import { rmSync } from "node:fs";
import path from "node:path";
import { glob, program, readJson, run, tc, tempDir, writeFile } from "noda-scripts/ci";
import { downloadReleaseAssets } from "noda-scripts/gh";

const { tag, owner, dryRun } = program
  .description("Publishes a release's npm tarballs to GitHub Packages.")
  .requiredOption("--tag <tag>", "the release tag")
  .requiredOption("--owner <owner>", "the repository's owner (the packages' scope)")
  .option("--dry-run", "npm publish --dry-run")
  .parse().opts<{ tag: string; owner: string; dryRun?: boolean }>();

const work = tempDir("noda-js-github-packages-");
try {
  downloadReleaseAssets(tag, "*.tgz", work);
  for (const tgz of glob(work, "*.tgz")) {
    const cwd = path.join(await tc.extractTar(path.join(work, tgz), path.join(work, path.basename(tgz, ".tgz"))), "package");
    const manifest = readJson(path.join(cwd, "package.json"));
    manifest.name = `@${owner.toLowerCase()}/${manifest.name}`;
    manifest.publishConfig = { registry: "https://npm.pkg.github.com" };
    writeFile(path.join(cwd, "package.json"), JSON.stringify(manifest, null, 2) + "\n");
    // --ignore-scripts: prepack copies files the tarball already has.
    run("npm", ["publish", "--ignore-scripts", ...(dryRun ? ["--dry-run"] : [])], { cwd });
  }
} finally {
  rmSync(work, { recursive: true, force: true });
}
