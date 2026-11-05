// noda-js-zod: zod schemas for noda-js. `import NodaZ from "noda-js-zod"; NodaZ.Instant.parse("2024-01-31T12:00:00Z")`.
// NodaZ is the namespace of ./schemas.ts, so a bundler keeps only the schemas an app uses. See README.md.

import * as NodaZ from "./schemas.ts";

export default NodaZ;
export { NodaZ };
export type { CalendarSchema, DateIntervalJson, IntervalJson, ObjectSchema, TextSchema } from "./schemas.ts";
