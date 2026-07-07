enum SubscriptionPlan { trial, essential, management, pro }

enum SubscriptionStatus { trialing, active, pastDue, cancelled }

class BusinessSubscription {
  const BusinessSubscription({
    required this.businessId,
    required this.plan,
    required this.status,
    required this.trialEndsAt,
    this.currentPeriodEndsAt,
  });

  final String businessId;
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final DateTime trialEndsAt;
  final DateTime? currentPeriodEndsAt;

  int get trialDaysRemaining {
    final difference = trialEndsAt.difference(DateTime.now()).inDays;
    return difference < 0 ? 0 : difference + 1;
  }

  bool get hasAccess =>
      status == SubscriptionStatus.active ||
      (status == SubscriptionStatus.trialing &&
          DateTime.now().isBefore(trialEndsAt));

  Map<String, Object?> toJson() => {
    'businessId': businessId,
    'plan': plan.name,
    'status': status.name,
    'trialEndsAt': trialEndsAt.toIso8601String(),
    'currentPeriodEndsAt': currentPeriodEndsAt?.toIso8601String(),
  };

  factory BusinessSubscription.fromJson(Map<String, dynamic> json) =>
      BusinessSubscription(
        businessId: json['businessId'] as String,
        plan: SubscriptionPlan.values.byName(json['plan'] as String),
        status: SubscriptionStatus.values.byName(json['status'] as String),
        trialEndsAt: DateTime.parse(json['trialEndsAt'] as String),
        currentPeriodEndsAt: DateTime.tryParse(
          json['currentPeriodEndsAt'] as String? ?? '',
        ),
      );
}
