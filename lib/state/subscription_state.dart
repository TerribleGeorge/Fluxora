import '../domain/subscription.dart';

enum SubscriptionLoadStatus { initial, loading, ready, failure }

class SubscriptionState {
  const SubscriptionState({
    this.status = SubscriptionLoadStatus.initial,
    this.subscription,
    this.message,
  });
  final SubscriptionLoadStatus status;
  final BusinessSubscription? subscription;
  final String? message;
}
