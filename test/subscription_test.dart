import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/subscription.dart';

void main() {
  test('período de teste futuro mantém acesso', () {
    final subscription = BusinessSubscription(
      businessId: 'business-1',
      plan: SubscriptionPlan.trial,
      status: SubscriptionStatus.trialing,
      trialEndsAt: DateTime.now().add(const Duration(days: 14)),
    );

    expect(subscription.hasAccess, isTrue);
    expect(subscription.trialDaysRemaining, greaterThanOrEqualTo(14));
  });

  test('teste expirado bloqueia acesso sem apagar dados', () {
    final subscription = BusinessSubscription(
      businessId: 'business-1',
      plan: SubscriptionPlan.trial,
      status: SubscriptionStatus.trialing,
      trialEndsAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    expect(subscription.hasAccess, isFalse);
    expect(subscription.trialDaysRemaining, 0);
  });

  test('assinatura ativa mantém acesso após o teste', () {
    final subscription = BusinessSubscription(
      businessId: 'business-1',
      plan: SubscriptionPlan.management,
      status: SubscriptionStatus.active,
      trialEndsAt: DateTime(2026),
    );

    expect(subscription.hasAccess, isTrue);
  });
}
