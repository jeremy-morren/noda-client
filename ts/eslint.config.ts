// Keeps src/ to ES2015 built-ins (tsc lowers syntax, not built-ins) and checks that {@link}s resolve.
import esX from "eslint-plugin-es-x";
import tseslint from "typescript-eslint";
import type { Linter } from "eslint";
import docLinks from "./eslint-rules/doc-links.ts";

// Syntax TypeScript lowers to ES2015.
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
// es-x also reports `Iterator<T>` type annotations.
rules["es-x/no-iterator"] = "off";

const config: Linter.Config[] = [
  { ignores: ["src/*/dist/**"] },
  {
    files: ["src/**/*.ts"],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
        jsDocParsingMode: "all",
      },
    },
    plugins: { "es-x": esX, noda: { rules: { "doc-links": docLinks } } },
    linterOptions: { reportUnusedDisableDirectives: "error" },
    rules: { ...rules, "noda/doc-links": "error" },
  },
  {
    // Only picked where the engine has BigInt.
    files: ["src/noda-js/Utility/LongBigInt.ts"],
    rules: { "es-x/no-bigint": "off" },
  },
];

export default config;
