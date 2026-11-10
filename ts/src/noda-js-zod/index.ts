// noda-js-zod: new code. Zod schemas for noda-js (see README.md); NodaZ is a namespace, so bundlers tree-shake it.

import * as NodaZ from "./schemas.ts";

export default NodaZ;
export { NodaZ };
export type { CalendarSchema, DateIntervalJson, IntervalJson, ObjectSchema, TextSchema } from "./schemas.ts";
