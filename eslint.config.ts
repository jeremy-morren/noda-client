// ESLint does two things. 1. It keeps src/ within ES2015 (plus the Intl APIs the build's lib allows), so
// noda-js runs on ES2015 hosts without polyfills. TypeScript (target ES2015) already lowers newer *syntax*;
// it doesn't polyfill newer *built-ins* (Array.prototype.includes, Object.entries, String.prototype.padStart,
// ...), which is what these rules catch. They use type information, so e.g. a string's .includes (ES2015) isn't
// mistaken for an array's (ES2016).
// 2. It checks that every {@link X} in a doc comment resolves (eslint-rules/doc-links.ts).
import esX from "eslint-plugin-es-x";
import tseslint from "typescript-eslint";
import type { Linter } from "eslint";
import docLinks from "./eslint-rules/doc-links.ts";

// es-x syntax rules for syntax TypeScript lowers to ES2015, so using it in src/ is fine.
const loweredByTypeScript = [
  "no-exponential-operators", // ES2016
  "no-async-functions", // ES2017
  "no-trailing-function-commas", // ES2017
  "no-rest-spread-properties", // ES2018
  "no-async-iteration", // ES2018
  "no-optional-catch-binding", // ES2019
  "no-optional-chaining", // ES2020
  "no-nullish-coalescing-operators", // ES2020
  "no-logical-assignment-operators", // ES2021
  "no-numeric-separators", // ES2021
  "no-class-fields", // ES2022
  "no-class-instance-fields", // ES2022
  "no-class-static-fields", // ES2022
  "no-class-private-fields", // ES2022
  "no-class-private-methods", // ES2022
  "no-class-static-block", // ES2022
  "no-private-in", // ES2022
];

const rules: Partial<Linter.RulesRecord> = {
  ...esX.configs["flat/restrict-to-es2015"].rules,
  ...esX.configs["flat/restrict-to-es2015-intl-api"].rules,
};
for (const rule of loweredByTypeScript) {
  if (`es-x/${rule}` in rules) {
    rules[`es-x/${rule}`] = "off";
  }
}
// The ES2025 Iterator global: es-x also reports TypeScript's `Iterator<T>` type annotations, which aren't runtime
// uses. (Iterator helper *methods*, e.g. iterator.map, are still caught by their own rules.)
rules["es-x/no-iterator"] = "off";

const config: Linter.Config[] = [
  // Build output (src/<package>/dist) isn't linted.
  { ignores: ["src/*/dist/**"] },
  {
    files: ["src/**/*.ts"],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
        // Doc comments must be parsed for the doc-links rule.
        jsDocParsingMode: "all",
      },
    },
    plugins: { "es-x": esX, noda: { rules: { "doc-links": docLinks } } },
    linterOptions: { reportUnusedDisableDirectives: "error" },
    rules: { ...rules, "noda/doc-links": "error" },
  },
];

export default config;
