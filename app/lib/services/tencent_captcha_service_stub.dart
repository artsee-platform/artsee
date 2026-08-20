import 'package:flutter/material.dart';

import 'tencent_captcha_models.dart';

class TencentCaptchaService {
  TencentCaptchaService._();

  static Future<TencentCaptchaProof?> verify(BuildContext context) {
    throw const TencentCaptchaClientException('当前平台暂不支持腾讯安全验证');
  }
}
