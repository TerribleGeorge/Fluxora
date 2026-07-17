import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/subscription.dart';
import '../domain/subscription_repository.dart';

class CachedSubscriptionRepository implements SubscriptionRepository {
  CachedSubscriptionRepository({
    required this.remote,
    required this.preferences,
    required this.businessId,
  });

  final SubscriptionRepository remote;
  final SharedPreferences preferences;
  final String businessId;
  String get _key => 'fluxora.subscription.$businessId.v1';

  @override
  Future<BusinessSubscription> getSubscription() async {
    try {
      final subscription = await remote.getSubscription();
      await preferences.setString(_key, jsonEncode(subscription.toJson()));
      return subscription;
    } on Exception {
      final raw = preferences.getString(_key);
      if (raw != null) {
        return BusinessSubscription.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
      rethrow;
    }
  }
}
