import 'package:http/http.dart' as http;
import 'package:beautiful_soup_dart/beautiful_soup.dart';
import 'dart:convert';
import '../models/product.dart';
import '../models/market_source.dart';
import 'dart:math';

class ApiService {
  // Migros API
  static const String migrosBaseUrl =
      'https://www.migros.com.tr/rest/search/screens/v2';

  // A101 API (Note: A101 might require different authentication)
  static const String a101BaseUrl = 'https://www.a101.com.tr/api/v1';

  // BIM doesn't have a public API, we might need web scraping
  static const String bimBaseUrl = 'https://www.bim.com.tr';

  Future<List<Product>> searchProducts(String query) async {
    try {
      // Fetch from BİM using web scraping
      final bimProducts = await _searchBim(query);

      // For now, we'll only return BİM products
      // Later we can add Migros and A101 when their APIs are implemented
      return bimProducts;
    } catch (e) {
      print('Error in searchProducts: $e');
      return [];
    }
  }

  Future<List<Product>> _searchMigros(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$migrosBaseUrl/search?q=${Uri.encodeComponent(query)}'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0', // Some APIs require this
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Product> products = [];

        // Parse Migros-specific response
        if (data['data'] != null && data['data']['products'] != null) {
          for (var item in data['data']['products']) {
            products.add(Product(
              name: item['name'],
              imageUrl: item['images']?[0] ?? '',
              prices: {'Migros': double.parse(item['price'].toString())},
              unit: item['unit'] ?? _extractUnit(item['name']),
            ));
          }
        }

        return products;
      } else {
        throw Exception('Migros API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching from Migros: $e');
      return [];
    }
  }

  Future<List<Product>> _searchA101(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$a101BaseUrl/products/search?q=${Uri.encodeComponent(query)}'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Product> products = [];

        // Parse A101-specific response
        if (data['products'] != null) {
          for (var item in data['products']) {
            products.add(Product(
              name: item['name'],
              imageUrl: item['image'] ?? '',
              prices: {'A101': double.parse(item['price'].toString())},
              unit: item['unit'] ?? _extractUnit(item['name']),
            ));
          }
        }

        return products;
      } else {
        throw Exception('A101 API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching from A101: $e');
      return [];
    }
  }

  Future<List<Product>> _searchBim(String query) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final response = await http.get(
        Uri.parse(
            'https://www.bim.com.tr/arama?q=${Uri.encodeComponent(query)}'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'keep-alive',
          'Referer': 'https://www.bim.com.tr/',
        },
      );

      print('BİM response status: ${response.statusCode}');
      print('BİM response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final List<Product> products = [];
        final soup = BeautifulSoup(response.body);

        // Print full HTML for debugging
        print('Full HTML: ${response.body}');

        // Try different selectors for product containers
        final productElements =
            soup.findAll('div', class_: 'product-wrapper') ??
                soup.findAll('div', class_: 'product-item-wrapper') ??
                soup.findAll('div', class_: 'product-list-wrapper');

        print('Found ${productElements.length} product elements');

        for (var element in productElements) {
          try {
            // Try different selectors for product details
            final nameElement = element.find('h2') ??
                element.find('div', class_: 'title') ??
                element.find('div', class_: 'description');

            final priceElement = element.find('div', class_: 'price') ??
                element.find('span', class_: 'amount');

            final imageElement = element.find('img');

            if (nameElement != null) {
              print('Found name element: ${nameElement.text}');
            }
            if (priceElement != null) {
              print('Found price element: ${priceElement.text}');
            }

            if (nameElement != null && priceElement != null) {
              final name = nameElement.text.trim();
              final priceText = priceElement.text
                  .replaceAll(RegExp(r'[^\d,.]'), '')
                  .replaceAll(',', '.')
                  .trim();

              final price = double.tryParse(priceText) ?? 0.0;
              String? imageUrl = imageElement?.attributes['src'] ??
                  imageElement?.attributes['data-src'];

              if (price > 0 && name.isNotEmpty) {
                products.add(Product(
                  name: name,
                  imageUrl: _normalizeImageUrl(imageUrl ?? '', 'bim.com.tr'),
                  prices: {'BİM': price},
                  unit: _extractUnit(name),
                ));
                print('Successfully added product: $name at price: $price');
              }
            }
          } catch (e) {
            print('Error parsing product element: $e');
            continue;
          }
        }

        return products;
      } else {
        print('Error response body: ${response.body}');
        throw Exception('Failed to load BİM products: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in _searchBim: $e');
      return [];
    }
  }

  String _cleanProductName(String name) {
    // Remove extra whitespace and normalize Turkish characters
    name = name
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');

    return name;
  }

  String _extractPrice(String priceText) {
    // Remove currency symbol and normalize decimal separator
    return priceText
        .replaceAll(RegExp(r'[^\d,.]'), '')
        .replaceAll(',', '.')
        .trim();
  }

  String _normalizeImageUrl(String url, String domain) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    return 'https://$domain$url';
  }

  String _getRandomUserAgent() {
    final userAgents = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.59',
    ];
    return userAgents[
        DateTime.now().millisecondsSinceEpoch % userAgents.length];
  }

  // Enhanced rate limiting
  DateTime? _lastBimRequest;
  static const _minRequestInterval = Duration(seconds: 3);
  int _consecutiveFailures = 0;
  static const _maxRetries = 3;

  Future<void> _respectRateLimit() async {
    if (_lastBimRequest != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastBimRequest!);
      final waitTime = _minRequestInterval * (_consecutiveFailures + 1);

      if (timeSinceLastRequest < waitTime) {
        await Future.delayed(waitTime - timeSinceLastRequest);
      }
    }
    _lastBimRequest = DateTime.now();
  }

  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    for (int i = 0; i < _maxRetries; i++) {
      try {
        final result = await operation();
        _consecutiveFailures = 0;
        return result;
      } catch (e) {
        _consecutiveFailures++;
        if (i == _maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: pow(2, i).toInt()));
      }
    }
    throw Exception('Max retries exceeded');
  }

  // Enhance the normalize function for better product matching
  String _normalizeProductName(String name) {
    name = name.toLowerCase();
    // Remove common Turkish characters
    name = name
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');

    // Remove common variations and units
    name = name
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(
            RegExp(r'\d+\s*(ml|gr|g|kg|l|lt|gram|kilogram|litre|mililetre)'),
            '')
        .replaceAll(RegExp(r'[\(\)]'), '')
        .trim();

    // Remove common brand names for better matching
    final commonBrands = [
      'bim',
      'a101',
      'migros',
      'sok',
      'torku',
      'ülker',
      'eti',
      'pinar',
      'sek',
      'dano',
      'mis',
      'içim',
      'sütaş'
    ];

    for (var brand in commonBrands) {
      name = name.replaceAll(brand, '');
    }

    return name.trim();
  }

  // Enhance unit extraction
  String _extractUnit(String name) {
    final unitRegex = RegExp(
      r'(\d+(?:[.,]\d+)?\s*(?:ml|gr|g|kg|l|lt|gram|kilogram|litre|mililetre))',
      caseSensitive: false,
    );
    final match = unitRegex.firstMatch(name);
    if (match != null) {
      String unit = match.group(1)!.toLowerCase();
      // Standardize units
      unit = unit
          .replaceAll('gram', 'g')
          .replaceAll('kilogram', 'kg')
          .replaceAll('litre', 'l')
          .replaceAll('mililetre', 'ml')
          .replaceAll('lt', 'l');
      return unit;
    }
    return '';
  }
}
