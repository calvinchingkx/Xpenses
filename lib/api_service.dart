import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://replit.com/@alvin316625/expense-ai#main.py'; // 👈 Replace with your real API

  static Future<String> predictCategory(String description) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'description': description}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['category'];
    } else {
      throw Exception('Failed to predict category');
    }
  }
}
