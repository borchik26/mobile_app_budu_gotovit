// Общий смысл кода:
// Этот файл содержит два класса, которые используются для хранения API данных и состояния приложения:
// ApiData хранит информацию о прокси-сервере, API ключе, промокодах и ссылках на сервисы доставки.
// AppState хранит информацию о выбранном экране, фильтрах для поиска рецептов, а также количество людей, для которых готовятся блюда.
// Классы ApiData и AppState используют ChangeNotifier для уведомления слушателей об изменениях своих данных, что позволяет обновлять UI приложения в соответствии с изменениями состояния.



import 'package:flutter/material.dart';

// Класс для хранения API данных (proxy, API ключ, промокоды, ссылки на сервисы доставки)
class ApiData with ChangeNotifier {
  String? _proxy; // Прокси-сервер
  String? _apiKey; // API ключ
  Map<String, Map<String, String>> _promoCodes = {}; // Промокоды
  Map<String, Map<String, String>> _orderLinks = {}; // Ссылки на сервисы доставки
  // Список сохраненных фильтров
  static List<Map<String, dynamic>> savedFilters = [];
  final TextEditingController recipeNameController = TextEditingController();


  // Геттеры для доступа к приватным полям
  String? get proxy => _proxy;
  String? get apiKey => _apiKey;
  Map<String, Map<String, String>> get promoCodes => _promoCodes;
  Map<String, Map<String, String>> get orderLinks => _orderLinks;

  // Метод для установки API данных
  void setApiData(
      String proxy,
      String apiKey,
      Map<String, Map<String, String>> promoCodes,
      Map<String, Map<String, String>> orderLinks) {
    _proxy = proxy;
    _apiKey = apiKey;
    _promoCodes = promoCodes;
    _orderLinks = orderLinks;
    notifyListeners(); // Уведомление слушателей об изменениях
  }
}

// Класс для хранения состояния приложения (выбранный экран, фильтры, количество людей)
class AppState extends ChangeNotifier {
  int _selectedIndex = 0; // Индекс выбранного экрана
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>(); // Ключ для управления навигацией

  // Список включенных и исключенных ингредиентов
  List<String> _includedIngredients = [];
  List<String> _excludedIngredients = [];

  // Свойства для хранения выбранных фильтров
  String? _selectedCategory;
  String? _selectedDish;
  String? _selectedCuisine;
  String? _selectedMenu;
  String? _selectedCookingTime;
  String? _selectedDifficulty;
  String? _selectedCost;
  String? _selectedSeason;
  String? _selectedCookingMethod;
  String? _preferences; // Предпочтения пользователя
  int _numberOfPeople = 4; // Количество человек

  // Геттеры для доступа к приватным полям
  int get selectedIndex => _selectedIndex;
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;
  String? get selectedCategory => _selectedCategory;
  String? get selectedDish => _selectedDish;
  String? get selectedCuisine => _selectedCuisine;
  String? get selectedMenu => _selectedMenu;
  String? get selectedCookingTime => _selectedCookingTime;
  String? get selectedDifficulty => _selectedDifficulty;
  String? get selectedCost => _selectedCost;
  String? get selectedSeason => _selectedSeason;
  String? get selectedCookingMethod => _selectedCookingMethod;
  String? get preferences => _preferences;
  int get numberOfPeople => _numberOfPeople;
  List<String> get includedIngredients => _includedIngredients;
  List<String> get excludedIngredients => _excludedIngredients;

  // Сеттеры для изменения приватных полей
  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  void setSelectedDish(String? dish) {
    _selectedDish = dish;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  void setSelectedCuisine(String? cuisine) {
    _selectedCuisine = cuisine;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  void setSelectedMenu(String? menu) {
    _selectedMenu = menu;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  void setSelectedCookingTime(String? cookingTime) {
    _selectedCookingTime = cookingTime;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  void setSelectedDifficulty(String? difficulty) {
    _selectedDifficulty = difficulty;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  void setSelectedCost(String? cost) {
    _selectedCost = cost;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  void setSelectedSeason(String? season) {
    _selectedSeason = season;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  void setSelectedCookingMethod(String? method) {
    _selectedCookingMethod = method;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  void setPreferences(String? preferences) {
    _preferences = preferences;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  void setNumberOfPeople(int number) {
    _numberOfPeople = number;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  void setIncludedIngredients(List<String> ingredients) {
    _includedIngredients = ingredients;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  void setExcludedIngredients(List<String> ingredients) {
    _excludedIngredients = ingredients;
    notifyListeners(); // Уведомление слушателей об изменениях
  }

  // Метод для выполнения поиска рецептов
  void performRecipeSearch() {
    setSelectedIndex(3); // Переход на экран "Рецепты"
    navigatorKey.currentState?.pushReplacementNamed('/'); // Переключение вкладок
    notifyListeners(); // Уведомление слушателей об изменениях
  }
}
