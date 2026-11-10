// Vitest's JUnit reporter, naming each suite after its project and blob label too:
// "test/ported/LocalDateTest.test.ts [firefox, macos-arm64]".

import { JUnitReporter, type TestModule } from "vitest/node";

type NameVariables = { filename: string; filepath: string; displayName: string };
type FileInfo = { name: string; label: string | undefined };

const key = (project: string, filepath: string) => `${project}\0${filepath}`;

/** The name templates only get a file's project and absolute path. */
type FileLookup = {
  readonly byFile: WeakMap<object, FileInfo>;
  /** In test-module order: two machines with the same checkout path give one key two entries. */
  readonly byPath: Map<string, FileInfo[]>;
  readonly named: Map<string, number>;
  writing: FileInfo | undefined;
};

export default class ProjectJUnitReporter extends JUnitReporter {
  // Names relative to each machine's own checkout (Vitest's {filename} is relative to this one).
  private readonly lookup: FileLookup;

  constructor() {
    const lookup: FileLookup = { byFile: new WeakMap(), byPath: new Map(), named: new Map(), writing: undefined };
    const format = (vars: NameVariables, file: FileInfo | undefined) => {
      const project = file?.label ? `${vars.displayName}, ${file.label}` : vars.displayName;
      return `${file?.name ?? vars.filename} [${project}]`;
    };
    super({
      // Suites are named in test-module order: the nth with a key is that key's nth module.
      suiteNameTemplate: (vars: NameVariables) => {
        const k = key(vars.displayName, vars.filepath);
        const n = lookup.named.get(k) ?? 0;
        lookup.named.set(k, n + 1);
        return format(vars, lookup.byPath.get(k)?.[n]);
      },
      classnameTemplate: (vars: NameVariables) => format(vars, lookup.writing ?? lookup.byPath.get(key(vars.displayName, vars.filepath))?.[0]),
    });
    this.lookup = lookup;
  }

  override onTestRunEnd(testModules: ReadonlyArray<TestModule>, unhandledErrors?: Parameters<JUnitReporter["onTestRunEnd"]>[1]): Promise<void> {
    for (const testModule of testModules) {
      const file: FileInfo = { name: testModule.relativeModuleId, label: testModule.meta().__vitest_label__ };
      // task isn't in the public types; testModule.id is the same for two blobs.
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
