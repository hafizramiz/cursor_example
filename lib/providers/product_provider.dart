import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> searchProducts(String query) async {
    _searchQuery = query;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _apiService.searchProducts(query);
    } catch (error) {
      _error = error.toString();
      _products = [];
      debugPrint('Error searching products: $error');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> retryLastSearch() async {
    if (_searchQuery.isNotEmpty) {
      await searchProducts(_searchQuery);
    }
  }
}
