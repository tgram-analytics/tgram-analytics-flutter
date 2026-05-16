// Unit tests for the runtime properties validator.
//
// The validator is the runtime safety net for the permissive
// Map<String, Object?> type used by EventProperties. Static analysis
// can't catch every bad value (Dart's dynamic dispatch allows Object
// literals through), so we surface developer mistakes synchronously
// from track() / identify() instead of letting the server respond
// with 422.
import 'package:test/test.dart';
import 'package:tgram_analytics/src/validate.dart';

void main() {
  group('validateProperties — accepts', () {
    test('empty map', () {
      expect(() => validateProperties({}, 'track'), returnsNormally);
    });

    test('scalar primitives (String, int, double, bool, null)', () {
      expect(
        () => validateProperties(
          {'s': 'x', 'i': 1, 'f': 1.5, 'b': true, 'z': null},
          'track',
        ),
        returnsNormally,
      );
    });

    test('list of strings', () {
      expect(
        () => validateProperties({
          'tags': ['a', 'b', 'c']
        }, 'track'),
        returnsNormally,
      );
    });

    test('list of numbers', () {
      expect(
        () => validateProperties({
          'scores': [1, 2, 3.5]
        }, 'track'),
        returnsNormally,
      );
    });

    test('list of bools', () {
      expect(
        () => validateProperties({
          'flags': [true, false]
        }, 'track'),
        returnsNormally,
      );
    });

    test('heterogeneous list of scalars', () {
      expect(
        () => validateProperties({
          'mixed': ['a', 1, true, null]
        }, 'track'),
        returnsNormally,
      );
    });

    test('empty list', () {
      expect(
        () => validateProperties({'empty': <Object?>[]}, 'track'),
        returnsNormally,
      );
    });
  });

  group('validateProperties — rejects', () {
    test('nested map value', () {
      expect(
        () => validateProperties({
          'nested': {'a': 1}
        }, 'track'),
        throwsA(predicate(
          (e) => e is ArgumentError && e.toString().contains('nested'),
        )),
      );
    });

    test('map inside list', () {
      expect(
        () => validateProperties({
          'tags': [{}]
        }, 'track'),
        throwsA(predicate(
          (e) => e is ArgumentError && e.toString().contains('tags'),
        )),
      );
    });

    test('list inside list', () {
      expect(
        () => validateProperties({
          'tags': [
            <int>[1, 2]
          ]
        }, 'track'),
        throwsA(predicate(
          (e) => e is ArgumentError && e.toString().contains('tags'),
        )),
      );
    });

    test('error message names the bad index', () {
      try {
        validateProperties({
          'tags': ['a', {}]
        }, 'track');
        fail('expected throw');
      } on ArgumentError catch (e) {
        expect(e.toString(), contains('1'));
      }
    });

    test('error message names the calling method', () {
      try {
        validateProperties({'x': DateTime(2024)}, 'identify');
        fail('expected throw');
      } on ArgumentError catch (e) {
        expect(e.toString(), contains('identify'));
      }
    });

    test('NaN is rejected (JSON-unsafe)', () {
      expect(
        () => validateProperties({'n': double.nan}, 'track'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Infinity is rejected', () {
      expect(
        () => validateProperties({'n': double.infinity}, 'track'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
