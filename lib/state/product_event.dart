import '../domain/product.dart';

sealed class ProductEvent {
  const ProductEvent();
}

final class ProductStarted extends ProductEvent {
  const ProductStarted();
}

final class ProductSaved extends ProductEvent {
  const ProductSaved({
    this.id,
    required this.name,
    required this.category,
    required this.salePrice,
    required this.unitCost,
    required this.stockQuantity,
    required this.minStockQuantity,
    this.active = true,
  });

  final String? id;
  final String name;
  final String category;
  final double salePrice;
  final double unitCost;
  final int stockQuantity;
  final int minStockQuantity;
  final bool active;
}

final class ProductActiveChanged extends ProductEvent {
  const ProductActiveChanged(this.product, this.active);

  final Product product;
  final bool active;
}
