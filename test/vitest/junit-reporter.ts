// Vitest's JUnit reporter, with each test file's suite (and each test's classname) named after its project too:
// "test/ported/LocalDateTest.test.ts [firefox]". The same file runs in the node, chromium, firefox and webkit
// projects, and a failure should say which one. `npm run test:ci` uses it with `--outputFile.junit=...`, like the
// built-in `junit` reporter.
//
// CI runs the projects on several machines, each writing a blob report labelled with where it ran, its platform and
// architecture (VITEST_BLOB_LABEL: "linux-x64", "windows-arm64", "macos-arm64", an iOS or Android device; see
// scripts/test-blob.ps1), and merges them with `vitest --merge-reports` (see .github/workflows/ci.yml). There the label
// follows the project: "test/ported/LocalDateTest.test.ts [firefox, macos-arm64]".

import { JUnitReporter, type TestModule } from "vitest/node";

type NameVariables = { filename: string; filepath: string; displayName: string };
type FileInfo = { name: string; label: string | undefined };

const key = (project: string, filepath: string) => `${project}\0${filepath}`;

/** What the name templates look up (they only get a file's project and absolute path, not the file). */
type FileLookup = {
  /** Each test module's info, by its task (the File that writeTasks' tasks point to). */
  readonly byFile: WeakMap<object, FileInfo>;
  /**
   * The same, by project and absolute path, in test-module order. Two machines with the same checkout path (e.g. the
   * Windows x64 and ARM64 runners, were they both on D:) give one key two entries.
   */
  readonly byPath: Map<string, FileInfo[]>;
  /** How many suites have been named with each key. */
  readonly named: Map<string, number>;
  /** The file writeTasks is writing the tests of. */
  writing: FileInfo | undefined;
};

export default class ProjectJUnitReporter extends JUnitReporter {
  // Each test file's name, relative to its own machine's checkout (Vitest's {filename} is relative to this one, which
  // doesn't work for another machine's paths), and its blob's label.
  private readonly lookup: FileLookup;

  constructor() {
    const lookup: FileLookup = { byFile: new WeakMap(), byPath: new Map(), named: new Map(), writing: undefined };
    const format = (vars: NameVariables, file: FileInfo | undefined) => {
      const project = file?.label ? `${vars.displayName}, ${file.label}` : vars.displayName;
      return `${file?.name ?? vars.filename} [${project}]`;
    };
    super({
      // Vitest names the suites in test-module order (before sorting them), so the nth suite named with a key is that
      // key's nth module.
      suiteNameTemplate: (vars: NameVariables) => {
        const k = key(vars.displayName, vars.filepath);
        const n = lookup.named.get(k) ?? 0;
        lookup.named.set(k, n + 1);
        return format(vars, lookup.byPath.get(k)?.[n]);
      },
      // A test's file is the one writeTasks is writing (else, for a file that failed to load, the first with its path).
      classnameTemplate: (vars: NameVariables) => format(vars, lookup.writing ?? lookup.byPath.get(key(vars.displayName, vars.filepath))?.[0]),
    });
    this.lookup = lookup;
  }

  override onTestRunEnd(testModules: ReadonlyArray<TestModule>, unhandledErrors?: Parameters<JUnitReporter["onTestRunEnd"]>[1]): Promise<void> {
    // (When merging, each module's project is the blob's: scripts/merge-test-reports.ps1 defines every project.)
    for (const testModule of testModules) {
      const file: FileInfo = { name: testModule.relativeModuleId, label: testModule.meta().__vitest_label__ };
      // The module's File task: JUnitReporter.onTestRunEnd reads it as testModule.task too, though it isn't in the
      // public types. (Not testModule.id: that's a hash of the project and relative path, the same for both blobs.)
      this.lookup.byFile.set((testModule as unknown as { readonly task: object }).task, file);
      const k = key(testModule.project.name, testModule.moduleId);
      const files = this.lookup.byPath.get(k);
      if (files === undefined) {
        this.lookup.byPath.set(k, [file]);
      } else {
        files.push(file);
      }
    }
    return super.onTestRunEnd(testModules, unhandledErrors);
  }

  override async writeTasks(...args: Parameters<JUnitReporter["writeTasks"]>): Promise<void> {
    const task = args[0].find(t => t.file);
    this.lookup.writing = task?.file ? this.lookup.byFile.get(task.file) : undefined;
    try {
      await super.writeTasks(...args);
    } finally {
      this.lookup.writing = undefined;
    }
  }
}
