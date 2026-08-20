import 'package:artsee_app/services/tencent_captcha_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts a normal Tencent Captcha proof', () {
    const proof = TencentCaptchaProof(
      ticket: 'normal-ticket',
      randstr: '@random',
    );

    expect(proof.isValid, isTrue);
  });

  test('rejects a disaster-recovery ticket on the client', () {
    const proof = TencentCaptchaProof(
      ticket: 'trerror_1001_199999164_1786320000',
      randstr: '@fallback',
    );

    expect(proof.isValid, isFalse);
  });
}
