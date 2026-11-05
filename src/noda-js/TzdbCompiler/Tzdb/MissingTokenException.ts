// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Tzdb/MissingTokenException.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { NodaError } from "../../internal.ts";

/**
 * Thrown when an expected token is missing from the token stream.
 */
export class MissingTokenException extends NodaError<"MissingTokenException"> {

  /**
   * Initializes a new instance of the {@link MissingTokenException} class.
   * (Merges NodaTime's two constructors.)
   * @param name The name.
   * @param message The message.
   */
  constructor(name: string, message: string = `Missing token ${name}`) {
    super("MissingTokenException", message);
    this.Name = name;
  }

  /**
   * Gets or sets the name of the missing token
   */
  readonly Name: string;
}
