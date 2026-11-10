// Checks noda_dart's packed archive as pub sees it (dart pub publish --dry-run), or publishes it (--publish), from an
// extracted copy outside git.
// Usage: node dart/scripts/package/validate-package.ts [--archive <path>] [--publish]
import { rmSync } from "node:fs";
import path from "node:path";
import { fail, glob, program, resolvePath, run, stage, tc, tempDir, trackedFiles } from "noda-scripts/ci";

const { archive, publish } = program
  .description("Checks (or publishes) noda_dart's packed archive with pub.")
  .option("--archive <path>", "the archive, repo-relative or a temp path (default: the one artifacts/noda_dart-*.tar.gz)")
  .option("--publish", "publish it to pub.dev instead of the dry run")
  .parse().opts<{ archive?: string; publish?: boolean }>();
const archives = archive ? [archive] : glob("artifacts", "noda_dart-*.tar.gz").map((f) => `artifacts/${f}`);
if (archives.length !== 1) fail(`Expected one archive, found ${archives.length}: pass --archive or run dart/scripts/package/pack.ts.`);

const work = tempDir("noda-dart-package-");
try {
  // The package beside its dev_dependency ../test_apps/system_source_checks, as in the repository.
  const packageDir = await tc.extractTar(resolvePath(archives[0]!), path.join(work, "dart/noda_dart"));
  stage(work, "dart/test_apps/system_source_checks", await trackedFiles("dart/test_apps/system_source_checks"));
  run("dart", ["pub", "get"], { cwd: packageDir });
  run("dart", ["pub", "publish", publish ? "--force" : "--dry-run"], { cwd: packageDir });
  console.log(`${path.basename(archives[0]!)}: ${publish ? "published" : "valid"}.`);
} finally {
  rmSync(work, { recursive: true, force: true });
}
