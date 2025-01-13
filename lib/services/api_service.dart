import 'package:http/http.dart' as http;
import 'package:beautiful_soup_dart/beautiful_soup.dart';
import 'dart:convert';
import '../models/product.dart';
import '../models/market_source.dart';

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
      // Fetch from multiple sources concurrently
      final results = await Future.wait([
        _searchMigros(query),
        _searchA101(query),
        _searchBim(query),
      ]);

      // Combine and normalize results
      final List<Product> products = [];
      final Map<String, Map<String, double>> priceMap = {};

      // Process results from each source
      for (var sourceProducts in results) {
        for (var product in sourceProducts) {
          String normalizedName = _normalizeProductName(product.name);

          if (!priceMap.containsKey(normalizedName)) {
            priceMap[normalizedName] = {};
          }

          priceMap[normalizedName]?.addAll(product.prices);
        }
      }

      // Create combined products
      priceMap.forEach((name, prices) {
        products.add(Product(
          name: name,
          imageUrl: '', // Use the first available image
          prices: prices,
          unit: _extractUnit(name),
        ));
      });

      return products;
    } catch (e) {
      throw Exception('Error fetching products: $e');
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
      // First, get the search results page
      final response = await http.get(
        Uri.parse(
            'https://www.bim.com.tr/Categories/100/arama.aspx?query=${Uri.encodeComponent(query)}'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      );

      if (response.statusCode == 200) {
        final List<Product> products = [];
        final soup = BeautifulSoup(response.body);

        // Find all product containers
        final productElements = soup.findAll('div', class_: 'product-card');

        for (var element in productElements) {
          try {
            // Extract product details
            final nameElement = element.find('h3', class_: 'product-name');
            final priceElement = element.find('span', class_: 'current-price');
            final imageElement = element.find('img', class_: 'product-image');

            if (nameElement != null && priceElement != null) {
              final name = nameElement.text.trim();
              final priceText = priceElement.text
                  .trim()
                  .replaceAll('TL', '')
                  .replaceAll(',', '.')
                  .trim();
              final price = double.tryParse(priceText) ?? 0.0;
              final imageUrl = imageElement?.attributes['src'] ?? '';

              products.add(Product(
                name: name,
                imageUrl: imageUrl.startsWith('http')
                    ? imageUrl
                    : 'https://www.bim.com.tr$imageUrl',
                prices: {'BİM': price},
                unit: _extractUnit(name),
              ));
            }
          } catch (e) {
            print('Error parsing product element: $e');
            continue;
          }
        }

        return products;
      } else {
        throw Exception('BİM website error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching from BİM: $e');
      return [];
    }
  }

  // Add rate limiting functionality
  DateTime? _lastBimRequest;
  static const _minRequestInterval = Duration(seconds: 2);

  Future<void> _respectRateLimit() async {
    if (_lastBimRequest != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastBimRequest!);
      if (timeSinceLastRequest < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - timeSinceLastRequest);
      }
    }
    _lastBimRequest = DateTime.now();
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
        .replaceAll(RegExp(r'\d+\s*(ml|gr|g|kg|l|lt)'), '')
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
