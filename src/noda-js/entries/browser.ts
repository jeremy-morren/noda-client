// noda-js: the `noda-js/browser` entry point: time zones from the host's Intl implementation,
// as the equivalent of NodaTime's BclDateTimeZoneSource and DateTimeZoneProviders.Bcl.

import { BrowserDateTimeZoneSource, DateTimeZoneCache } from "../internal.ts";
import type { IDateTimeZoneProvider } from "../internal.ts";

export { BrowserDateTimeZone, BrowserDateTimeZoneSource } from "../internal.ts";

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
 * A time zone provider for the host's time zones (the equivalent of NodaTime's `DateTimeZoneProviders.Bcl`):
 * a {@link DateTimeZoneCache} over a {@link BrowserDateTimeZoneSource}, created on first use.
 */
export const browser: IDateTimeZoneProvider = /*#__PURE__*/ Lazy(() => new DateTimeZoneCache(new BrowserDateTimeZoneSource()));
