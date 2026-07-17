import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/subscription.dart';
import '../domain/subscription_repository.dart';

class SupabaseSubscriptionRepository implements SubscriptionRepository {
  SupabaseSubscriptionRepository(this._client, this.businessId);
  final SupabaseClient _client;
  final String businessId;

  @override
  Future<BusinessSubscription> getSubscription() async {
    final row = await _client
        .from('business_subscriptions')
        .select()
        .eq('business_id', businessId)
        .single();
    return BusinessSubscription(
      businessId: row['business_id'] as String,
      plan: SubscriptionPlan.values.byName(row['plan'] as String),
      status: SubscriptionStatus.values.byName(row['status'] as String),
      trialEndsAt: DateTime.parse(row['trial_ends_at'] as String).toLocal(),
      currentPeriodEndsAt: DateTime.tryParse(
        row['current_period_ends_at'] as String? ?? '',
      )?.toLocal(),
    );
  }
}
