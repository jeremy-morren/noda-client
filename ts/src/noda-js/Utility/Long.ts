// noda-js: new code. The 64-bit integer for exact C# longs: native BigInt where available, else long.js (same API).

import LongJs from "long";
import LongBigInt from "./LongBigInt.ts";

// eslint-disable-next-line es-x/no-bigint -- a feature check, not a use: LongBigInt is only chosen where BigInt exists.
const Long: typeof LongJs = typeof BigInt === "function" ? (LongBigInt as unknown as typeof LongJs) : LongJs;
type Long = LongJs;

export default Long;
