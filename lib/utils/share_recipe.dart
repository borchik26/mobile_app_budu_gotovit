// Общий смысл кода:
// Этот файл содержит функцию shareRecipe, которая позволяет пользователю поделиться рецептом с помощью других приложений.
// В сообщении для обмена указывается название рецепта, его описание и ссылка на приложение в Google Play.


import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/telegram_helper.dart'; // Импортируем TelegramHelper

// URL для ссылки на приложение в Google Play
const String googlePlayUrl =
    "bit.ly/budu_gotovit"; 

// Функция для обмена рецептом
Future<void> shareRecipe(
    BuildContext context, Map<String, String> recipe) async {
  // Создание сообщения для обмена
  final message =
      'Посмотри рецепт: ${recipe['title']}\n\n${recipe['details']}\n\n'
      'Больше рецептов в приложении $googlePlayUrl';
  try {
    // Попытка поделиться сообщением
    await Share.share(message);
  } catch (e) {
    print('Ошибка при попытке поделиться рецептом: $e');
    // Вывод сообщения об ошибке на экране
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Не удалось поделиться рецептом. Попробуйте еще раз.')));
    TelegramHelper.sendTelegramError("Ошибка при попытке поделиться рецептом: $e"); // Отправка сообщения в Telegram о возникшей ошибке
  }
}