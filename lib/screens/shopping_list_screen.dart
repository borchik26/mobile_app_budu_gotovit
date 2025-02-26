// Общий смысл кода:
// ShoppingListScreen - это экран, который позволяет пользователю управлять списком покупок. Пользователь может добавлять продукты в список вручную или с помощью голосовой диктовки, отмечать продукты как завершенные, редактировать или удалять продукты, а также очистить весь список.
// Список покупок сохраняется в SharedPreferences, чтобы данные не терялись при перезапуске приложения.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/launch.dart';
import '../utils/telegram_helper.dart'; // Импортируем TelegramHelper
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../utils/share_shopping_list.dart';





class ShoppingListScreen extends StatefulWidget {
  @override
  _ShoppingListScreenState createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  // Списки покупок (активный и завершенный)
  final List<String> _shoppingList = [];
  final List<String> _completedList = [];

  // Контроллеры для ввода текста и фокусировки
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Переменные для управления голосовой диктовкой
  late stt.SpeechToText _speech;
  bool _isListening = false; // Флаг, указывающий на включенную диктовку
  String _lastWords = ''; // Последние распознанные слова
  String _previousWords = ''; // Предыдущие распознанные слова
  bool _speechEnabled = false; // Флаг, указывающий на доступность диктовки
  bool _showHint =
      true; // Флаг, указывающий на показ подсказки при первом запуске диктовки

  // Инициализация состояния
  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech(); // Инициализация диктовки
    _loadShoppingList(); // Загрузка списка покупок из SharedPreferences
    _loadShowHint(); // Загрузка флага показа подсказки

    // Обработка изменения фокуса текстового поля
    _textFieldFocusNode.addListener(() {
      if (!_textFieldFocusNode.hasFocus) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  // Инициализация диктовки
  void _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      setState(() {});
    } catch (e) {
      // Отправка сообщения в Telegram при ошибке
      TelegramHelper.sendTelegramError("Ошибка инициализации SpeechToText: $e");
    }
  }

  // Добавление одного продукта в список
  void _addProduct(String product) {
    if (product.isNotEmpty) {
      setState(() {
        _shoppingList.add(product);
        _scrollToBottom(); // Прокрутка к нижней части списка
      });
      _saveShoppingList(); // Сохранение списка покупок в SharedPreferences
      _textController.clear(); // Очистка текстового поля
    }
  }

  // Добавление нескольких продуктов из строки
  void _addProducts(String products) {
    // Разделение строки по запятой и слову "и"
    List<String> productList = products.split(RegExp(r',\s*|(?<!\S)и\s*'));
    setState(() {
      for (String product in productList) {
        if (product.isNotEmpty) {
          _shoppingList.add(product.trim());
        }
      }
    });
    _saveShoppingList(); // Сохранение списка покупок в SharedPreferences
    _textController.clear(); // Очистка текстового поля
  }

  // Прокрутка к нижней части списка
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Перемещение продукта между списками (активный / завершенный)
  void _toggleProductCompletion(int index) {
    setState(() {
      if (index < _shoppingList.length) {
        // Перемещение из активного списка в завершенный (в начало)
        String item = _shoppingList.removeAt(index);
        _completedList.insert(
            0, item); // Добавление в начало завершенного списка
      } else {
        // Перемещение из завершенного списка обратно в активный
        int completedIndex = index - _shoppingList.length;
        String item = _completedList.removeAt(completedIndex);
        _shoppingList.add(item); // Добавление в конец активного списка
      }
    });
    _saveShoppingList(); // Сохранение списка покупок в SharedPreferences
  }

  // Редактирование продукта
  void _editProduct(int index) {
    final isCompleted = index >=
        _shoppingList.length; // Проверка, в каком списке находится продукт
    final String item = isCompleted
        ? _completedList[index - _shoppingList.length]
        : _shoppingList[index];

    // Создание контроллера для текстового поля для редактирования
    TextEditingController editController = TextEditingController(text: item);

    // Отображение диалогового окна для редактирования
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Редактировать продукт'),
        content: TextField(
          controller: editController,
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Сохранение изменений и закрытие диалогового окна
              setState(() {
                if (isCompleted) {
                  _completedList[index - _shoppingList.length] =
                      editController.text;
                } else {
                  _shoppingList[index] = editController.text;
                }
                _saveShoppingList();
              });
              Navigator.of(context).pop();
            },
            child: Text('Сохранить'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Закрытие диалогового окна
            },
            child: Text('Отмена'),
          ),
        ],
      ),
    );
  }

  // Удаление продукта из списка
  void _removeProduct(int index) {
    // Снятие фокуса с текстового поля
    FocusScope.of(context).unfocus();

    setState(() {
      if (index < _shoppingList.length) {
        _shoppingList.removeAt(index); // Удаление из активного списка
      } else {
        int completedIndex = index - _shoppingList.length;
        _completedList
            .removeAt(completedIndex); // Удаление из завершенного списка
      }
    });
    _saveShoppingList(); // Сохранение списка покупок в SharedPreferences
  }

  // Очистка списков
  void _clearList() {
    setState(() {
      _shoppingList.clear();
      _completedList.clear();
    });
    _saveShoppingList(); // Сохранение пустого списка в SharedPreferences
  }

  // Запуск прослушивания голосовой диктовки
  void _startListening() async {
    if (_speechEnabled && !_isListening) {
      if (_showHint) {
        _showHintDialog(); // Отображение подсказки при первом запуске диктовки
      } else {
        _startSpeechToText(); // Запуск диктовки
      }
    }
  }

  // Запуск диктовки
  void _startSpeechToText() async {
    try {
      await _speech.listen(
        // Обработка результата диктовки
        onResult: (val) => setState(() {
          _lastWords = val.recognizedWords;
          if (_lastWords != _previousWords && val.finalResult) {
            _addProducts(
                _lastWords); // Добавление распознанных продуктов в список
            _previousWords = _lastWords; // Обновление предыдущих слов
          }
        }),
        // Параметры диктовки
        listenFor: Duration(seconds: 120),
        pauseFor: Duration(seconds: 5),
        onSoundLevelChange: (val) => setState(() {}),
        cancelOnError: true,
        partialResults: true,
      );
      setState(() {
        _isListening =
            true; // Установка флага, указывающего на включенную диктовку
      });
    } catch (e) {
      // Отправка сообщения в Telegram при ошибке
      TelegramHelper.sendTelegramError("Ошибка при запуске прослушивания: $e");
    }
  }

  // Остановка прослушивания голосовой диктовки
  void _stopListening() async {
    if (_isListening) {
      try {
        await _speech.stop();
        setState(() {
          _isListening =
              false; // Сброс флага, указывающего на включенную диктовку
        });
        _lastWords = '';
        _previousWords = '';
      } catch (e) {
        // Отправка сообщения в Telegram при ошибке
        TelegramHelper.sendTelegramError(
            "Ошибка при остановке прослушивания: $e");
      }
    }
  }

  // Сохранение списка покупок в SharedPreferences
  void _saveShoppingList() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setStringList('shoppingList', _shoppingList);
      prefs.setStringList('completedList', _completedList);
    } catch (e) {
      // Отправка сообщения в Telegram при ошибке
      TelegramHelper.sendTelegramError(
          "Ошибка при сохранении списка покупок: $e");
    }
  }

  // Загрузка списка покупок из SharedPreferences
  void _loadShoppingList() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _shoppingList.addAll(prefs.getStringList('shoppingList') ?? []);
        _completedList.addAll(prefs.getStringList('completedList') ?? []);
      });
    } catch (e) {
      // Отправка сообщения в Telegram при ошибке
      TelegramHelper.sendTelegramError(
          "Ошибка при загрузке списка покупок: $e");
    }
  }

  // Сохранение флага показа подсказки в SharedPreferences
  void _saveShowHint() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool('showHint', _showHint);
    } catch (e) {
      // Отправка сообщения в Telegram при ошибке
      TelegramHelper.sendTelegramError("Ошибка при сохранении подсказки: $e");
    }
  }

  // Загрузка флага показа подсказки из SharedPreferences
  void _loadShowHint() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _showHint = prefs.getBool('showHint') ?? true;
      });
    } catch (e) {
      // Отправка сообщения в Telegram при ошибке
      TelegramHelper.sendTelegramError("Ошибка при загрузке подсказки: $e");
    }
  }

  // Отображение подсказки при первом запуске диктовки
  void _showHintDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Подсказка'),
        content: Text(
            'При диктовке вы можете разделять продукты произнося «запятая» или союз «и». Чтобы завершить запись, нажмите на ту же кнопку в конце.'),
        actions: [
          TextButton(
            onPressed: () {
              // Скрытие подсказки и запуск диктовки
              setState(() {
                _showHint = false;
              });
              _saveShowHint(); // Сохранение флага показа подсказки
              Navigator.of(context).pop();
              _startSpeechToText();
            },
            child: Text('Больше не показывать'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Закрытие диалогового окна
              _startSpeechToText();
            },
            child: Text('ОК'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Получаем данные из ApiData для отображения промокодов
    final promoCodes = Provider.of<ApiData>(context).promoCodes;
    return Scaffold(
      appBar: AppBar(
        title: Text('Список покупок'),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () =>
                ShareHelper.shareShoppingList(_shoppingList, _completedList),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _clearList,
          ),
        ],
      ),
      body: Column(
        // Основной столбец виджета
        children: [
          Expanded(
            // Занимает всю доступную высоту
            child: ListView.builder(
              // Список для отображения продуктов
              controller: _scrollController,
              itemCount: _shoppingList.length + _completedList.length,
              // Количество элементов в списке
              itemBuilder: (context, index) {
                // Проверяем, в каком списке находится продукт (активный / завершенный)
                final bool isCompleted = index >= _shoppingList.length;
                final String item = isCompleted
                    ? _completedList[index - _shoppingList.length]
                    : _shoppingList[index];
                // Элемент списка с возможностью переключения состояния продукта
                return GestureDetector(
                  onTap: () => _toggleProductCompletion(index),
                  child: ListTile(
                    // Анимация изменения состояния (прочеркивание при завершении)
                    title: AnimatedCrossFade(
                      firstChild: Text(
                        item,
                        style: TextStyle(
                          decoration: TextDecoration.none,
                          color: Colors.black, // Normal color
                        ),
                      ),
                      secondChild: Text(
                        item,
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.black.withOpacity(0.5), // Dimmed color
                        ),
                      ),
                      crossFadeState: isCompleted
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: Duration(milliseconds: 300),
                    ),
                    // Кнопки управления продуктом (изменение, удаление)
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Кнопка для отображения промокодов и ссылок на сервисы доставки
                        PopupMenuButton<String>(
                          icon: Container(
                            // Виджет для отображения кнопки
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            color: Colors.green,
                            child: Center(
                              child: Text(
                                'BB',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // Обработчик выбора сервиса доставки или промокода
                          onSelected: (String url) {
                            try {
                              final cleanedItem = item
                                  .replaceAll(RegExp(r'\(.*?\)'), '')
                                  .trim();
                              launchInBrowser(
                                  url, cleanedItem); // Запуск браузера
                            } catch (e) {
                              // Отправка сообщения в Telegram при ошибке
                              TelegramHelper.sendTelegramError(
                                  "Ошибка при открытии сервиса доставки: $e");
                            }
                          },
                          // Элементы меню (сервисы доставки и промокоды)
                          itemBuilder: (BuildContext context) {
                            return [
                              // Заголовок для разделения сервисов доставки и промокодов
                              PopupMenuItem<String>(
                                enabled: false,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Сервисы доставки',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Промокоды',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              // Разделитель между заголовком и элементами
                              PopupMenuDivider(height: 10),
                              // Ссылки на сервисы доставки и промокоды
                              ...promoCodes.keys.map((url) {
                                final name = promoCodes[url]!['name']!;
                                final promoCode = promoCodes[url]!['code']!;
                                // Сокращение промокода для удобства отображения
                                final truncatedPromoCode = promoCode.length > 3
                                    ? '${promoCode.substring(0, 3)}...'
                                    : promoCode;
                                return PopupMenuItem<String>(
                                  value: url,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          // Виджет для отображения иконки сервиса доставки
                                          CachedNetworkImage(
                                            imageUrl:
                                                'https://www.google.com/s2/favicons?domain=${Uri.parse(url).host}',
                                            width: 24,
                                            height: 24,
                                            // Placeholder для отображения до загрузки изображения
                                            placeholder: (context, url) =>
                                                Container(),
                                            errorWidget: (context, url,
                                                    error) =>
                                                Icon(Icons
                                                    .error), // Виджет ошибки загрузки
                                          ),
                                          SizedBox(width: 8),
                                          Text(name),
                                          // Отображение названия сервиса доставки
                                        ],
                                      ),
                                      // Кнопка для копирования промокода
                                      TextButton(
                                        onPressed: () {
                                          Clipboard.setData(
                                              ClipboardData(text: promoCode));
                                          // Вывод сообщения об успешном копировании
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Промокод "$promoCode" скопирован'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        // Отображение промокода
                                        child: Text(
                                          truncatedPromoCode,
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize:
                                                12, // Smaller font size for promo code
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ];
                          },
                          elevation:
                              0.0, // Убираем тень для минимизации анимации
                        ),
                        // Кнопки для дополнительных действий (изменение, удаление)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert),
                          // Обработчик выбора действия
                          onSelected: (String value) {
                            if (value == 'edit') {
                              _editProduct(index); // Редактирование продукта
                            } else if (value == 'delete') {
                              _removeProduct(index); // Удаление продукта
                            }
                          },
                          // Элементы меню для дополнительных действий
                          itemBuilder: (BuildContext context) {
                            return [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Изменить'),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Удалить'),
                              ),
                            ];
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              // Строка для ввода продукта и кнопок
              children: [
                Expanded(
                  child: TextField(
                    // Текстовое поле для ввода продукта
                    controller: _textController,
                    focusNode: _textFieldFocusNode,
                    // Фокус для текстового поля
                    decoration: InputDecoration(
                      labelText: 'Добавить продукт(ы)', // Подсказка для ввода
                    ),
                    // Обработчик ввода продукта (по завершению ввода)
                    onSubmitted: (value) {
                      try {
                        _addProducts(value); // Добавление продуктов в список
                        _textController.clear(); // Очистка текстового поля
                        _textFieldFocusNode.requestFocus(); // Возврат фокуса
                      } catch (e) {
                        // Отправка сообщения в Telegram при ошибке
                        TelegramHelper.sendTelegramError(
                            "Ошибка при добавлении продуктов: $e");
                      }
                    },
                  ),
                ),
                // Кнопка добавления продукта
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    try {
                      _addProducts(_textController
                          .text); // Добавление продуктов в список
                      _textController.clear(); // Очистка текстового поля
                      _textFieldFocusNode.requestFocus(); // Возврат фокуса
                      FocusScope.of(context)
                          .unfocus(); // Скрыть клавиатуру и убрать фокус
                    } catch (e) {
                      // Отправка сообщения в Telegram при ошибке
                      TelegramHelper.sendTelegramError(
                          "Ошибка при добавлении продуктов: $e");
                    }
                  },
                ),
                // Кнопка для включения/отключения голосовой диктовки
                IconButton(
                  icon:
                      Icon(_isListening ? Icons.record_voice_over : Icons.mic),
                  // Микрофон или микрофон с записью
                  onPressed: () {
                    if (_isListening) {
                      _stopListening(); // Остановка диктовки
                    } else {
                      _startListening(); // Запуск диктовки
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
