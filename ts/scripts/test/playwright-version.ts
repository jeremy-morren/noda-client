// The installed Playwright's version, as the step output "version" (the browsers' cache key).
// Usage: node ts/scripts/test/playwright-version.ts
import { program, readJson, setOutput } from "noda-scripts/ci";

program.description("Sets the step output \"version\" to the installed Playwright's version.").parse();
setOutput("version", readJson<{ version: string }>("ts/node_modules/playwright/package.json").version);
