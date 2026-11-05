// noda-js: String.prototype.padStart / padEnd (ES2017), for the ES2015 runtime baseline.
// Leaf module: imports nothing.

function Padding(text: string, length: number, fill: string): string {
  const count = length - text.length;
  if (count <= 0 || fill.length === 0) {
    return "";
  }
  const repeated = fill.repeat(Math.ceil(count / fill.length));
  return repeated.substring(0, count);
}

/**
 * `text.padStart(length, fill)`: pads the start of text with fill (repeated as needed) to the given length.
 * @internal
 */
export function PadStart(text: string, length: number, fill: string = " "): string {
  return Padding(text, length, fill) + text;
}

/**
 * `text.padEnd(length, fill)`: pads the end of text with fill (repeated as needed) to the given length.
 * @internal
 */
export function PadEnd(text: string, length: number, fill: string = " "): string {
  return text + Padding(text, length, fill);
}
