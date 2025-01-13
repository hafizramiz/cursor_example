class Product {
  final String name;
  final String imageUrl;
  final Map<String, double> prices; // Store -> Price
  final String unit;

  Product({
    required this.name,
    required this.imageUrl,
    required this.prices,
    required this.unit,
  });

  String get cheapestStore {
    if (prices.isEmpty) return 'No prices available';
    var entry = prices.entries.reduce((a, b) => a.value < b.value ? a : b);
    return entry.key;
  }

  double get cheapestPrice {
    if (prices.isEmpty) return 0.0;
    return prices.values.reduce((a, b) => a < b ? a : b);
  }
}
