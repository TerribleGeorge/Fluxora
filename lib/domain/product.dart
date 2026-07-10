import 'account.dart';

class ProductTemplate {
  const ProductTemplate({
    required this.id,
    required this.businessType,
    required this.name,
    required this.category,
    required this.suggestedSalePrice,
  });

  final String id;
  final BusinessType businessType;
  final String name;
  final String category;
  final double suggestedSalePrice;
}

class Product {
  const Product({
    required this.id,
    required this.businessId,
    required this.businessType,
    required this.name,
    required this.category,
    required this.salePrice,
    this.unitCost = 0,
    this.stockQuantity = 0,
    this.minStockQuantity = 0,
    this.active = true,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final BusinessType businessType;
  final String name;
  final String category;
  final double salePrice;
  final double unitCost;
  final int stockQuantity;
  final int minStockQuantity;
  final bool active;
  final DateTime? updatedAt;

  bool get lowStock => stockQuantity <= minStockQuantity;

  Map<String, Object?> toJson() => {
    'id': id,
    'businessId': businessId,
    'businessType': businessType.name,
    'name': name,
    'category': category,
    'salePrice': salePrice,
    'unitCost': unitCost,
    'stockQuantity': stockQuantity,
    'minStockQuantity': minStockQuantity,
    'active': active,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    businessId: json['businessId'] as String,
    businessType: BusinessType.values.byName(json['businessType'] as String),
    name: json['name'] as String,
    category: json['category'] as String? ?? 'Produtos',
    salePrice: (json['salePrice'] as num).toDouble(),
    unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0,
    stockQuantity: json['stockQuantity'] as int? ?? 0,
    minStockQuantity: json['minStockQuantity'] as int? ?? 0,
    active: json['active'] as bool? ?? true,
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );
}

class CheckoutProductLine {
  const CheckoutProductLine({required this.productId, required this.quantity});

  final String productId;
  final int quantity;

  Map<String, Object> toJson() => {
    'productId': productId,
    'quantity': quantity,
  };
}

class ProductCatalog {
  const ProductCatalog._();

  static bool productMatchesBusiness({
    required BusinessType businessType,
    required BusinessType productType,
  }) {
    return productType == businessType;
  }
}
