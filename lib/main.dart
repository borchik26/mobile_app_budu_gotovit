// Путь к файлу /Users/vladlyulin/Developer/project/рецепты/беха/recepti/lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sborka/utils/myrouteobserver.dart';
import 'models/app_state.dart';
import 'screens/home_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils/telegram_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiData = ApiData();
  try {
    await initializeApiData(apiData);
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => apiData),
          ChangeNotifierProvider(create: (context) => AppState()),
        ],
        child: MyApp(),
      ),
    );
  } catch (e) {
    // Логирование ошибки и отправка уведомления в Telegram
    print("Ошибка при инициализации приложения: $e");
    await TelegramHelper.sendTelegramError(
        "Ошибка при инициализации приложения: $e");
  }
}

// Загрузка API данных, включая proxy, API ключ, промокоды и ссылки на сервисы доставки
Future<void> initializeApiData(ApiData apiData) async {
  try {
    final url =
        Uri.parse('https://functions.yandexcloud.net/d4e5ht4ojjbkp9ktbe9v');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Преобразование данных из JSON в соответствующие структуры
      final promoCodes = (data['promo_codes'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          (value as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, v as String),
          ),
        ),
      );

      final orderLinks = (data['order_links'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          (value as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, v as String),
          ),
        ),
      );
      // Установка загруженных данных в ApiData
      apiData.setApiData(
          data['proxy'], data['api_key'], promoCodes, orderLinks);
    } else {
      throw Exception('Не удалось загрузить proxy и API ключ');
    }
  } catch (e) {
    print("Ошибка при загрузке API данных: $e");
    await TelegramHelper.sendTelegramError(
        "Ошибка при загрузке API данных: $e");
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recipe App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      navigatorObservers: <NavigatorObserver>[
        MyRouteObserver(),
      ],
      home: HomeScreen(),
      // Добавляем обработчик для Android back button
      builder: (context, child) {
        return WillPopScope(
          onWillPop: () async {
            // Проверяем возможность возврата
            final canPop = Navigator.of(context).canPop();
            if (canPop) {
              Navigator.of(context).pop();
            }
            return !canPop; // Возвращаем false, если не можем вернуться назад
          },
          child: child!,
        );
      },
    );
  }
}
