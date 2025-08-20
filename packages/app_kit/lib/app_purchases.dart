import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';

class AppPurchases {
  static final InAppPurchase _instance = InAppPurchase.instance;
  static bool _available = false;
  
  static Future<void> init() async {
    _available = await _instance.isAvailable();
  }
  
  static Future<List<ProductDetails>> getProducts(Set<String> productIds) async {
    if (!_available) return [];
    
    final ProductDetailsResponse response = 
        await _instance.queryProductDetails(productIds);
    return response.productDetails;
  }
  
  static Future<bool> purchaseProduct(ProductDetails product) async {
    if (!_available) return false;
    
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
    );
    
    try {
      final bool success = await _instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      return success;
    } catch (e) {
      return false;
    }
  }
  
  static Future<bool> restorePurchases() async {
    if (!_available) return false;
    
    try {
      await _instance.restorePurchases();
      return true;
    } catch (e) {
      return false;
    }
  }
}