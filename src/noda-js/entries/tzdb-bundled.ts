// noda-js: the `noda-js/tzdb/bundled` entry point: the tzdb data bundled with this package,
// as the equivalent of NodaTime's TzdbDateTimeZoneSource.Default and DateTimeZoneProviders.Tzdb.
// Nothing is decoded until first use.

import { DateTimeZoneCache, TzdbDateTimeZoneSource } from "../internal.ts";
import type { IDateTimeZoneProvider } from "../internal.ts";
import { nzdBase64 } from "../TimeZones/TzdbBundledData.generated.ts";

export * from "./tzdb.ts";
export { sha256 as bundledTzdbSha256, tzdbVersion as bundledTzdbVersion } from "../TimeZones/TzdbBundledData.generated.ts";

/**
 * Returns an object that forwards every property access to the value created by `factory`, which is called
 * on first access. `instanceof` checks see the real object's prototype.
 */
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

/**
 * The {@link TzdbDateTimeZoneSource} initialised from the tzdb data bundled with noda-js
 * (the equivalent of NodaTime's `TzdbDateTimeZoneSource.Default`). The data is decoded on first use.
 */
export const tzdbSource: TzdbDateTimeZoneSource = /*#__PURE__*/ Lazy(() => TzdbDateTimeZoneSource.FromBase64(nzdBase64));

/**
 * A time zone provider for the tzdb data bundled with noda-js (the equivalent of NodaTime's
 * `DateTimeZoneProviders.Tzdb`): a {@link DateTimeZoneCache} over {@link tzdbSource}, created on first use.
 */
export const tzdb: IDateTimeZoneProvider = /*#__PURE__*/ Lazy(() => new DateTimeZoneCache(tzdbSource));
