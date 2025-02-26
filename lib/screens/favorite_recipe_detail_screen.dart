import 'package:flutter/material.dart';
import '../utils/order_menu_utils.dart'; // Импортируем утилиту для отображения меню заказа
import '../utils/launch.dart'; // Импортируем утилиты для запуска внешних приложений
import '../utils/add_to_shopping_list.dart'; // Импортируем утилиту для добавления ингредиентов в список покупок
import '../utils/share_recipe.dart'; // Импортируем утилиту для обмена рецептом

class FavoriteRecipeDetailScreen extends StatelessWidget {
  final Map<String, String> recipe; // Хранит данные о рецепте

  const FavoriteRecipeDetailScreen({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(''), // Заголовок экрана - название рецепта
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              recipe['title']!, // Вывод названия рецепта
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            ElevatedButton.icon(
              icon: Icon(Icons.add_shopping_cart), // Кнопка для добавления ингредиентов в список покупок
              label: Text('Добавить ингредиенты в список покупок'),
              onPressed: () => addToShoppingList(context, recipe), // Вызов функции addToShoppingList для добавления ингредиентов в список покупок
            ),
            const SizedBox(height: 16.0),
            Text(
              recipe['details']!, // Вывод подробного описания рецепта
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.video_library),
                    label: Text('YouTube'),
                    onPressed: () => launchYouTube(context, recipe['title']!),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.video_library),
                    label: Text('Rutube'),
                    onPressed: () => launchRutube(context, recipe['title']!),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.video_library),
                    label: Text('VK Видео'),
                    onPressed: () => launchVkvideo(context, recipe['title']!),
                  ),
                ],
              ),
            const SizedBox(height: 16.0),
            if (recipe['hasImages'] == 'true')
              Center(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.image),
                  label: Text('Картинки блюда'),
                  onPressed: () => launchYandexImages(context, recipe['title']!),
                ),
              ),
            const SizedBox(height: 16.0),
            if (recipe['canShare'] == 'true')
              Center(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.share),
                  label: Text('Поделиться'),
                  onPressed: () => shareRecipe(context, recipe),
                ),
              ),
            const SizedBox(height: 16.0),
            if (recipe['canOrder'] == 'true')
              Center(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.local_restaurant),
                  label: Text('Заказать готовое блюдо'),
                  onPressed: () => showOrderMenu(context, recipe),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}