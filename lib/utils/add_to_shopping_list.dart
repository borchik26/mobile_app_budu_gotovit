// Общий смысл кода:
// Этот файл содержит две функции:
// parseIngredients: Эта функция извлекает список ингредиентов из текста рецепта, очищая его и фильтруя стандартные элементы.
// addToShoppingList: Эта функция добавляет ингредиенты из рецепта в список покупок, который хранится в SharedPreferences.




import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/telegram_helper.dart'; // Импортируем TelegramHelper

// Функция для извлечения списка ингредиентов из текста рецепта
List<String> parseIngredients(String details) {
  try {
    // Находим начало и конец раздела "Ингредиенты" в тексте рецепта
    final ingredientsStart =
        details.indexOf("**Ингредиенты:**") + "**Ингредиенты:**".length;
    final ingredientsEnd = details.indexOf("**Приготовление:**");
    // Если разделы "Ингредиенты" или "Приготовление" не найдены, возвращаем пустой список
    if (ingredientsStart < 0 || ingredientsEnd < 0) return [];

    // Выделяем раздел "Ингредиенты" из текста рецепта
    final ingredientsSection =
        details.substring(ingredientsStart, ingredientsEnd).trim();

    // Парсим список ингредиентов, очищая от лишних символов и фильтруя
    final ingredientsList = ingredientsSection
        .split('\n')
        .map((ingredient) {
          String cleanedIngredient = ingredient
//             .replaceAll(RegExp(r'\(.*?\)'), '') // Удаление скобок и содержимого
              .replaceAll('*', '') // Удаление символов "*"
              .trim(); // Удаление лишних пробелов
          return cleanedIngredient;
        })
        // Фильтрация списка ингредиентов, удаление стандартных элементов
        .where((ingredient) =>
            ingredient.isNotEmpty && // Оставление только непустых строк
            !ingredient.toLowerCase().contains('соль') &&
            !ingredient.toLowerCase().contains('сахар') &&
            !ingredient.toLowerCase().contains(':') &&
            !ingredient.toLowerCase().contains('мясо/рыба') &&
            !ingredient.toLowerCase().contains('овощи') &&
            !ingredient.toLowerCase().contains('фрукты') &&
            !ingredient.toLowerCase().contains('вода'))
        .toList();

    return ingredientsList;
  } catch (e) {
    TelegramHelper.sendTelegramError("Ошибка при парсинге ингредиентов: $e"); // Отправка сообщения в Telegram о возникшей ошибке
    return []; // Возвращаем пустой список, если произошла ошибка
  }
}

// Функция для добавления ингредиентов из рецепта в список покупок
Future<void> addToShoppingList(
    BuildContext context, Map<String, String> recipe) async {
  try {
    // Получение SharedPreferences для хранения списка покупок
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> shoppingList = prefs.getStringList('shoppingList') ?? []; // Получение списка покупок из SharedPreferences

    // Парсинг ингредиентов из рецепта
    String ingredientsText = recipe['details']!;
    List<String> ingredients = parseIngredients(ingredientsText);

    // Добавление ингредиентов в список покупок
    shoppingList.addAll(ingredients);

    // Сортировка списка покупок по алфавиту
    shoppingList.sort();

    // Сохранение обновленного списка покупок в SharedPreferences
    await prefs.setStringList('shoppingList', shoppingList);
    // Вывод сообщения об успешном добавлении
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ингредиенты добавлены в список покупок'),
        duration: Duration(seconds: 1),
      ),
    );
  } catch (e) {
    TelegramHelper.sendTelegramError(
        "Ошибка при добавлении ингредиентов в список покупок: $e"); // Отправка сообщения в Telegram о возникшей ошибке
  }
}