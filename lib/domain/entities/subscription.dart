/// Abonnement annuel CityCare, montant en francs CFA (XAF).
class CareSubscription {
  const CareSubscription({
    required this.plan,
    required this.currency,
    required this.amount,
    required this.status,
    this.expiresAt,
    this.message,
  });

  /// Offre annuelle unique pour le Cameroun.
  static const annualPlan = 'annual_xaf';
  static const annualAmount = 12000;
  static const annualCurrency = 'XAF';

  final String plan;
  final String currency;
  final int amount;
  final String status;
  final DateTime? expiresAt;
  final String? message;

  bool get isRecorded => status == 'recorded' || status == 'active';

  bool get isActive => status == 'active' || status == 'recorded';

  String get priceLabel => '$amount $currency / an';

  factory CareSubscription.none() {
    return const CareSubscription(
      plan: annualPlan,
      currency: annualCurrency,
      amount: annualAmount,
      status: 'none',
      message:
          'Aucun paiement n’est débité ici. Mobile Money arrivera ensuite.',
    );
  }

  factory CareSubscription.fromJson(Map<String, dynamic> json) {
    return CareSubscription(
      plan: json['plan'] as String? ?? annualPlan,
      currency: json['currency'] as String? ?? annualCurrency,
      amount: json['amount'] as int? ?? annualAmount,
      status: json['status'] as String? ?? 'none',
      expiresAt: json['expires_at'] == null ? null : DateTime.tryParse(json['expires_at'] as String),
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'plan': plan,
        'currency': currency,
        'amount': amount,
        'status': status,
        if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
        if (message != null) 'message': message,
      };
}
