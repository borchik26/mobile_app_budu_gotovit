import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InAppReviewHelper {
  static const String _reviewRequestedKey = 'review_requested';
  static const String _generationCountKey = 'generation_count';

  static Future<void> maybeShowReview(int generationThreshold) async {
    final prefs = await SharedPreferences.getInstance();
    int generationCount = prefs.getInt(_generationCountKey) ?? 0;

    generationCount++;
    await prefs.setInt(_generationCountKey, generationCount);

    final reviewRequested = prefs.getBool(_reviewRequestedKey) ?? false;

    if (generationCount >= generationThreshold && !reviewRequested) {
      _requestReview();
      await prefs.setBool(_reviewRequestedKey, true); // Mark as requested
    }
  }

  static Future<void> _requestReview() async {
    final InAppReview inAppReview = InAppReview.instance;

    if (await inAppReview.isAvailable()) {
      try {
        await inAppReview.requestReview();
      } catch (e) {
        print("Ошибка при запросе оценки: $e");
        // Log error, but don't block the user experience.
      }
    }
  }

  static Future<void> resetGenerationCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_generationCountKey, 0);
  }
}
