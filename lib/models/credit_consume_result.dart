class CreditConsumeResult {
  final bool ok;
  final String message;
  final int? balance;

  const CreditConsumeResult({
    required this.ok,
    required this.message,
    this.balance,
  });

  bool get isOk => ok || message == 'ok' || message == 'ok_duplicate';
  bool get isOkDuplicate => message == 'ok_duplicate';
  bool get isNotEnoughCredits => message == 'not_enough_credits';
  bool get isProRequired => message == 'pro_required';
}
