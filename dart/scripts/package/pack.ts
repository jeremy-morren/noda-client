// Packs noda_dart as pub publishes it (its tracked files) with a release version, reproducibly, from a staged copy
// (the checkout is unchanged): artifacts/noda_dart-<version>.tar.gz.
// Usage: node dart/scripts/package/pack.ts [--version 3.3.1]
import { mkdirSync, rmSync } from "node:fs";
import path from "node:path";
import { parseDocument } from "yaml";
import { checkVersion, commitTime, majorMinor, nodaJsPackage, program, readFile, releaseChangelog, resolvePath, stage, tempDir, trackedFiles, writeFile } from "noda-scripts/ci";

const { version } = program
  .description("Packs noda_dart with a release version.")
  .option("--version <version>", "the release version (default: version.txt's MAJOR.MINOR.0)", checkVersion, `${majorMinor()}.0`)
  .parse().opts<{ version: string }>();
const files = await trackedFiles("dart/noda_dart");
const archive = `artifacts/noda_dart-${version}.tar.gz`;

const stageRoot = tempDir("noda-dart-pack-");
try {
  const staged = stage(stageRoot, "dart/noda_dart", files);
  const pubspec = path.join(staged, "pubspec.yaml");
  const document = parseDocument(readFile(pubspec));
  document.set("version", version);
  writeFile(pubspec, document.toString({ lineWidth: 0, flowCollectionPadding: false }));
  releaseChangelog(stageRoot, version, "noda_dart");
  // The list goes in a file: it's longer than a Windows command line can be.
  const list = path.join(stageRoot, "files.txt");
  writeFile(list, files.join("\n") + "\n");
  mkdirSync(resolvePath("artifacts"), { recursive: true });
  nodaJsPackage("tar-gzip", resolvePath(archive), "--files-from", list, "--directory", staged, "--time", await commitTime());
  console.log(`${archive} (${files.length} files)`);
} finally {
  rmSync(stageRoot, { recursive: true, force: true });
}
