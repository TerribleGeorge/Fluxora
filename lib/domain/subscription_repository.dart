import 'subscription.dart';

abstract interface class SubscriptionRepository {
  Future<BusinessSubscription> getSubscription();
}
