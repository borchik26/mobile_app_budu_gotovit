import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyRouteObserver extends RouteObserver {

void saveLastRoute(Route? lastRoute) async {
  // Проверяем, что lastRoute не равен null и у него есть свойство settings.name
  if (lastRoute?.settings.name != null) {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('last_route', lastRoute!.settings.name!); // безопасно обращаемся к settings.name
  }
}



  @override
  void didPop(Route? route, Route? previousRoute) {
    saveLastRoute(previousRoute); // note : take route name in stacks below
    super.didPop(route!, previousRoute);
  }

  @override
  void didPush(Route? route, Route? previousRoute) {
    saveLastRoute(route); // note : take new route name that just pushed
    super.didPush(route!, previousRoute);
  }

  @override
  void didRemove(Route? route, Route? previousRoute) {
    saveLastRoute(route);
    super.didRemove(route!, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    saveLastRoute(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}