import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

class SupabaseProductRepository implements ProductRepository {
  SupabaseProductRepository(this._client, this.businessId, this.businessType);

  final SupabaseClient _client;
  final String businessId;
  final BusinessType businessType;

  @override
  Future<List<ProductTemplate>> getTemplates() async {
    final rows = await _client
        .from('product_templates')
        .select()
        .eq('business_type', businessType.name)
        .eq('active', true)
        .order('name');
    return rows
        .map(
          (row) => ProductTemplate(
            id: row['id'] as String,
            businessType: BusinessType.values.byName(
              row['business_type'] as String,
            ),
            name: row['name'] as String,
            category: row['category'] as String? ?? 'Produtos',
            suggestedSalePrice:
                (row['suggested_sale_price'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<Product>> getProducts() async {
    final rows = await _client
        .from('products')
        .select()
        .eq('business_id', businessId)
        .order('name');
    return rows.map(_productFromRow).toList(growable: false);
  }

  @override
  Future<List<Product>> getSellableProducts() async {
    final rows = await _client
        .from('sellable_products')
        .select()
        .eq('business_id', businessId)
        .order('name');
    return rows.map(_sellableProductFromRow).toList(growable: false);
  }

  @override
  Future<void> saveProduct(Product product) async {
    await _client.rpc('save_product_with_stock_movement', params: {
      'target_product_id': product.id,
      'target_business_id': businessId,
      'target_business_type': businessType.name,
      'target_name': product.name,
      'target_category': product.category,
      'target_sale_price': product.salePrice,
      'target_unit_cost': product.unitCost,
      'target_stock_quantity': product.stockQuantity,
      'target_min_stock_quantity': product.minStockQuantity,
      'target_active': product.active,
    });
  }

  Product _productFromRow(Map<String, dynamic> row) => Product(
    id: row['id'] as String,
    businessId: row['business_id'] as String,
    businessType: BusinessType.values.byName(row['business_type'] as String),
    name: row['name'] as String,
    category: row['category'] as String? ?? 'Produtos',
    salePrice: (row['sale_price'] as num).toDouble(),
    unitCost: (row['unit_cost'] as num?)?.toDouble() ?? 0,
    stockQuantity: row['stock_quantity'] as int? ?? 0,
    minStockQuantity: row['min_stock_quantity'] as int? ?? 0,
    active: row['active'] as bool? ?? true,
    updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '')?.toLocal(),
  );

  Product _sellableProductFromRow(Map<String, dynamic> row) => Product(
    id: row['id'] as String,
    businessId: row['business_id'] as String,
    businessType: BusinessType.values.byName(row['business_type'] as String),
    name: row['name'] as String,
    category: row['category'] as String? ?? 'Produtos',
    salePrice: (row['sale_price'] as num).toDouble(),
    stockQuantity: row['stock_quantity'] as int? ?? 0,
    minStockQuantity: row['min_stock_quantity'] as int? ?? 0,
    active: row['active'] as bool? ?? true,
    updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '')?.toLocal(),
  );
}
