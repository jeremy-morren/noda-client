// node-longjs's Utility/Long.ts (see vitest.config.ts): always long.js.
import LongJs from "long";

const Long: typeof LongJs = LongJs;
type Long = LongJs;

export default Long;
