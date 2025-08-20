import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class RemoteConf {
  static Map<String, dynamic> _c = {};
  
  static Future<void> load(Uri url) async {
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        _c = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // Handle error silently
    }
  }
  
  static T get<T>(String key, T fallback) {
    return (_c[key] as T?) ?? fallback;
  }
  
  static bool getBool(String key, bool fallback) {
    return get<bool>(key, fallback);
  }
  
  static int getInt(String key, int fallback) {
    return get<int>(key, fallback);
  }
  
  static double getDouble(String key, double fallback) {
    return get<double>(key, fallback);
  }
  
  static String getString(String key, String fallback) {
    return get<String>(key, fallback);
  }
}