import 'package:flutter_hbb/common/lantern_password.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permanent passwords accept any nonempty text without complexity limits',
      () {
    for (final password in ['1', 'a', '1234', '中文🔑', ' a ', ' ', 'x' * 300]) {
      expect(validatePermanentPassword(password, password), isNull);
    }
  });

  test('permanent passwords require nonempty text and exact confirmation', () {
    expect(validatePermanentPassword('', ''), 'Password cannot be empty');
    expect(validatePermanentPassword(' a ', 'a'),
        'The confirmation is not identical.');
  });
}
