import 'package:flutter_test/flutter_test.dart';

import 'package:daeddong/core/router/app_router.dart';

void main() {
  group('parseRouteSeq', () {
    test('returns parsed integer for valid sequence', () {
      expect(parseRouteSeq('123'), 123);
    });

    test('returns null for invalid sequence', () {
      expect(parseRouteSeq('abc'), isNull);
      expect(parseRouteSeq(null), isNull);
      expect(parseRouteSeq(''), isNull);
    });
  });
}
