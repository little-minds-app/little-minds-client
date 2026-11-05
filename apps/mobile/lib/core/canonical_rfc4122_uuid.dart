/// Strict RFC 4122 UUID string check for wire-safe identifiers.
///
/// Accepts versions **4**, **5** (parent-scoped device row ids), and **7**.
/// Rejects other versions, wrong variant nibble, and non-canonical shapes.
abstract final class CanonicalRfc4122Uuid {
  static final pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[457][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isValid(String value) => pattern.hasMatch(value);
}
