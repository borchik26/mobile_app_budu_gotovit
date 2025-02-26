// Общий смысл кода:
// RecipeDetailScreen - это экран, который отображает подробную информацию о рецепте. Он получает текст рецепта с помощью модели Gemini, используя прокси и API ключ. Пользователь может добавить рецепт в избранное, открыть видео рецепт, посмотреть картинки блюда, поделиться рецептом или заказать готовое блюдо.

import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/app_state.dart';
import '../utils/add_to_shopping_list.dart';
import '../utils/launch.dart';
import '../utils/share_recipe.dart';
import '../utils/order_menu_utils.dart';
import '../utils/images.dart';
import '../utils/in_app_review_helper.dart';

import '../utils/telegram_helper.dart'; // Импорт TelegramHelper

// Расширение для приведения первой буквы строки к верхнему регистру
extension StringExtension on String {
  String capitalize() {
    return this.length > 0
        ? '${this[0].toUpperCase()}${this.substring(1)}'
        : '';
  }
}

class RecipeDetailScreen extends StatefulWidget {
  final String
      recipe; // Строка, содержащая запрос к модели для получения рецепта

  const RecipeDetailScreen({required this.recipe});

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  List<String> _imageUrls = [];
  bool _showAllImages = false;

  bool _isLoading = false; // Флаг, указывающий на загрузку рецепта
  final InAppReview inAppReview = InAppReview.instance;
  int _generationCount = 0; // Добавлено поле счетчика
  String? _recipeDetails; // Текст рецепта
  late String _recipeTitle; // Название рецепта

  @override
  void initState() {
    super.initState();
    _recipeTitle = _extractRecipeTitle(widget.recipe).capitalize();
    _fetchRecipeDetails();
    _fetchImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InAppReviewHelper.maybeShowReview(3);
    });
  }

  Future<void> _incrementGenerationCount() async {
    final prefs = await SharedPreferences.getInstance();
    _generationCount = (prefs.getInt('generation_count') ?? 0) + 1;
    await prefs.setInt('generation_count', _generationCount);
    InAppReviewHelper.maybeShowReview(3);
  }

  Future<void> _fetchImages() async {
    try {
      final urls = await ImageUtils.searchImages(_recipeTitle);
      setState(() {
        _imageUrls = urls;
      });
    } catch (e) {
      print('Ошибка при загрузке изображений: $e');
    }
  }

  // Извлечение названия рецепта из запроса
  String _extractRecipeTitle(String text) {
    final match = RegExp(r'@(.*?)@').firstMatch(text);
    return match != null ? match.group(1)! : '';
  }

  // Загрузка рецепта с помощью модели Gemini
  Future<void> _fetchRecipeDetails() async {
    final apiData = Provider.of<ApiData>(context, listen: false);
    final proxy = apiData.proxy; // Получение прокси
    final apiKey = apiData.apiKey; // Получение API ключа

    // Проверка наличия прокси и API ключа
    if (proxy == null || apiKey == null) {
      if (mounted) {
        setState(() {
          _recipeDetails =
              'Proxy и API ключ не загружены.'; // Установка сообщения об ошибке, если прокси или API ключ не найдены
        });
      }
      TelegramHelper.sendTelegramError(
          "Proxy и API ключ не загружены. $proxy"); // Отправка сообщения в Telegram о возникшей ошибке
      return;
    }

    // Установка флага загрузки в true
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // Создание HTTP клиента с настройкой прокси
    final client = HttpClient();
    final proxyParts = proxy.split('@');
    final credentials = proxyParts[0].split(':');
    final hostPort = proxyParts[1].split(':');

    client.findProxy = (uri) {
      return "PROXY ${hostPort[0]}:${hostPort[1]}";
    };
    client.addProxyCredentials(
      hostPort[0],
      int.parse(hostPort[1]),
      'Basic',
      HttpClientBasicCredentials(credentials[0], credentials[1]),
    );

    final ioClient =
        IOClient(client); // Создание IOClient для работы с HTTP запросами

    try {
      // Создание модели Gemini
      final model = GenerativeModel(
        model: 'gemini-1.5-flash-latest', // Имя модели
        apiKey: apiKey, // API ключ
        httpClient: ioClient, // HTTP клиент
      );

      // Создание контента запроса
      final content = [Content.text(widget.recipe)];
      // Отправка запроса к модели Gemini
      final response = await model.generateContent(content);

      // Установка полученного рецепта и сброс флага загрузки
      if (mounted) {
        setState(() {
          _recipeDetails = response.text;
          _isLoading = false;
        });
      }
     InAppReviewHelper.maybeShowReview(3);
    _incrementGenerationCount();
    } catch (e) {
      print("Ошибка: $e");
      // Установка сообщения об ошибке
      if (mounted) {
        setState(() {
          _recipeDetails =
              'Ошибка: Перезапустите пожалуйста приложение и попробуйте еще раз. $e ';
          _isLoading = false;
        });
      }
      TelegramHelper.sendTelegramError(
          "Ошибка при получении рецепта: $e $apiKey"); // Отправка сообщения в Telegram о возникшей ошибке
    } finally {
      ioClient.close(); // Закрытие HTTP клиента
    }
  }

  // Добавление рецепта в избранное
  void _addToFavorites() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> favorites = prefs.getStringList('favoritesList') ?? [];

      // Расширенный формат данных рецепта
      Map<String, String> recipeData = {
        'title': _recipeTitle,
        'details': _recipeDetails ?? 'Инструкции по приготовлению не найдены.',
        'hasVideo': 'true', // Флаги для кнопок
        'hasImages': 'true',
        'canShare': 'true',
        'canOrder': 'true'
      };

      String recipeJson = jsonEncode(recipeData);
      favorites.add(recipeJson);
      await prefs.setStringList('favoritesList', favorites);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Рецепт добавлен в избранное'),
        duration: Duration(seconds: 1),
      ));
    } catch (e) {
      print("Ошибка при добавлении в избранное: $e");
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Stack(
            alignment: Alignment.center, // Центрируем содержимое
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
              Positioned(
                right: 8.0, // Положение крестика справа
                top: 8.0, // Положение крестика сверху
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Рецепт'), // Заголовок экрана
        actions: [
          IconButton(
            icon: Icon(
                Icons.favorite), // Кнопка для добавления рецепта в избранное
            onPressed:
                _addToFavorites, // Вызов функции добавления рецепта в избранное
          ),
        ],
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back), // Кнопка для возврата на предыдущий экран
          onPressed: () {
            Navigator.pop(context); // Возврат на предыдущий экран
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? Center(
                child:
                    CircularProgressIndicator()) // Отображение индикатора загрузки, если рецепт еще не загружен
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _recipeTitle,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16.0),
                  if (_imageUrls.isNotEmpty)
                    Column(
                      children: [
                        Stack(
                          alignment:
                              Alignment.topCenter, // Выравнивание текста вверху
                          children: [
                            GridView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                              itemCount: _showAllImages ? _imageUrls.length : 6,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    _showImageDialog(
                                        context, _imageUrls[index]);
                                  },
                                  child: Image.network(
                                    _imageUrls[index],
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),

                            // Полупрозрачный текст над изображениями
                            Positioned(
                              top: 8.0, // Отступ сверху
                              child: Container(
                                color: Colors.black54, // Полупрозрачный фон
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.0), // Горизонтальные отступы
                                child: Text(
                                  'фотографии из интернета',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10, // Размер шрифта
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_imageUrls.length > 6)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showAllImages = !_showAllImages;
                              });
                            },
                            child: Text(_showAllImages
                                ? 'Скрыть картинки'
                                : 'Показать все картинки'),
                          ),
                      ],
                    ),

                  const SizedBox(height: 16.0),

                  ElevatedButton.icon(
                    icon: Icon(Icons
                        .add_shopping_cart), // Кнопка для добавления ингредиентов в список покупок
                    label: Text('Добавить ингредиенты в список покупок'),
                    onPressed: () => addToShoppingList(context, {
                      'title': _recipeTitle,
                      'details': _recipeDetails ??
                          'Инструкции по приготовлению не найдены.'
                    }), // Вызов функции добавления ингредиентов в список покупок
                  ),
                  const SizedBox(height: 16.0),
                  _recipeDetails != null
                      ? Text(
                          _recipeDetails!, // Вывод подробного описания рецепта
                          style: TextStyle(fontSize: 16),
                        )
                      : Text(
                          'Инструкции по приготовлению не найдены.'), // Вывод сообщения, если рецепт не найден
                  const SizedBox(height: 16.0),
                  // Строка с кнопками YouTube, Rutube, VK Видео
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons
                            .video_library), // Кнопка для поиска видео рецепта
                        label: Text('YouTube'),
                        onPressed: () => launchYouTube(context,
                            _recipeTitle), // Вызов функции запуска поиска видео рецепта
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons
                            .video_library), // Кнопка для поиска видео рецепта
                        label: Text('Rutube'),
                        onPressed: () => launchRutube(context,
                            _recipeTitle), // Вызов функции запуска поиска видео рецепта
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons
                            .video_library), // Кнопка для поиска видео рецепта
                        label: Text('VK Видео'),
                        onPressed: () => launchVkvideo(context,
                            _recipeTitle), // Вызов функции запуска поиска видео рецепта
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  // Строка с кнопкой для поиска картинок
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(
                            Icons.image), // Кнопка для поиска картинок блюда
                        label: Text('Картинки блюда'),
                        onPressed: () => launchYandexImages(context,
                            _recipeTitle), // Вызов функции запуска поиска картинок блюда
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  // Строка с кнопкой для поделиться
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.share), // Кнопка для обмена рецептом
                        label: Text('Поделиться'),
                        onPressed: () => shareRecipe(context, {
                          'title': _recipeTitle,
                          'details': _recipeDetails ??
                              'Инструкции по приготовлению не найдены.'
                        }), // Вызов функции обмена рецептом
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  // Строка с кнопкой для заказа готового блюда
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons
                            .local_restaurant), // Кнопка для заказа готового блюда
                        label: Text('Заказать готовое блюдо'),
                        onPressed: () => showOrderMenu(context, {
                          'title': _recipeTitle,
                          'details': _recipeDetails ??
                              'Инструкции по приготовлению не найдены.'
                        }), // Вызов функции показа меню заказа
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }
}
