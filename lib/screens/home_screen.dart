// lib/screens/home_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../utils/myrouteobserver.dart';
import '../utils/telegram_helper.dart';
import 'recipe_search_screen.dart';
import 'favorites_screen.dart';
import 'shopping_list_screen.dart';
import 'recipes_list_screen.dart';
import 'recipe_detail_screen.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) async {
            if (didPop) {
              return;
            }
            if (appState.navigatorKey.currentState != null &&
                appState.navigatorKey.currentState!.canPop()) {
              appState.navigatorKey.currentState!.pop();
            } else {
              // Закрытие приложения, если это корневой экран
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            body: Stack(
              children: [
                CustomNavigator(), // Виджет для навигации по экранам приложения
                Align(
                  alignment: Alignment.bottomCenter,
                  child: BottomNavBar(), // Виджет нижней панели навигации
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CustomNavigator extends StatelessWidget {
  const CustomNavigator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Navigator(
          key: appState.navigatorKey, // Ключ для управления навигацией
          initialRoute: '/', // Начальный маршрут
          observers: <NavigatorObserver>[
            MyRouteObserver(), // this will listen all changes
          ],
          onGenerateRoute: (RouteSettings settings) {
            return _generateRoute(settings, appState);
          },
        );
      },
    );
  }

  Route<dynamic> _generateRoute(RouteSettings settings, AppState appState) {
    try {
      WidgetBuilder builder;
      switch (settings.name) {
        case '/':
          builder = (BuildContext context) => RecipeSearchScreen();
          break;
        case '/favorites':
          builder = (BuildContext context) => FavoritesScreen();
          break;
        case '/shopping_list':
          builder = (BuildContext context) => ShoppingListScreen();
          break;
        case '/recipes_list':
          builder = (BuildContext context) => RecipesListScreen(
                selectedCategory: appState.selectedCategory,
                selectedDish: appState.selectedDish,
                selectedCuisine: appState.selectedCuisine,
                selectedMenu: appState.selectedMenu,
                selectedCookingTime: appState.selectedCookingTime,
                selectedDifficulty: appState.selectedDifficulty,
                selectedCost: appState.selectedCost,
                selectedSeason: appState.selectedSeason,
                selectedCookingMethod: appState.selectedCookingMethod,
                numberOfPeople: appState.numberOfPeople,
                includedIngredients: appState.includedIngredients,
                excludedIngredients: appState.excludedIngredients,
                preferences: appState.preferences ?? '',
              );
          break;
        case '/recipe_detail':
          final recipe = settings.arguments as String;
          builder = (BuildContext context) => RecipeDetailScreen(recipe: recipe);
          break;
        default:
          throw Exception('Invalid route: ${settings.name}');
      }
      return MaterialPageRoute(builder: builder, settings: settings);
    } catch (e) {
      return _handleError(settings, e);
    }
  }

  Route<dynamic> _handleError(RouteSettings settings, Object e) {
    if (kDebugMode) {
      print("Error generating route: ${settings.name}, Error: $e");
    }
    TelegramHelper.sendTelegramError(
        "Error generating route: ${settings.name}, Error: $e");
    return MaterialPageRoute(
      builder: (context) => const Scaffold(
        body: Center(child: Text('Error: Invalid route')),
      ),
    );
  }
}

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return BottomNavigationBar(
          currentIndex: appState.selectedIndex,
          onTap: (index) {
            _onTap(index, appState);
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.grey[600],
          unselectedItemColor: Colors.grey[600],
          selectedIconTheme: IconThemeData(
            color: Colors.grey[600],
            size: 24,
          ),
          unselectedIconTheme: IconThemeData(
            color: Colors.grey[600],
            size: 24,
          ),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          enableFeedback: false,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Поиск',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Избранное',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Список покупок',
            ),
          ],
        );
      },
    );
  }

void _onTap(int index, AppState appState) {
  try {
    appState.setSelectedIndex(index);
    const routes = ['/', '/favorites', '/shopping_list'];
    if (index < routes.length) {
      appState.navigatorKey.currentState?.pushNamed(routes[index]);
    }
  } catch (e) {
    print("Error navigating to index $index: $e");
    TelegramHelper.sendTelegramError("Error navigating to index $index: $e");
  }
}
}
