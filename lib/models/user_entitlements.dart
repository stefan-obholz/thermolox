class UserEntitlements {
  final bool proLifetime;
  final int creditsBalance;

  const UserEntitlements({
    required this.proLifetime,
    required this.creditsBalance,
  });

  UserEntitlements copyWith({
    bool? proLifetime,
    int? creditsBalance,
  }) {
    return UserEntitlements(
      proLifetime: proLifetime ?? this.proLifetime,
      creditsBalance: creditsBalance ?? this.creditsBalance,
    );
  }
}
