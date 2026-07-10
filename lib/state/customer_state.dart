import '../domain/customer.dart';

enum CustomerStatus { initial, loading, success, failure }

class CustomerState {
  const CustomerState({
    this.status = CustomerStatus.initial,
    this.loyaltySettings,
    this.customers = const [],
    this.message,
  });

  final CustomerStatus status;
  final LoyaltySettings? loyaltySettings;
  final List<Customer> customers;
  final String? message;

  bool get loading => status == CustomerStatus.loading;

  CustomerState copyWith({
    CustomerStatus? status,
    LoyaltySettings? loyaltySettings,
    List<Customer>? customers,
    String? message,
  }) => CustomerState(
    status: status ?? this.status,
    loyaltySettings: loyaltySettings ?? this.loyaltySettings,
    customers: customers ?? this.customers,
    message: message,
  );
}
