class ApiConfig {
  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: 'YOUR_DEFAULT_API_KEY',
  );

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.com/v1', // Replace with actual API URL
  );
}
