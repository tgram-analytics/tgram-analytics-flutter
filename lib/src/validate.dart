// Runtime validator for [EventProperties].
//
// The static EventProperties type is intentionally permissive
// (Map<String, Object?>) so the SDK feels ergonomic to call. This
// module is the runtime safety net that fails loudly when an unsupported
// shape is about to be sent to the server — so developer mistakes
// surface in tests rather than as silent 422s.
//
// Allowed value shapes:
// * scalar:        String, int, double, bool, or null
// * scalar list:   List of the above scalars
//
// Anything else (nested Map, nested List, DateTime, custom objects,
// double.nan, double.infinity) throws ArgumentError with a message that
// names the bad key, the index in the list when relevant, and the
// calling method.
import 'types.dart';

bool _isScalar(Object? v) {
  if (v == null) return true;
  if (v is String || v is bool) return true;
  if (v is num) {
    // JSON.encode would refuse NaN / Infinity (or worse, silently encode
    // them with non-spec-compliant encoders). Reject up front.
    return v.isFinite;
  }
  return false;
}

String _describe(Object? v) {
  if (v == null) return 'null';
  if (v is num && !v.isFinite) return v.isNaN ? 'NaN' : 'Infinity';
  if (v is List) return 'List';
  if (v is Map) return 'Map';
  return v.runtimeType.toString();
}

/// Validate [props] before it is sent or merged into the session.
///
/// [method] is the calling method name (`'track'`, `'pageview'`, or
/// `'identify'`) — it is included in the error message to make debugging
/// painless.
///
/// Throws [ArgumentError] when any value (or list element) is not a
/// JSON-safe scalar. Mutates nothing.
void validateProperties(EventProperties props, String method) {
  for (final entry in props.entries) {
    final key = entry.key;
    final value = entry.value;

    if (_isScalar(value)) continue;

    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        final item = value[i];
        if (_isScalar(item)) continue;
        throw ArgumentError(
          "tgram_analytics.$method(): properties['$key'][$i] must be a "
          'scalar (String, int, double, bool, null); '
          'got ${_describe(item)}. Lists may only contain scalar '
          'primitives — Maps, nested Lists, NaN, and Infinity are not '
          'allowed.',
        );
      }
      continue;
    }

    throw ArgumentError(
      "tgram_analytics.$method(): properties['$key'] must be a scalar "
      '(String, int, double, bool, null) or a List of those scalars; '
      'got ${_describe(value)}.',
    );
  }
}
