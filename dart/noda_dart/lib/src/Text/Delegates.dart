// Ported from NodaTime 6e024dde: src/NodaTime/Text/Delegates.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'ParseBucket.dart';
import 'Patterns/PatternCursor.dart';
import 'Patterns/SteppedPatternBuilder.dart';

// This file contains all the delegates declared within the NodaTime.Text namespace.
// It's simpler than either nesting them or giving them a file per delegate.

@internal
typedef CharacterHandler<TResult, TBucket extends ParseBucket<TResult>> = void Function(
    PatternCursor patternCursor, SteppedPatternBuilder<TResult, TBucket> patternBuilder);
