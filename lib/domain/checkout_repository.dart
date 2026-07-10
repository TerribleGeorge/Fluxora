import 'product.dart';
import 'sale.dart';

abstract interface class CheckoutRepository {
  Future<Sale> completeAppointmentCheckout({
    required String appointmentId,
    required PaymentMethod paymentMethod,
    double paymentFeePercent = 0,
    List<CheckoutProductLine> products = const [],
    String notes = '',
  });
}
