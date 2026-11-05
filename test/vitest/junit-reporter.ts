// Vitest's JUnit reporter, with each test file's suite named after its project too: the same file runs in the
// node, chromium, firefox and webkit projects, and a failure should say which one. `npm run test:ci` uses it with
// `--outputFile.junit=...`, like the built-in `junit` reporter.

import type { RunnerTestFile } from "vitest";
import type { Vitest } from "vitest/node";
import { JUnitReporter } from "vitest/reporters";

export default class ProjectJUnitReporter extends JUnitReporter {
  private vitest: Vitest | undefined;

  override async onInit(ctx: Vitest): Promise<void> {
    this.vitest = ctx;
    await super.onInit(ctx);
  }

  // The suite name (and each test's classname) is the file's path relative to the root:
  // "test/ported/LocalDateTest.test.ts [firefox]".
  override async onFinished(files: RunnerTestFile[] = this.vitest!.state.getFiles()): Promise<void> {
    await super.onFinished(files.map(file => (file.projectName ? { ...file, filepath: `${file.filepath} [${file.projectName}]` } : file)));
  }
}
