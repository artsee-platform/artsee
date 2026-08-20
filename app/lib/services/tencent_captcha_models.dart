class TencentCaptchaProof {
  const TencentCaptchaProof({
    required this.ticket,
    required this.randstr,
  });

  final String ticket;
  final String randstr;

  bool get isValid =>
      ticket.isNotEmpty &&
      ticket.length <= 2048 &&
      !ticket.startsWith('trerror_') &&
      randstr.isNotEmpty &&
      randstr.length <= 256;
}

class TencentCaptchaClientException implements Exception {
  const TencentCaptchaClientException(this.message);

  final String message;

  @override
  String toString() => message;
}
