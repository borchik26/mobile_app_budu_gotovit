// RecipeSearchScreen - это экран, который позволяет пользователю искать рецепты по названию или с помощью фильтров. Пользователь может выбрать категорию, блюдо, кухню, меню, время приготовления, сложность, стоимость, сезонность, способ приготовления, добавить или исключить ингредиенты и задать свои предпочтения.
// Также можно сохранить текущий фильтр для быстрого доступа в будущем..

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'recipe_detail_screen.dart';
import 'recipes_list_screen.dart';
import '../models/app_state.dart';
import '../constants/list_constants.dart';
import '../utils/launch.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Для преобразования данных в JSON
import 'package:image_picker/image_picker.dart'; // Для выбора изображений
import 'dart:io'; // Для работы с файлами
import '../utils/telegram_helper.dart'; // Импортируем TelegramHelper

// Функция для отображения диалогового окна с информацией о разработчике и формой обратной связи
void _showDeveloperInfoDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return DeveloperInfoDialog();
    },
  );
}

class DeveloperInfoDialog extends StatefulWidget {
  @override
  _DeveloperInfoDialogState createState() => _DeveloperInfoDialogState();
}

class _DeveloperInfoDialogState extends State<DeveloperInfoDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _messageController = TextEditingController();
  File? _selectedImage;
  String googlePlayUrl = "bit.ly/budu_gotovit";

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (image != null) {
        _selectedImage = File(image.path);
      }
    });
  }

  Future<void> _sendMessageToTelegram() async {
    if (_formKey.currentState!.validate()) {
      String message = _messageController.text;
      try {
        // Отправка сообщения в Telegram с использованием TelegramHelper
        // Теперь передаем _selectedImage
        TelegramHelper.sendTelegramError(
            "Сообщение из формы обратной связи: $message",
            image: _selectedImage);

        // Закрываем диалоговое окно после успешной отправки
        Navigator.of(context).pop();
        // Опционально: показываем SnackBar с сообщением об успехе
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сообщение отправлено разработчику!')),
        );
      } catch (e) {
        print('Ошибка отправки в Telegram: $e');
        // Обработка ошибки отправки
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('От разработчика'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Здравствуйте! Меня зовут Влад, я разработчик приложения «Буду готовить».\n\n'
                  'С радостью представляю вам своё творение. Надеюсь, оно поможет вам открывать для себя новые и интересные кулинарные идеи.\n\n'
                  'Я всегда стремлюсь к тому, чтобы в приложении не было никаких багов. Однако, если вы обнаружили какой-либо недочёт или у вас есть идея для улучшения, не стесняйтесь оставлять свой комментарий в специальной форме ниже.\n\n'
                  'Если вам нравится мое приложение, пожалуйста, оставьте отзыв, нажав на кнопку ниже.'),
              SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'Ваше сообщение',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите сообщение';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Прикрепить изображение'),
              ),
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Image.file(
                    _selectedImage!,
                    height: 100,
                  ),
                ),
              SizedBox(height: 16),
              // Кнопка для перехода по ссылке
              TextButton(
                onPressed: () async {
                  const url = 'https://bit.ly/budu_gotovit';
                  if (await canLaunch(url)) {
                    await launch(url);
                  } else {
                    throw 'Не удалось открыть $url';
                  }
                },
                child: Text('Оставить отзыв'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Закрытие диалогового окна
          },
          child: Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _sendMessageToTelegram,
          child: Text('Отправить'),
        ),
      ],
    );
  }
}

final TextEditingController _recipeNameController = TextEditingController();

class RecipeSearchScreen extends StatefulWidget {
  @override
  _RecipeSearchScreenState createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen> {
  String _selectedMenu = 'Любое меню';
  String? _selectedCategory; // Выбранная категория рецепта
  String? _selectedDish; // Выбранное блюдо
  String? _selectedCuisine; // Выбранная кухня
  String? _selectedCookingTime; // Выбранное время приготовления
  String? _selectedDifficulty; // Выбранная сложность рецепта
  String? _selectedCost; // Выбранная стоимость рецепта
  String? _selectedSeason; // Выбранный сезон
  String? _selectedCookingMethod; // Выбранный способ приготовления
  int _numberOfPeople = 4; // Количество порций
  String _searchQuery = ""; // Строка для хранения запроса поиска по названию

  // Список включенных и исключенных ингредиентов
  final List<String> _includedIngredients = [];
  final List<String> _excludedIngredients = [];

  // Контроллеры текстовых полей для ввода ингредиентов
  final TextEditingController _includeController = TextEditingController();
  final TextEditingController _excludeController = TextEditingController();
  final TextEditingController _preferencesController =
      TextEditingController(); // Контроллер для ввода предпочтений
  final TextEditingController _filterNameController =
      TextEditingController(); // Контроллер для ввода имени фильтра

  // Контроллер для ввода названия рецепта

  // Функция поиска рецепта по названию
  void _searchRecipeByName() {
    final recipeName = _searchQuery; // Получение названия рецепта
    // Формирование запроса к модели для получения рецепта
    final prompt =
        'Напиши рецепт @$recipeName@ на русском языке. На $_numberOfPeople порций. Точно расчитай ингридиенты по количеству порций. Все ингредиенты указывай в формате "Ингредиент - вес" (например, Пармезан - 50 г). Красиво отформатируй текст. Рецепт должен содержать заголовок с указанием количества порций, время приготовления, подзаголовки: **Ингредиенты:**, **Приготовление:**, **Советы:**. Пронумерованные шаги в пункте **Приготовление:** разделяй пустой строкой для удобства чтения, не пиши <br>. В ответ не включай ни какой текст из промта. ';

    if (recipeName.isNotEmpty) {
      // Проверка, введено ли название рецепта
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailScreen(
            // Переход на экран с деталями рецепта
            recipe: prompt, // Передача запроса к модели в качестве аргумента
          ),
        ),
      );
    }
  }

  Future<void> _saveFilter(String filterName, String filterDescription) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // 1. Создаем карту (Map) с данными фильтра
      Map<String, dynamic> filterData = {
        'name': filterName,
        'description': filterDescription,
        'category': _selectedCategory,
        'dish': _selectedDish,
        'cuisine': _selectedCuisine,
        'menu': _selectedMenu,
        'cookingTime': _selectedCookingTime,
        'difficulty': _selectedDifficulty,
        'cost': _selectedCost,
        'season': _selectedSeason,
        'selectedCookingMethod': _selectedCookingMethod,
        'preferences': _preferencesController.text,
        'includedIngredients': _includedIngredients,
        'excludedIngredients': _excludedIngredients,
        'numberOfPeople': _numberOfPeople,
      };

      // 2. Получаем текущий список фильтров из SharedPreferences
      List<String> savedFiltersJson = prefs.getStringList('savedFilters') ?? [];

      // 3. Преобразуем карту фильтра в JSON строку
      String filterJson = jsonEncode(filterData);

      // 4. Добавляем новую JSON строку в список
      savedFiltersJson.add(filterJson);

      // 5. Сохраняем обновленный список в SharedPreferences
      await prefs.setStringList('savedFilters', savedFiltersJson);

      // Обновляем локальный список ApiData.savedFilters
      _loadSavedFilters();

      // Выводим сообщение об успешном сохранении
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Фильтр сохранен')),
      );
    } catch (e) {
      print("Ошибка при сохранении фильтра: $e");
      TelegramHelper.sendTelegramError("Ошибка при сохранении фильтра: $e");
    }
  }

  Future<void> _loadSavedFilters() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> savedFiltersJson = prefs.getStringList('savedFilters') ?? [];

      setState(() {
        ApiData.savedFilters.clear(); // Очищаем существующий список

        // Преобразуем JSON строки обратно в Map и добавляем в ApiData.savedFilters
        for (String filterJson in savedFiltersJson) {
          Map<String, dynamic> filterData = jsonDecode(filterJson);
          ApiData.savedFilters.add(filterData);
        }
      });
    } catch (e) {
      print("Ошибка при загрузке фильтров: $e");
      TelegramHelper.sendTelegramError("Ошибка при загрузке фильтров: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedMenu = 'Любое меню';
    _loadSavedFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Поиск рецептов'),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              _showDeveloperInfoDialog(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Раздел "Поиск по названию блюда"
              const Text(
                'Поиск по названию блюда',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _recipeNameController,
                decoration: InputDecoration(
                  labelText: 'Название блюда',
                  hintText: 'Введите название блюда',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: Colors.purple),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value; // Обновление запроса поиска
                  });
                },
              ),
              SizedBox(height: 10),
              // Раздел "На сколько порций?"
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'На сколько порций?',
                    style: TextStyle(fontSize: 16),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (_numberOfPeople > 1) {
                              // Уменьшение количества порций
                              _numberOfPeople--;
                            }
                          });
                        },
                        icon: Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$_numberOfPeople', // Отображение количества порций
                        style: TextStyle(fontSize: 18),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _numberOfPeople++; // Увеличение количества порций
                          });
                        },
                        icon: Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.center,
                child: ElevatedButton(
                  // Кнопка для поиска рецепта по названию
                  onPressed: _searchRecipeByName,
                  child: Text('Найти'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Divider(height: 20, thickness: 2, color: Colors.purple),
              SizedBox(height: 10),

              // Раздел "Поиск по фильтру"
              Text(
                'Поиск по фильтру',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              _buildCategoryDropdown(
                  'Любая категория', categories, _selectedCategory, (value) {
                // Выпадающий список для выбора категории
                setState(() {
                  _selectedCategory = value;
                  // Обновление списка блюд в соответствии с выбранной категорией
                  currentDishes = dishesByCategory[value] ?? defaultDishes;
                  _selectedDish =
                      currentDishes.first; // Выбор первого блюда в списке
                  Provider.of<AppState>(context, listen: false)
                      .setSelectedCategory(value!);
                  Provider.of<AppState>(context, listen: false).setSelectedDish(
                      _selectedDish!); // Обновление выбранного блюда в AppState
                });
              }),

              // Выпадающий список для выбора блюда
              _buildDishDropdown('Любое блюдо', currentDishes, _selectedDish,
                  (value) {
                setState(() {
                  _selectedDish = value;
                  Provider.of<AppState>(context, listen: false)
                      .setSelectedDish(value!);
                });
              }),

              // Выпадающий список для выбора кухни
              _buildCuisineDropdown('Любая кухня', cuisines, _selectedCuisine,
                  (value) {
                setState(() {
                  _selectedCuisine = value;
                  Provider.of<AppState>(context, listen: false)
                      .setSelectedCuisine(value!);
                });
              }),
              // Выпадающие списки для выбора остальных фильтров
              _buildDropdown('Любое меню', menus, _selectedMenu, (value) {
                setState(() {
                  _selectedMenu =
                      value ?? 'Любое меню'; // Добавление проверки на null
                  Provider.of<AppState>(context, listen: false)
                      .setSelectedMenu(value ?? 'Любое меню');
                });
              }),
              _buildDropdown(
                  'Время приготовления', cookingTimes, _selectedCookingTime,
                  (value) {
                setState(() {
                  _selectedCookingTime = value;
                  Provider.of<AppState>(context, listen: false)
                      .setSelectedCookingTime(value!);
                });
              }),
              _buildDropdown('Сложность', difficulties, _selectedDifficulty,
                  (value) {
                setState(() {
                  _selectedDifficulty = value;
                  Provider.of<AppState>(context, listen: false)
                      .setSelectedDifficulty(value!);
                });
              }),
              _buildDropdown('Стоимость ингредиентов', costs, _selectedCost,
                  (value) {
                setState(() {
                  _selectedCost = value;
                  Provider.of<AppState>(context, listen: false)
                      .setSelectedCost(value!);
                });
              }),
              _buildDropdown('Сезонные рецепты', seasons, _selectedSeason,
                  (value) {
                setState(() {
                  _selectedSeason = value;
                  Provider.of<AppState>(context, listen: false)
                      .setSelectedSeason(value!);
                });
              }),
              _buildDropdown('Способ приготовления', cookingMethods,
                  _selectedCookingMethod, (value) {
                setState(() {
                  _selectedCookingMethod = value;
                  Provider.of<AppState>(context, listen: false)
                      .setSelectedCookingMethod(value!);
                });
              }),
              TextField(
                controller: _preferencesController,
                decoration: InputDecoration(
                  labelText: 'Предпочтения',
                  hintText: 'Например, без глютена, кето, низкокалорийные',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: Colors.purple),
                  ),
                ),
                onChanged: (value) {
                  Provider.of<AppState>(context, listen: false).setPreferences(
                      value); // Обновление предпочтений в AppState
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                // Кнопка для добавления ингредиентов
                onPressed: () {
                  _showIngredientsDialog(
                      context); // Вызов диалогового окна для ввода ингредиентов
                },
                child: Text('Ингредиенты'),
              ),
              SizedBox(height: 20),
              // Раздел "На сколько порций?"
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'На сколько порций?',
                    style: TextStyle(fontSize: 16),
                  ),
                  // Изменение количества людей в AppState
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (Provider.of<AppState>(context, listen: false)
                                  .numberOfPeople >
                              1) {
                            Provider.of<AppState>(context, listen: false)
                                .setNumberOfPeople(Provider.of<AppState>(
                                            context,
                                            listen: false)
                                        .numberOfPeople -
                                    1);
                          }
                        },
                        icon: Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${Provider.of<AppState>(context).numberOfPeople}', // Вывод количества порций
                        style: TextStyle(fontSize: 18),
                      ),
                      IconButton(
                        onPressed: () {
                          Provider.of<AppState>(context, listen: false)
                              .setNumberOfPeople(
                                  Provider.of<AppState>(context, listen: false)
                                          .numberOfPeople +
                                      1);
                        },
                        icon: Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    try {
                      // Переход на экран с результатами поиска
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecipesListScreen(
                            selectedCategory: _selectedCategory,
                            selectedDish: _selectedDish,
                            selectedCuisine: _selectedCuisine,
                            selectedMenu: _selectedMenu,
                            selectedCookingTime: _selectedCookingTime,
                            selectedDifficulty: _selectedDifficulty,
                            selectedCost: _selectedCost,
                            selectedSeason: _selectedSeason,
                            selectedCookingMethod: _selectedCookingMethod,
                            // Новое свойство
                            numberOfPeople: _numberOfPeople,
                            includedIngredients: _includedIngredients,
                            // Добавьте это
                            excludedIngredients: _excludedIngredients,
                            // Добавьте это
                            preferences:
                                _preferencesController.text, // Добавьте это
                          ),
                        ),
                      );
                    } catch (e) {
                      // Отправка сообщения в Telegram при ошибке
                      TelegramHelper.sendTelegramError(
                          "Ошибка на экране поиска: $e");
                    }
                  },
                  child: Text('Найти'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  // Кнопка для сохранения текущего фильтра
                  onPressed: () {
                    try {
                      _showSaveFilterDialog(
                          context); // Вызов диалогового окна для сохранения фильтра
                    } catch (e) {
                      // Отправка сообщения в Telegram при ошибке
                      TelegramHelper.sendTelegramError(
                          "Ошибка при сохранении фильтра: $e");
                    }
                  },
                  child: Text('Сохранить текущий фильтр'),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Сохраненные фильтры',
                style: TextStyle(fontSize: 16),
              ),
              ListView.builder(
                shrinkWrap: true,
                itemCount: ApiData.savedFilters.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(ApiData.savedFilters[index]['name']),
                    subtitle: Text(ApiData.savedFilters[index]['description']),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: Colors.red[400],
                      ),
                      onPressed: () async {
                        try {
                          // Получаем SharedPreferences
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();

                          // Получаем текущий список фильтров
                          List<String> savedFiltersJson =
                              prefs.getStringList('savedFilters') ?? [];

                          // Удаляем фильтр по индексу
                          savedFiltersJson.removeAt(index);

                          // Сохраняем обновленный список
                          await prefs.setStringList(
                              'savedFilters', savedFiltersJson);

                          // Обновляем UI
                          setState(() {
                            ApiData.savedFilters.removeAt(index);
                          });

                          // Показываем сообщение об успешном удалении
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Фильтр удален')),
                          );
                        } catch (e) {
                          TelegramHelper.sendTelegramError(
                              "Ошибка при удалении фильтра: $e");
                        }
                      },
                    ),
                    onTap: () {
                      try {
                        setState(() {
                          // Загрузка значений фильтра в соответствующие переменные
                          _selectedCategory =
                              ApiData.savedFilters[index]['category'];
                          // Обновление списка блюд в соответствии с выбранной категорией
                          currentDishes = dishesByCategory[_selectedCategory] ??
                              defaultDishes;
                          _selectedDish = ApiData.savedFilters[index]['dish'];
                          _selectedCuisine =
                              ApiData.savedFilters[index]['cuisine'];
                          _selectedMenu = ApiData.savedFilters[index]['menu'];
                          _selectedCookingTime =
                              ApiData.savedFilters[index]['cookingTime'];
                          _selectedDifficulty =
                              ApiData.savedFilters[index]['difficulty'];
                          _selectedCost = ApiData.savedFilters[index]['cost'];
                          _selectedSeason =
                              ApiData.savedFilters[index]['season'];
                          _selectedCookingMethod = ApiData.savedFilters[index]
                              ['selectedCookingMethod'];
                          _preferencesController.text =
                              ApiData.savedFilters[index]['preferences'] ?? '';
                          _numberOfPeople = ApiData.savedFilters[index]
                                  ['numberOfPeople'] ??
                              4;

                          // Преобразование List<dynamic> в List<String>
                          _includedIngredients.clear();
                          List<dynamic> included = ApiData.savedFilters[index]
                                  ['includedIngredients'] ??
                              [];
                          _includedIngredients.addAll(
                              included.map((e) => e.toString()).toList());

                          _excludedIngredients.clear();
                          List<dynamic> excluded = ApiData.savedFilters[index]
                                  ['excludedIngredients'] ??
                              [];
                          _excludedIngredients.addAll(
                              excluded.map((e) => e.toString()).toList());

                          // Обновление состояния в AppState
                          Provider.of<AppState>(context, listen: false)
                              .setSelectedCategory(_selectedCategory);
                          Provider.of<AppState>(context, listen: false)
                              .setSelectedDish(_selectedDish);
                          Provider.of<AppState>(context, listen: false)
                              .setSelectedCuisine(_selectedCuisine);
                          Provider.of<AppState>(context, listen: false)
                              .setSelectedMenu(_selectedMenu);
                          Provider.of<AppState>(context, listen: false)
                              .setSelectedCookingTime(_selectedCookingTime);
                          Provider.of<AppState>(context, listen: false)
                              .setSelectedDifficulty(_selectedDifficulty);
                          Provider.of<AppState>(context, listen: false)
                              .setSelectedCost(_selectedCost);
                          Provider.of<AppState>(context, listen: false)
                              .setSelectedSeason(_selectedSeason);
                          Provider.of<AppState>(context, listen: false)
                              .setPreferences(_preferencesController.text);
                          Provider.of<AppState>(context, listen: false)
                              .setNumberOfPeople(_numberOfPeople);
                          Provider.of<AppState>(context, listen: false)
                              .setSelectedCookingMethod(_selectedCookingMethod);
                        });
                      } catch (e) {
                        // Отправка сообщения в Telegram при ошибке
                        TelegramHelper.sendTelegramError(
                            "Ошибка при загрузке сохраненного фильтра: $e");
                        print(
                            "Ошибка при загрузке сохраненного фильтра: $e"); // Добавляем вывод в консоль
                      }
                    },
                  );
                },
              ),

              SizedBox(height: 80),
              // Добавляем дополнительное пространство внизу
            ],
          ),
        ),
      ),
    );
  }

  // Метод для создания выпадающего списка
  Widget _buildCategoryDropdown(String hint, List<String> items,
      String? selectedValue, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.purple),
          ),
        ),
        value: selectedValue,
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // Метод для создания выпадающего списка блюд
  Widget _buildDishDropdown(String hint, List<String> items,
      String? selectedValue, ValueChanged<String?> onChanged) {
    // Убираем дубликаты
    Set<String> uniqueItems = Set<String>.from(items);

    // Проверка, есть ли выбранное значение в уникальных элементах
    if (selectedValue != null && !uniqueItems.contains(selectedValue)) {
      selectedValue =
          null; // если выбранное значение не в списке, сбрасываем его
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.purple),
          ),
        ),
        value: selectedValue,
        items: uniqueItems.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value),
                // Кнопка поиска картинок для блюда
                if (value != 'Любое блюдо' && _selectedDish != value)
                  IconButton(
                    icon: Icon(Icons.image_search, color: Colors.purple),
                    onPressed: () {
                      openImageSearch(context,
                          'https://yandex.ru/images/search?from=tabbar&text=$value');
                    },
                  ),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCuisineDropdown(String hint, List<String> items,
      String? selectedValue, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.purple),
          ),
        ),
        value: selectedValue,
        items: items.toSet().map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value),
                // Кнопка поиска картинок для кухни
                if (value != 'Любая кухня' && _selectedCuisine != value)
                  IconButton(
                    icon: Icon(Icons.image_search, color: Colors.purple),
                    onPressed: () {
                      openImageSearch(context,
                          'https://yandex.ru/images/search?from=tabbar&text=$value кухня');
                    },
                  ),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // Метод для создания выпадающего списка для остальных фильтров
// Метод для создания выпадающего списка для остальных фильтров
  Widget _buildDropdown(String hint, List<String> items, String? selectedValue,
      ValueChanged<String?> onChanged) {
    if (hint == 'Любое меню') {
      return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.white, // Фон выпадающего списка
            ),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelStyle: TextStyle(
                  color: const Color.fromARGB(255, 0, 0, 0),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: Colors.grey.shade600),
                ),
              ),
              style: TextStyle(
                color: const Color.fromARGB(
                    255, 0, 0, 0), // Цвет только для выбранного значения
                fontSize: 16,
              ),
              value: selectedValue,
              items: [
                DropdownMenuItem<String>(
                  value: 'Любое меню',
                  child: Text(
                    'Любое меню',
                    style: TextStyle(
                        color: Colors.grey[800]), // Цвет для пунктов меню
                  ),
                ),
                ...menuGroups.expand((group) => [
                      DropdownMenuItem<String>(
                        enabled: false,
                        child: Text(
                          group.title,
                          style: TextStyle(
                            color: const Color.fromARGB(255, 0, 0, 0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...group.items.map((item) => DropdownMenuItem<String>(
                            value: item,
                            child: Padding(
                              padding: EdgeInsets.only(left: 16.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item,
                                    style: TextStyle(
                                        color: Colors
                                            .black), // Цвет для пунктов меню
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.search), // Ваша иконка
                                    onPressed: () {
                                      // Переход по ссылке на Яндекс
                                      final searchQuery =
                                          Uri.encodeComponent(item);
                                      launch(
                                          'https://yandex.ru/search/?text=$searchQuery');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )),
                      if (group != menuGroups.last)
                        DropdownMenuItem<String>(
                          enabled: false,
                          child: Divider(),
                        ),
                    ]),
              ],
              onChanged: onChanged,
            ),
          ));
    } else {
      // Оставляем оригинальную реализацию для других выпадающих списков
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Colors.purple),
            ),
          ),
          value: selectedValue,
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      );
    }
  }

  // Метод для показа диалогового окна для ввода ингредиентов
  void _showIngredientsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Ингредиенты'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ввод включенных ингредиентов
                    _buildIngredientInput('Включить ингредиенты',
                        _includedIngredients, _includeController, (ingredient) {
                      setState(() {
                        _includedIngredients.add(ingredient);
                      });
                    }, setState),
                    // Ввод исключенных ингредиентов
                    _buildIngredientInput('Исключить ингредиенты',
                        _excludedIngredients, _excludeController, (ingredient) {
                      setState(() {
                        _excludedIngredients.add(ingredient);
                      });
                    }, setState),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      // Очистка списков ингредиентов
                      _includedIngredients.clear();
                      _excludedIngredients.clear();
                    });
                    Navigator.of(context).pop(); // Закрытие диалогового окна
                  },
                  child: Text('Очистить всё'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Закрытие диалогового окна
                  },
                  child: Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSaveFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Сохранить фильтр'),
          content: TextField(
            controller: _filterNameController,
            decoration: InputDecoration(
              labelText: 'Имя фильтра',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Colors.purple),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Отмена сохранения фильтра
              },
              child: Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // 1. Получаем имя фильтра из контроллера
                  String filterName = _filterNameController.text;

                  // 2. Проверяем, что имя фильтра не пустое
                  if (filterName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Имя фильтра не может быть пустым')),
                    );
                    return; // Прерываем выполнение, если имя пустое
                  }

                  // 3. Создаем карту (Map) с данными фильтра
                  Map<String, dynamic> filterData = {
                    'name': filterName, // Название фильтра
                    'description':
                        _generateFilterDescription(), // Описание фильтра
                    'category': _selectedCategory, // Выбранная категория
                    'dish': _selectedDish, // Выбранное блюдо
                    'cuisine': _selectedCuisine, // Выбранная кухня
                    'menu': _selectedMenu, // Выбранное меню
                    'cookingTime':
                        _selectedCookingTime, // Выбранное время приготовления
                    'difficulty': _selectedDifficulty, // Выбранная сложность
                    'cost': _selectedCost, // Выбранная стоимость
                    'season': _selectedSeason, // Выбранный сезон
                    'selectedCookingMethod':
                        _selectedCookingMethod, // Выбранный способ приготовления
                    'preferences': _preferencesController.text, // Предпочтения
                    'numberOfPeople': _numberOfPeople, // Количество порций
                    'includedIngredients':
                        List<String>.from(_includedIngredients),
                    'excludedIngredients':
                        List<String>.from(_excludedIngredients),
                  };

                  // 4. Получаем SharedPreferences instance
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();

                  // 5. Получаем текущий список фильтров из SharedPreferences
                  List<String> savedFiltersJson =
                      prefs.getStringList('savedFilters') ?? [];

                  // 6. Преобразуем карту фильтра в JSON строку
                  String filterJson = jsonEncode(filterData);

                  // 7. Добавляем новую JSON строку в список
                  savedFiltersJson.add(filterJson);

                  // 8. Сохраняем обновленный список в SharedPreferences
                  await prefs.setStringList('savedFilters', savedFiltersJson);

                  // 9. Очищаем поле ввода названия фильтра
                  _filterNameController.clear();

                  // 10. Закрываем диалоговое окно
                  Navigator.of(context).pop();

                  // 11. Обновляем список фильтров
                  _loadSavedFilters();

                  // 12. Показываем сообщение об успешном сохранении
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Фильтр успешно сохранен')),
                  );
                } catch (e) {
                  // Отправка сообщения в Telegram при ошибке
                  TelegramHelper.sendTelegramError(
                      "Ошибка при сохранении фильтра: $e");
                  print(
                      "Ошибка при сохранении фильтра: $e"); // Добавляем вывод в консоль
                }
              },
              child: Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  // Генерация описания фильтра
  String _generateFilterDescription() {
    List<String> parts = [];
    if (_selectedCategory != null) parts.add('Категория: $_selectedCategory');
    if (_selectedDish != null) parts.add('Блюдо: $_selectedDish');
    if (_selectedCuisine != null) parts.add('Кухня: $_selectedCuisine');
    if (_selectedMenu != null) parts.add('Меню: $_selectedMenu');
    if (_selectedCookingTime != null) parts.add('Время: $_selectedCookingTime');
    if (_selectedDifficulty != null) {
      parts.add('Сложность: $_selectedDifficulty');
    }
    if (_selectedCost != null) parts.add('Стоимость: $_selectedCost');
    if (_selectedSeason != null) parts.add('Сезон: $_selectedSeason');
    if (_selectedCookingMethod != null) {
      parts.add('Способ приготовления: $_selectedCookingMethod');
    }
    if (_preferencesController.text.isNotEmpty) {
      parts.add('Предпочтения: ${_preferencesController.text}');
    }
    if (_includedIngredients.isNotEmpty) {
      parts.add('Включенные ингредиенты: ${_includedIngredients.join(', ')}');
    }
    if (_excludedIngredients.isNotEmpty) {
      parts.add('Исключенные ингредиенты: ${_excludedIngredients.join(', ')}');
    }
    return parts.join(', '); // Возвращение сформированного описания
  }

  // Метод для создания виджета ввода ингредиентов
  Widget _buildIngredientInput(
      String label,
      List<String> ingredients,
      TextEditingController controller,
      Function(String) onAdd,
      StateSetter dialogSetState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: label.contains('Включить')
                      ? '+ Ингредиент'
                      : '- Ингредиент',
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  onAdd(controller.text); // Добавление ингредиента в список
                  controller.clear(); // Очистка поля ввода
                }
              },
            ),
          ],
        ),
        Wrap(
          spacing: 8.0,
          children: ingredients.map((ingredient) {
            return Chip(
              label: Text(ingredient),
              onDeleted: () {
                dialogSetState(() {
                  ingredients
                      .remove(ingredient); // Удаление ингредиента из списка
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
