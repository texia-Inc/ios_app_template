import 'package:app_review/app_review.dart';

class AppReview {
  static Future<void> requestReview() async {
    try {
      await AppReview.requestReview();
    } catch (e) {
      // Handle error silently
    }
  }
  
  static Future<void> writeReview() async {
    try {
      await AppReview.writeReview();
    } catch (e) {
      // Handle error silently
    }
  }
}