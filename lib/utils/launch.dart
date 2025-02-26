// Общий смысл кода:
// Этот файл содержит набор функций для запуска внешних приложений, таких как YouTube, Яндекс Картинки и браузер.
// Эти функции используются для поиска дополнительной информации о рецепте или для заказа продуктов онлайн.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Функция для запуска поиска видео рецепта на YouTube
Future<void> launchYouTube(BuildContext context, String recipeTitle) async {
  const String baseUrl = 'https://www.youtube.com/results?search_query=';
  final url = '$baseUrl${Uri.encodeComponent(recipeTitle)}'; // Формирование URL для поиска на YouTube
  // Проверка возможности запуска URL
  if (await canLaunch(url)) {
    await launch(url); // Запуск URL в браузере
  } else {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Не удалось открыть YouTube'))); // Вывод сообщения об ошибке
  }
}

// Функция для запуска поиска видео рецепта на Rutube
Future<void> launchRutube(BuildContext context, String recipeTitle) async {
  const String baseUrl = 'https://rutube.ru/search/?query=';
  final url = '$baseUrl${Uri.encodeComponent(recipeTitle)}'; // Формирование URL для поиска на YouTube
  // Проверка возможности запуска URL
  if (await canLaunch(url)) {
    await launch(url); // Запуск URL в браузере
  } else {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Не удалось открыть Rutube'))); // Вывод сообщения об ошибке
  }
}

// Функция для запуска поиска видео рецепта на Vkvideo
Future<void> launchVkvideo(BuildContext context, String recipeTitle) async {
  const String baseUrl = 'https://m.vkvideo.ru/';
  final query = Uri.encodeComponent(recipeTitle); // Кодирование названия рецепта
  final url = '$baseUrl?q=$query&action=search'; // Формирование полного URL

  // Проверка возможности запуска URL
  if (await canLaunch(url)) {
    await launch(url); // Запуск URL в браузере
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось открыть Vkvideo')),
    ); // Вывод сообщения об ошибке
  }
}

// Функция для запуска поиска картинок блюда в Яндекс Картинках
Future<void> launchYandexImages(
    BuildContext context, String recipeTitle) async {
  const String baseUrl = 'https://yandex.ru/images/search?from=tabbar&text=';
  final url = '$baseUrl${Uri.encodeComponent(recipeTitle)}'; // Формирование URL для поиска в Яндекс Картинках
  // Проверка возможности запуска URL
  if (await canLaunch(url)) {
    await launch(url); // Запуск URL в браузере
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть Яндекс Картинки'))); // Вывод сообщения об ошибке
  }
}

// Функция для открытия ссылки на сервис доставки в браузере
Future<void> launchInBrowser(String url, String product) async {
  String parsedProduct = product.split('-').first.trim(); // Извлечение названия продукта из строки
  final fullUrl = Uri.encodeFull('$url$parsedProduct'); // Формирование полного URL
  final uri = Uri.parse(fullUrl); // Преобразование строки в URL

  // Проверка возможности запуска URL
  if (!await launchUrl(
    uri,
    mode: LaunchMode.externalApplication, // Запуск URL во внешнем приложении
  )) {
    throw Exception('Could not launch $fullUrl'); // Выбрасывание исключения, если произошла ошибка
  }
}

// Функция для открытия поиска картинок в браузере
void openImageSearch(BuildContext context, String url) {
  launch(url); // Запуск URL в браузере
}