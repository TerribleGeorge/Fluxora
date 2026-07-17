import '../domain/customer.dart';

enum CustomerStatus { initial, loading, success, failure }

class CustomerState {
  const CustomerState({
    this.status = CustomerStatus.initial,
    this.loyaltySettings,
    this.customers = const [],
    this.associationCandidates = const [],
    this.associationQuery = '',
    this.associationSearchLoading = false,
    this.message,
  });

  final CustomerStatus status;
  final LoyaltySettings? loyaltySettings;
  final List<Customer> customers;
  final List<Customer> associationCandidates;
  final String associationQuery;
  final bool associationSearchLoading;
  final String? message;

  bool get loading => status == CustomerStatus.loading;

  CustomerState copyWith({
    CustomerStatus? status,
    LoyaltySettings? loyaltySettings,
    List<Customer>? customers,
    List<Customer>? associationCandidates,
    String? associationQuery,
    bool? associationSearchLoading,
    String? message,
  }) => CustomerState(
    status: status ?? this.status,
    loyaltySettings: loyaltySettings ?? this.loyaltySettings,
    customers: customers ?? this.customers,
    associationCandidates: associationCandidates ?? this.associationCandidates,
    associationQuery: associationQuery ?? this.associationQuery,
    associationSearchLoading:
        associationSearchLoading ?? this.associationSearchLoading,
    message: message,
  );
}
