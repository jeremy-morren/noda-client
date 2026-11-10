// noda-js: the `noda-js/tzdb/bundled` entry point: the bundled tzdb, decoded on first use.

import { DateTimeZoneCache, TzdbDateTimeZoneSource } from "../internal.ts";
import type { IDateTimeZoneProvider } from "../internal.ts";
import { nzdBase64 } from "../TimeZones/TzdbBundledData.generated.ts";

export * from "./tzdb.ts";
export { sha256 as bundledTzdbSha256, tzdbVersion as bundledTzdbVersion } from "../TimeZones/TzdbBundledData.generated.ts";

/** A proxy for the value `factory` creates on first access. */
function Lazy<T extends object>(factory: () => T): T {
  let value: T | undefined;
  const get = (): T => (value ??= factory());
  return new Proxy({} as T, {
    get(_target, property) {
      const target = get();
      const result: unknown = Reflect.get(target, property, target);
      return typeof result === "function" && property !== "constructor" ? (result as (...args: unknown[]) => unknown).bind(target) : result;
    },
    has(_target, property) {
      return Reflect.has(get(), property);
    },
    getPrototypeOf() {
      return Object.getPrototypeOf(get()) as object | null;
    },
  });
}

/** The bundled tzdb source (NodaTime's `TzdbDateTimeZoneSource.Default`). */
export const tzdbSource: TzdbDateTimeZoneSource = /*#__PURE__*/ Lazy(() => TzdbDateTimeZoneSource.FromBase64(nzdBase64));

/** The bundled tzdb provider (NodaTime's `DateTimeZoneProviders.Tzdb`). */
export const tzdb: IDateTimeZoneProvider = /*#__PURE__*/ Lazy(() => new DateTimeZoneCache(tzdbSource));
