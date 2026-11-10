// noda_dart: new code (from time_machine2's test support).
// Use of this source code is governed by the Apache License 2.0, as found in the LICENSE.txt file.

// Preloaded by dart_test.yaml: dart2wasm's Uri.base (used by package:stack_trace) asserts without
// globalThis.location on Node.js. Defined as dart2js's preamble does (configurable, so it still can).
import { pathToFileURL } from 'node:url';

if (globalThis.location === undefined) {
  Object.defineProperty(globalThis, 'location', {
    configurable: true,
    value: {
      get href() {
        return pathToFileURL(process.cwd()).href + '/';
      },
    },
  });
}
