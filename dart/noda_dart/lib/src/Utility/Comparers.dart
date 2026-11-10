// noda_dart: new code. .NET's IComparer<T> and IEqualityComparer<T>.

/// .NET's `IComparer<T>`.
abstract interface class IComparer<T> {
  /// Compares [x] and [y]: negative if [x] is less, zero if equal, positive if greater.
  int Compare(T x, T y);
}

/// .NET's `IEqualityComparer<T>`.
abstract interface class IEqualityComparer<T> {
  /// Whether [x] and [y] are equal.
  bool Equals(T x, T y);

  /// A hash code for [obj], consistent with [Equals].
  int GetHashCode(T obj);
}
