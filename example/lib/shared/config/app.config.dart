class AppConfig {
  // JSONPlaceholder is sometimes blocked by Cloudflare
  // static const String baseUrl = 'https://jsonplaceholder.typicode.com';
  static const String baseUrl = 'https://dummyjson.com';

  // Alternative APIs if JSONPlaceholder is blocked:
  // static const String baseUrl = 'https://reqres.in/api';  // Use /users instead of /posts
  // static const String baseUrl = 'https://dummyjson.com';  // Use /posts
  // static const String baseUrl = 'https://gorest.co.in/public/v2';  // Use /posts
}
