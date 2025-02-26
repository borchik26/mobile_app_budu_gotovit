// Общий смысл кода:
// RecipesListScreen - это экран, который отображает список рецептов, полученных с помощью модели Gemini, используя переданные фильтры. Пользователь может перейти на экран с детальной информацией о рецепте, найти картинки блюда в Яндекс Картинках.
// Также на этом экране есть кнопка "Найти еще", которая позволяет запросить у модели дополнительные рецепты.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/app_state.dart';
import 'recipe_detail_screen.dart';
import '../utils/launch.dart';
import '../utils/telegram_helper.dart'; // Импортируйте TelegramHelper

class RecipesListScreen extends StatefulWidget {
  // Параметры фильтров для поиска рецептов
  final String? selectedCategory;
  final String? selectedDish;
  final String? selectedCuisine;
  final String? selectedMenu;
  final String? selectedCookingTime;
  final String? selectedDifficulty;
  final String? selectedCost;
  final String? selectedSeason;
  final String? selectedCookingMethod;
  final List<String> includedIngredients;
  final List<String> excludedIngredients;
  final String preferences;

  // Конструктор экрана списка рецептов
  RecipesListScreen({
    this.selectedCategory,
    this.selectedDish,
    this.selectedCuisine,
    this.selectedMenu,
    this.selectedCookingTime,
    this.selectedDifficulty,
    this.selectedCost,
    this.selectedSeason,
    this.selectedCookingMethod,
    required this.includedIngredients,
    required this.excludedIngredients,
    required this.preferences,
    required int numberOfPeople,
  });

  @override
  _RecipesListScreenState createState() => _RecipesListScreenState();
}

class _RecipesListScreenState extends State<RecipesListScreen> {
  bool _isLoading = false; // Флаг для отображения индикатора загрузки
  List<String> _recipes = []; // Список рецептов, полученных от AI
  List<String> _allFetchedRecipes =
      []; // Отслеживание всех загруженных рецептов
  String? _result; // Хранит результат от AI
  String? _errorMessage; // Сообщение об ошибке
  final ScrollController _scrollController =
      ScrollController(); // Контроллер прокрутки списка

  @override
  void initState() {
    super.initState();
    _sendQuery(); // Автоматический запрос рецептов при инициализации экрана
  }

  // Отправка запроса для генерации списка рецептов
  Future<void> _sendQuery() async {
    final apiData = Provider.of<ApiData>(context, listen: false);
    final appState = Provider.of<AppState>(context, listen: false);
    final proxy = apiData.proxy;
    final apiKey = apiData.apiKey;

    // Проверка наличия proxy и API ключа
    if (proxy == null || apiKey == null) {
      setState(() {
        _errorMessage = 'Proxy и API ключ не загружены.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Формирование запроса для генеративной модели
    final query =
        'Напиши 20 названий рецептов. на русском. одним списком. каждый рецепт пронумеруй. Без комментариев и заголовка. '
        'Категория: ${widget.selectedCategory}. '
        'Блюдо: ${widget.selectedDish}. '
        'Кухня: ${widget.selectedCuisine}. '
        'Меню: ${widget.selectedMenu}. '
        'Время приготовления: ${widget.selectedCookingTime}. '
        'Сложность: ${widget.selectedDifficulty}. '
        'Стоимость ингредиентов: ${widget.selectedCost}. '
        'Сезонность: ${widget.selectedSeason}. '
        'Способ приготовления: ${widget.selectedCookingMethod}. '
        'Включенные ингредиенты: ${widget.includedIngredients.join(', ')}. '
        'Исключенные ингредиенты: ${widget.excludedIngredients.join(', ')}. '
        'Предпочтения: ${widget.preferences}. '
        'Количество человек: ${appState.numberOfPeople}. '; // Используем значение из appState

    final client = HttpClient();
    final proxyParts = proxy.split('@');
    final credentials = proxyParts[0].split(':');
    final hostPort = proxyParts[1].split(':');

    // Настройка прокси-клиента
    client.findProxy = (uri) {
      return "PROXY ${hostPort[0]}:${hostPort[1]}";
    };
    client.addProxyCredentials(
      hostPort[0],
      int.parse(hostPort[1]),
      'Basic',
      HttpClientBasicCredentials(credentials[0], credentials[1]),
    );

    final ioClient = IOClient(client);

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash-latest', // Используемая модель AI
        apiKey: apiKey,
        httpClient: ioClient,
      );

      // Отправка запроса модели и обработка ответа
      final content = [Content.text(query)];
      final response = await model.generateContent(content);

      if (mounted) {
        // Проверяем, что виджет все еще в дереве
        setState(() {
          _result = response.text;
          print("Received response: $_result"); // Вывод результата для отладки
          _parseRecipes(); // Парсинг полученного текста в список рецептов
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Ошибка: $e");
      if (mounted) {
        // Проверяем mounted также в блоке catch
        setState(() {
          _errorMessage = 'Ошибка: $e';
          _isLoading = false;
        });
      }
      // Отправка ошибки в Telegram
      TelegramHelper.sendTelegramError(
          "Ошибка при получении списка рецептов: $e");
    } finally {
      ioClient.close(); // Закрытие HTTP-клиента
    }
  }

  // Парсинг списка рецептов из результата модели
  void _parseRecipes() {
    if (_result != null) {
      try {
        // Очистка результата от лишних символов
        final cleanedResult =
            _result!.replaceAll('\n', '').replaceAll('\r', '').trim();
        print("Cleaned Result: $cleanedResult"); // Отладочный вывод

        // Разделение строк по шаблону нумерации
        final lines = cleanedResult.split(RegExp(r'\d+\.\s*'));
        lines.removeWhere((line) => line.isEmpty); // Удаление пустых строк
        setState(() {
          _recipes = lines;
          _allFetchedRecipes
              .addAll(lines); // Добавление новых рецептов к полному списку
        });
      } catch (e) {
        print("Ошибка парсинга: $e");
        setState(() {
          _errorMessage = 'Ошибка парсинга: $e';
        });
        // Отправка ошибки в Telegram
        TelegramHelper.sendTelegramError("Ошибка при парсинге рецептов: $e");
      }
    }
  }

  // Запрос на получение дополнительных рецептов
  Future<void> _findMoreRecipes() async {
    setState(() {
      _isLoading = true;
    });

    // Исключаем ранее полученные рецепты
    final previouslyFetchedRecipes = _allFetchedRecipes.join(', ');
    final newPrompt =
        'Напиши 20 названий рецептов. на русском. одним списком. каждый рецепт пронумеруй. Без комментариев и заголовка. '
        'Категория: ${widget.selectedCategory}. '
        'Блюдо: ${widget.selectedDish}. '
        'Кухня: ${widget.selectedCuisine}. '
        'Меню: ${widget.selectedMenu}. '
        'Время приготовления: ${widget.selectedCookingTime}. '
        'Сложность: ${widget.selectedDifficulty}. '
        'Стоимость ингредиентов: ${widget.selectedCost}. '
        'Сезонность: ${widget.selectedSeason}. '
        'Способ приготовления: ${widget.selectedCookingMethod}. '
        'Включенные ингредиенты: ${widget.includedIngredients.join(', ')}. '
        'Исключенные ингредиенты: ${widget.excludedIngredients.join(', ')}. '
        'Предпочтения: ${widget.preferences}. '
        'Исключи следующие рецепты: $previouslyFetchedRecipes.'; 

    final apiData = Provider.of<ApiData>(context, listen: false);
    final proxy = apiData.proxy;
    final apiKey = apiData.apiKey;

    // Проверка наличия proxy и API ключа
    if (proxy == null || apiKey == null) {
      setState(() {
        _errorMessage = 'Proxy и API ключ не загружены.';
        _isLoading = false;
      });
      return;
    }

    final client = HttpClient();
    final proxyParts = proxy.split('@');
    final credentials = proxyParts[0].split(':');
    final hostPort = proxyParts[1].split(':');

    // Настройка прокси-клиента
    client.findProxy = (uri) {
      return "PROXY ${hostPort[0]}:${hostPort[1]}";
    };
    client.addProxyCredentials(
      hostPort[0],
      int.parse(hostPort[1]),
      'Basic',
      HttpClientBasicCredentials(credentials[0], credentials[1]),
    );

    final ioClient = IOClient(client);

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash-latest', // Используемая модель AI
        apiKey: apiKey,
        httpClient: ioClient,
      );

      // Отправка нового запроса для получения дополнительных рецептов
      final content = [Content.text(newPrompt)];
      final response = await model.generateContent(content);

      setState(() {
        _result = response.text;
        print("Received response: $_result"); // Отладочный вывод
        _parseRecipes(); // Парсинг полученных рецептов
        _isLoading = false;
      });

      // Прокрутка списка к началу
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.jumpTo(0);
      });
    } catch (e) {
      print("Ошибка: $e");
      setState(() {
        _errorMessage = 'Ошибка: $e';
        _isLoading = false;
      });
      // Отправка ошибки в Telegram
      TelegramHelper.sendTelegramError(
          "Ошибка при получении списка рецептов (findMoreRecipes): $e");
    } finally {
      ioClient.close(); // Закрытие HTTP-клиента
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Список рецептов'), // Заголовок экрана
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator()) // Индикатор загрузки
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!)) // Отображение ошибки
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _recipes.length +
                      1, // Количество элементов в списке + 1 для кнопки
                  itemBuilder: (context, index) {
                    if (index < _recipes.length) {
                      return ListTile(
                        title: Text(_recipes[index]),
                        trailing: IconButton(
                          icon: Icon(Icons.image_search, color: Colors.purple),
                          onPressed: () {
                            try {
                              launchYandexImages(
                                  context,
                                  _recipes[
                                      index]); // Поиск изображения рецепта в Яндекс
                            } catch (e) {
                              // Отправка ошибки в Telegram
                              TelegramHelper.sendTelegramError(
                                  "Ошибка при открытии Яндекс Картинки: $e");
                            }
                          },
                        ),
                        onTap: () {
                          try {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecipeDetailScreen(
                                  recipe:
                                      'Напиши рецепт @${_recipes[index]}@. на русском. без твоих комментариев. Точно расчитай ингридиенты по количеству порций. Все ингредиенты указывай в формате "Ингредиент - вес" (например, Пармезан - 50 г). Рецепт должен содержать заголовок с указанием количества порций, время приготовления, подзаголовки: **Ингредиенты:**, **Приготовление:**, **Советы:**. В ответ не включай ни какой текст из промта. Пронумерованные шаги в пункте **Приготовление:** разделяй одной пустой строкой для удобства чтения.'
                                      'Категория: ${widget.selectedCategory}. '
                                      'Блюдо: ${widget.selectedDish}. '
                                      'Кухня: ${widget.selectedCuisine}. '
                                      'Меню: ${widget.selectedMenu}. '
                                      'Время приготовления: ${widget.selectedCookingTime}. '
                                      'Сложность: ${widget.selectedDifficulty}. '
                                      'Стоимость ингредиентов: ${widget.selectedCost}. '
                                      'Сезонность: ${widget.selectedSeason}. '
                                      'Способ приготовления: ${widget.selectedCookingMethod}. '
                                      'Включенные ингредиенты: ${widget.includedIngredients.join(', ')}. '
                                      'Исключенные ингредиенты: ${widget.excludedIngredients.join(', ')}. '
                                      'Предпочтения: ${widget.preferences}. '
                                      'Количество порций: ${appState.numberOfPeople}. ', // Используем значение из appState
                                ),
                              ),
                            );
                          } catch (e) {
                            // Отправка ошибки в Telegram
                            TelegramHelper.sendTelegramError(
                                "Ошибка при переходе к детализации рецепта: $e");
                          }
                        },
                      );
                    } else {
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ElevatedButton(
                              onPressed: () {
                                try {
                                  _findMoreRecipes(); // Запрос дополнительных рецептов
                                } catch (e) {
                                  // Отправка ошибки в Telegram
                                  TelegramHelper.sendTelegramError(
                                      "Ошибка при поиске дополнительных рецептов: $e");
                                }
                              },
                              child: Text('Найти еще'),
                            ),
                          ),
                          SizedBox(height: 80),
                        ],
                      );
                    }
                  },
                ),
    );
  }
}
