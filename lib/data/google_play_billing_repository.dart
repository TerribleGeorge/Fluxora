import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/billing_repository.dart';

class GooglePlayBillingRepository implements BillingRepository {
  GooglePlayBillingRepository({
    InAppPurchase? inAppPurchase,
    required SupabaseClient client,
    required SharedPreferences preferences,
  }) : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance,
       _client = client,
       _preferences = preferences {
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (_) {
        // Access is only granted after server-side verification.
      },
    );
  }

  final InAppPurchase _inAppPurchase;
  final SupabaseClient _client;
  final SharedPreferences _preferences;
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;
  final Map<String, String> _pendingBusinessIdsByProduct = {};
  static const _pendingBusinessPrefix =
      'fluxora.billing.pendingBusinessIdByProduct.';

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
  Future<void> buy(String productId, {required String businessId}) async {
    final response = await _inAppPurchase.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      throw const BillingUnavailableException(
        'Plano indisponível na Google Play neste momento.',
      );
    }

    _pendingBusinessIdsByProduct[productId] = businessId;
    await _preferences.setString(_pendingBusinessKey(productId), businessId);
    final purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
      applicationUserName: businessId,
    );
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final verified = await _verifyPurchase(purchase);
        if (verified && purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData;
    final businessId =
        _pendingBusinessIdsByProduct[purchase.productID] ??
        _preferences.getString(_pendingBusinessKey(purchase.productID));
    if (token.isEmpty) return false;
    if (businessId == null || businessId.isEmpty) return false;

    try {
      await _client.functions.invoke(
        'verify-play-purchase',
        body: {
          'businessId': businessId,
          'productId': purchase.productID,
          'purchaseToken': token,
        },
      );
      _pendingBusinessIdsByProduct.remove(purchase.productID);
      await _preferences.remove(_pendingBusinessKey(purchase.productID));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() => _purchaseSubscription.cancel();

  String _pendingBusinessKey(String productId) =>
      '$_pendingBusinessPrefix$productId';
}

class UnavailableBillingRepository implements BillingRepository {
  const UnavailableBillingRepository();

  @override
  Future<void> buy(String productId, {required String businessId}) async {
    throw const BillingUnavailableException(
      'A contratação será liberada após a revisão da Google Play.',
    );
  }

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<BillingProduct>> loadProducts() async => const [];
}
