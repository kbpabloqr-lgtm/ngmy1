// Model for payment proof submissions
class PaymentProof {
  final String id;
  final String username; // User who submitted
  final double investmentAmount;
  final double paidAmount;
  final String screenshotPath;
  final DateTime submittedAt;
  final String status; // 'pending', 'approved', 'rejected'
  final String scope; // 'growth' or 'global'
  final String? adminMessage;
  final String? userReply;
  final DateTime? respondedAt;

  PaymentProof({
    required this.id,
    required this.username,
    required this.investmentAmount,
    required this.paidAmount,
    required this.screenshotPath,
    required this.submittedAt,
    required this.status,
    this.scope = 'growth',
    this.adminMessage,
    this.userReply,
    this.respondedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'investmentAmount': investmentAmount,
      'paidAmount': paidAmount,
      'screenshotPath': screenshotPath,
      'submittedAt': submittedAt.toIso8601String(),
      'status': status,
      'scope': scope,
      'adminMessage': adminMessage,
      'userReply': userReply,
      'respondedAt': respondedAt?.toIso8601String(),
    };
  }

  factory PaymentProof.fromJson(Map<String, dynamic> json) {
    return PaymentProof(
      id: json['id'] as String,
      username:
          json['username'] as String? ?? 'NGMY User', // Fallback for old data
      investmentAmount: (json['investmentAmount'] as num).toDouble(),
      paidAmount: (json['paidAmount'] as num).toDouble(),
      screenshotPath: json['screenshotPath'] as String,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      status: json['status'] as String,
      scope: (json['scope'] as String?)?.toLowerCase() == 'global'
          ? 'global'
          : 'growth',
      adminMessage: json['adminMessage'] as String?,
      userReply: json['userReply'] as String?,
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'] as String)
          : null,
    );
  }
}
