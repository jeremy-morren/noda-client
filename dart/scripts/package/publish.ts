// Publishes a release's noda_dart archive to pub.dev, from an extracted copy outside git.
// Usage: node dart/scripts/package/publish.ts --tag v3.3.1
import { rmSync } from "node:fs";
import path from "node:path";
import { glob, program, run, stage, tc, tempDir, trackedFiles } from "noda-scripts/ci";
import { downloadReleaseAssets } from "noda-scripts/gh";

const { tag } = program
  .description("Publishes a release's noda_dart archive to pub.dev.")
  .requiredOption("--tag <tag>", "the release tag")
  .parse().opts<{ tag: string }>();

const work = tempDir("noda-dart-publish-");
try {
  downloadReleaseAssets(tag, "noda_dart-*.tar.gz", work);
  const [archive] = glob(work, "noda_dart-*.tar.gz");
  // The package beside its dev_dependency ../test_apps/system_source_checks, as in the repository.
  const packageDir = await tc.extractTar(path.join(work, archive!), path.join(work, "dart/noda_dart"));
  stage(work, "dart/test_apps/system_source_checks", await trackedFiles("dart/test_apps/system_source_checks"));
  run("dart", ["pub", "get"], { cwd: packageDir });
  run("dart", ["pub", "publish", "--force"], { cwd: packageDir });
} finally {
  rmSync(work, { recursive: true, force: true });
}
