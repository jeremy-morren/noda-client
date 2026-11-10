// Publishes noda_dart's packed archive to pub.dev, or checks it as pub sees it (--dry-run),
// from an extracted copy outside git.
// Usage: node dart/scripts/package/publish.ts [--archive <path>] [--dry-run]
import { rmSync } from "node:fs";
import path from "node:path";
import { fail, glob, program, resolvePath, run, stage, tc, tempDir, trackedFiles } from "noda-scripts/ci";

const { archive, dryRun } = program
  .description("Publishes noda_dart's packed archive to pub.dev (or checks it).")
  .option("--archive <path>", "the archive, repo-relative or a temp path (default: the one artifacts/noda_dart-*.tar.gz)")
  .option("--dry-run", "only check it (dart pub publish --dry-run)")
  .parse().opts<{ archive?: string; dryRun?: boolean }>();
const archives = archive ? [archive] : glob("artifacts", "noda_dart-*.tar.gz").map((f) => `artifacts/${f}`);
if (archives.length !== 1) fail(`Expected one archive, found ${archives.length}: pass --archive or run dart/scripts/package/pack.ts.`);

const work = tempDir("noda-dart-package-");
try {
  // The package beside its dev_dependency ../test_apps/system_source_checks, as in the repository.
  const packageDir = await tc.extractTar(resolvePath(archives[0]!), path.join(work, "dart/noda_dart"));
  stage(work, "dart/test_apps/system_source_checks", await trackedFiles("dart/test_apps/system_source_checks"));
  run("dart", ["pub", "get"], { cwd: packageDir });
  run("dart", ["pub", "publish", dryRun ? "--dry-run" : "--force"], { cwd: packageDir });
  console.log(`${path.basename(archives[0]!)}: ${dryRun ? "valid" : "published"}.`);
} finally {
  rmSync(work, { recursive: true, force: true });
}
