// Vitest's JUnit reporter, with each test file's suite (and each test's classname) named after its project too:
// "test/ported/LocalDateTest.test.ts [firefox]". The same file runs in the node, chromium, firefox and webkit
// projects, and a failure should say which one. `npm run test:ci` uses it with `--outputFile.junit=...`, like the
// built-in `junit` reporter.

import { JUnitReporter } from "vitest/node";

const name = "{filename} [{displayName}]";

export default class ProjectJUnitReporter extends JUnitReporter {
  constructor() {
    super({ suiteNameTemplate: name, classnameTemplate: name });
  }
}
