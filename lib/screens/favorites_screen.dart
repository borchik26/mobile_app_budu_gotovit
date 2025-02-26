import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Импорт пакета для работы с SharedPreferences
import 'dart:convert'; // Импорт пакета для работы с JSON
import '../utils/telegram_helper.dart'; // Импорт утилиты для отправки сообщений в Telegram
import 'favorite_recipe_detail_screen.dart'; // Импорт экрана с деталями рецепта

class FavoritesScreen extends StatefulWidget {
  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final List<Map<String, String>> _favoritesList =
      []; // Список для хранения избранных рецептов

  @override
  void initState() {
    super.initState();
    _loadFavoritesList(); // Загрузка списка избранных рецептов при инициализации экрана
  }

  // Функция для загрузки списка избранных рецептов из SharedPreferences
  void _loadFavoritesList() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList('favoritesList') ?? [];
      setState(() {
        _favoritesList.clear();
        for (String item in favorites) {
          Map<String, dynamic> decodedMap = jsonDecode(item);
          _favoritesList.add(Map<String, String>.from(
              decodedMap.map((key, value) => MapEntry(key, value.toString()))));
        }
      });
    } catch (e) {
      print("Error loading favorites: $e");
      await TelegramHelper.sendTelegramError("Error loading favorites: $e");
    }
  }

  // Функция для очистки списка избранных рецептов
  void _clearList() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(
          'favoritesList'); // Удаление списка избранных рецептов из SharedPreferences
      setState(() {
        _favoritesList.clear(); // Очистка списка рецептов в памяти
      });
    } catch (e) {
      print("Error clearing favorites list: $e");
      await TelegramHelper.sendTelegramError(
          "Error clearing favorites list: $e"); // Отправка сообщения в Telegram при ошибке
    }
  }

  // Функция для перехода к экрану с деталями рецепта
  void _navigateToRecipeDetail(Map<String, String> recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FavoriteRecipeDetailScreen(
            recipe: recipe), // Переход на экран с деталями рецепта
      ),
    );
  }

  // Функция для удаления рецепта из списка избранных
  void _removeRecipe(int index) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _favoritesList.removeAt(index); // Удаление рецепта из списка в памяти
      });
      List<String> favorites = _favoritesList
          .map((e) => jsonEncode(e))
          .toList(); // Кодирование списка рецептов в JSON-строки
      await prefs.setStringList('favoritesList',
          favorites); // Сохранение обновленного списка в SharedPreferences
    } catch (e) {
      print("Error removing recipe: $e");
      await TelegramHelper.sendTelegramError(
          "Error removing recipe: $e"); // Отправка сообщения в Telegram при ошибке
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Избранные рецепты'), // Заголовок экрана
      ),
      body: ListView.builder(
        // Виджет для отображения списка рецептов
        itemCount: _favoritesList.length, // Количество рецептов в списке
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
                _favoritesList[index]['title']!), // Название рецепта в списке
            onTap: () => _navigateToRecipeDetail(_favoritesList[
                index]), // Переход к экрану с деталями рецепта при нажатии на элемент списка
            trailing: IconButton(
              icon: Icon(Icons.delete), // Кнопка удаления рецепта
              onPressed: () => _removeRecipe(
                  index), // Вызов функции удаления рецепта при нажатии на кнопку
            ),
          );
        },
      ),
    );
  }
}
