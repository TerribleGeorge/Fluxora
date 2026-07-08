import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/billing_repository.dart';

class GooglePlayBillingRepository implements BillingRepository {
  GooglePlayBillingRepository({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;

  @override
  Future<bool> isAvailable() => _inAppPurchase.isAvailable();

  @override
  Future<List<BillingProduct>> loadProducts() async {
    final available = await isAvailable();
    if (!available) return const [];

    final response = await _inAppPurchase.queryProductDetails({
      FluxoraBillingCatalog.founderProductId,
    });

    if (response.error != null) {
      throw BillingUnavailableException(
        'Não foi possível carregar os planos da Google Play.',
      );
    }

    return response.productDetails
        .map(
          (product) => BillingProduct(
            productId: product.id,
            title: product.title,
            description: product.description,
            price: product.price,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> buy(String productId) async {
    final response = await _inAppPurchase.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      throw const BillingUnavailableException(
        'Plano indisponível na Google Play neste momento.',
      );
    }

    final purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
    );
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }
}

class UnavailableBillingRepository implements BillingRepository {
  const UnavailableBillingRepository();

  @override
  Future<void> buy(String productId) async {
    throw const BillingUnavailableException(
      'A contratação será liberada após a revisão da Google Play.',
    );
  }

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<BillingProduct>> loadProducts() async => const [];
}
