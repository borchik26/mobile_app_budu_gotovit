import 'package:share_plus/share_plus.dart';

class ShareHelper {
  static Future<void> shareShoppingList(List<String> activeList, List<String> completedList) async {
    try {
      String shareText = 'Список покупок:\n\n';
      
      if (activeList.isNotEmpty) {
        shareText += '📝 Нужно купить:\n';
        activeList.forEach((item) => shareText += '• $item\n');
      }
      
      if (completedList.isNotEmpty) {
        shareText += '\n✅ Куплено:\n';
        completedList.forEach((item) => shareText += '• $item\n');
      }
      
      await Share.share(shareText);
    } catch (e) {
      print('Ошибка при попытке поделиться: $e');
    }
  }
}
