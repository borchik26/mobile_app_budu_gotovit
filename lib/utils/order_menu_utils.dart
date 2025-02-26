// Общий смысл кода:
// showOrderMenu - это функция, которая отображает контекстное меню с ссылками на сервисы доставки для заказа готового блюда.
// Меню получает данные о сервисах доставки из AppState и позволяет пользователю скопировать промокод для выбранного сервиса или открыть ссылку на сервис доставки в браузере.




import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import 'launch.dart';

// Функция для отображения меню заказа
void showOrderMenu(BuildContext context, Map<String, String> recipe) {
  final orderLinks = Provider.of<ApiData>(context, listen: false).orderLinks; // Получение списка ссылок на сервисы доставки из AppState

  showModalBottomSheet( // Отображение контекстного меню
    context: context,
    builder: (context) {
      return Column(
        children: [
          ListTile( // Заголовок меню
            title: Text('Сервисы доставки', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Divider(), // Разделитель
          // Создание списка элементов меню (сервисы доставки)
          ...orderLinks.keys.map((url) {
            final name = orderLinks[url]!['name']!; // Название сервиса доставки
            final promoCode = orderLinks[url]!['code']!; // Промокод для сервиса доставки
            final product = recipe['title'] ?? ''; // Название блюда

            return ListTile(
              leading: CachedNetworkImage( // Виджет для загрузки иконки сервиса доставки
                imageUrl: 'https://www.google.com/s2/favicons?domain=${Uri.parse(url).host}',
                width: 24,
                height: 24,
                placeholder: (context, url) => Container(), // Placeholder для отображения до загрузки
                errorWidget: (context, url, error) => Icon(Icons.error), // Виджет ошибки загрузки
              ),
              title: Text(name), // Отображение названия сервиса доставки
              trailing: TextButton( // Кнопка для копирования промокода
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: promoCode)); // Копирование промокода в буфер обмена
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar( // Вывод сообщения об успешном копировании
                      content: Text('Промокод "$promoCode" скопирован'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(
                  promoCode,
                  style: TextStyle(color: Colors.blue, fontSize: 12),
                ),
              ),
              onTap: () {
                launchInBrowser(url, product); // Открытие ссылки на сервис доставки в браузере
                Navigator.pop(context); // Закрытие контекстного меню
              },
            );
          }).toList(), // Создание списка элементов меню из полученных данных
        ],
      );
    },
  );
}