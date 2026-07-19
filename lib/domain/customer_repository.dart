import 'customer.dart';

abstract interface class CustomerRepository {
  Future<LoyaltySettings> getLoyaltySettings();
  Future<void> saveLoyaltySettings(LoyaltySettings settings);
  Future<List<Customer>> getCustomers();
  Future<void> saveCustomer(Customer customer);
  Future<Customer> updateCustomerLoyaltyOverride({
    required String customerId,
    required CustomerLoyaltyTier? tier,
    required String reason,
  });
  Future<BookingPriceQuote> resolveBookingPrice({
    required String serviceId,
    required String name,
    required String email,
    required String phone,
  });
  Future<void> linkAppointmentToCustomer({
    required String appointmentId,
    required String customerId,
  });
  Future<List<Customer>> searchLinkableCustomers({
    required String appointmentId,
    required String query,
  });
}
