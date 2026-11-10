// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Tzdb/FileSource.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { GetFileName } from "../internal.ts";

/**
 * A random access collection of files.
 * @internal
 */
export class FileSource {
  /**
   * The name of the origin of the files - just the last part,
   * rather than the whole URL/path.
   */
  readonly Origin: string;

  /**
   * The names of the files.
   */
  readonly Names: readonly string[];

  private readonly _openFunction: (name: string) => Uint8Array;

  /**
   * NodaTime's private constructor, as a factory: noda-js builds sources outside this class (TzdbCompiler/Archive.ts).
   * @internal
   */
  static NewNamesOpenFunctionFullOrigin(names: readonly string[], openFunction: (name: string) => Uint8Array, fullOrigin: string): FileSource {
    return new FileSource(names, openFunction, fullOrigin);
  }

  private constructor(names: readonly string[], openFunction: (name: string) => Uint8Array, fullOrigin: string) {
    this.Names = names; // Could create a ReadOnlyCollection if we ever wanted to make this public
    this.Origin = GetFileName(fullOrigin);
    this._openFunction = openFunction;
  }

  /**
   * Returns the contents of the named file.
   *
   * noda-js: returns the file's bytes rather than a Stream over them.
   */
  Open(name: string): Uint8Array {
    return this._openFunction(name);
  }

  Contains(name: string): boolean {
    return this.Names.indexOf(name) !== -1;
  }

  // Not ported: FromArchive(Stream, string) (see TzdbCompiler/Archive.ts)
  // Not ported: FromDirectory(string) (no file system access)
}
