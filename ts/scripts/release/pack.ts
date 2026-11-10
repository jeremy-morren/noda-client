// Packs npm packages with a release version into ts/artifacts/ from staged copies (the checkout is unchanged):
// noda-js-zod's peer dependency ^version, noda-js's native optional dependencies and changelog section.
// Usage: node ts/scripts/release/pack.ts --version 3.3.1 [<package dir>...]   (repo-relative; default ts/src/noda-js ts/src/noda-js-zod)
import { mkdirSync, rmSync } from "node:fs";
import path from "node:path";
import { checkVersion, copy, program, readJson, releaseChangelog, resolvePath, run, stage, tempDir, writeFile } from "noda-scripts/ci";

program
  .description("Packs npm packages with a release version.")
  .requiredOption("--version <version>", "the release version", checkVersion)
  .argument("[packages...]", "repo-relative package directories", ["ts/src/noda-js", "ts/src/noda-js-zod"])
  .parse();
const { version } = program.opts<{ version: string }>();
mkdirSync(resolvePath("ts/artifacts"), { recursive: true });

const stageRoot = tempDir("noda-js-pack-");
try {
  for (const source of program.processedArgs[0] as string[]) {
    const target = stage(stageRoot, source);
    copy("LICENSE.txt", path.join(target, "LICENSE.txt"));
    copy("NOTICE.txt", path.join(target, "NOTICE.txt"));
    const manifestFile = path.join(target, "package.json");
    const manifest = readJson(manifestFile);
    manifest.version = version;
    if (manifest.name === "noda-js-zod") {
      manifest.peerDependencies["noda-js"] = `^${version}`;
    }
    if (manifest.name === "noda-js") {
      // Only in releases: in the repository npm would look for them on the registry.
      manifest.optionalDependencies = { "noda-js-win-x64": version, "noda-js-win-arm64": version };
      releaseChangelog(stageRoot, version, "noda-js");
    }
    writeFile(manifestFile, JSON.stringify(manifest, null, 2) + "\n");
    // --ignore-scripts: prepack's copies are done above.
    run("npm", ["pack", "--ignore-scripts", "--pack-destination", resolvePath("ts/artifacts")], { cwd: target });
  }
} finally {
  rmSync(stageRoot, { recursive: true, force: true });
}
