/// Commande boutique persistée (serveur + local). Paiement démo uniquement.
class MarketplaceOrder {
  const MarketplaceOrder({
    required this.productId,
    required this.productName,
    required this.amount,
    this.id,
    this.currency = 'XAF',
    this.status = 'recorded',
    this.message,
  });

  final String? id;
  final String productId;
  final String productName;
  final int amount;
  final String currency;
  final String status;
  final String? message;

  bool get isRecorded => status == 'recorded' || status == 'active';

  factory MarketplaceOrder.fromJson(Map<String, dynamic> json) {
    return MarketplaceOrder(
      id: json['id']?.toString(),
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'XAF',
      status: json['status'] as String? ?? 'recorded',
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'product_id': productId,
        'product_name': productName,
        'amount': amount,
        'currency': currency,
        'status': status,
        if (message != null) 'message': message,
      };
}
