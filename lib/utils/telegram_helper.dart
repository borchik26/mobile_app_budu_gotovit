import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io'; // Import for Platform
import 'package:logger/logger.dart'; // Import logger package
import 'package:path/path.dart';  // Для получения имени файла
import 'package:http_parser/http_parser.dart';  // Для указания MIME-типа

class TelegramHelper {
  // Токен бота Telegram
  static const String _telegramBotToken =
      "7247841674:AAF0jSv8q6aOdkzCKwpI9nDtm7xnwDoLwrE";  // Замените YOUR_TELEGRAM_BOT_TOKEN на свой токен
  // ID чата, куда будут отправляться сообщения
  static const int _telegramChatId = 346967554; // Замените YOUR_TELEGRAM_CHAT_ID на ID своего чата
  // Экземпляр логгера для записи ошибок
  static final Logger _logger = Logger();

  // Статическая функция для отправки сообщения об ошибке в Telegram
  static Future<void> sendTelegramError(String errorMessage, {File? image}) async {
    try {
      // Получение информации об устройстве
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      Map<String, dynamic> deviceData = {};

      if (Platform.isAndroid) {
        deviceData = (await deviceInfo.androidInfo).toMap();
      } else if (Platform.isIOS) {
        deviceData = (await deviceInfo.iosInfo).toMap();
      } else {
        deviceData = {"platform": "Unknown"};
      }

      // Формирование строки с информацией об устройстве
      String deviceInfoString =
          "Device: ${deviceData["model"]} (${deviceData["manufacturer"]}), OS: ${deviceData["systemVersion"]}";

      // Формирование сообщения для отправки
      String message = 'Ошибка в приложении: $errorMessage\n'
          'Информация об устройстве:\n'
          '$deviceInfoString';

      // Отправка сообщения и изображения в Telegram
      await _sendTelegram(message, image: image);

    } catch (e) {
      // Запись ошибки в логгер
      _logger.e("Ошибка отправки сообщения в Telegram: $e");
    }
  }

  // Вспомогательная функция для отправки сообщения и изображения в Telegram
  static Future<void> _sendTelegram(String message, {File? image}) async {
    var url = Uri.parse('https://api.telegram.org/bot$_telegramBotToken/sendPhoto'); // Используем sendPhoto для отправки фотографий
    var request = http.MultipartRequest('POST', url)
      ..fields['chat_id'] = _telegramChatId.toString()
      ..fields['caption'] = message;

    if (image != null) {
      // Добавляем файл изображения к запросу
      String fileName = basename(image.path);  // Получаем имя файла
      String? mimeType;

      // Определение MIME-типа на основе расширения файла (базово)
      if (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (fileName.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else {
        mimeType = 'image/jpeg'; // Default to jpeg if type is unknown
        _logger.w("Unknown image type for file: $fileName. Defaulting to image/jpeg."); // Предупреждение о неизвестном типе файла
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',  // Ключ для файла должен быть 'photo' для sendPhoto
          image.path,
          filename: fileName,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,  // Укажем MIME тип
        ),
      );
    } else {
      // Если изображения нет, отправляем обычное текстовое сообщение
      url = Uri.parse('https://api.telegram.org/bot$_telegramBotToken/sendMessage'); // Возвращаемся к sendMessage
      request = http.MultipartRequest('POST', url)
        ..fields['chat_id'] = _telegramChatId.toString()
        ..fields['text'] = message;
    }

    try {
      var response = await request.send();

      if (response.statusCode != 200) {
        final respStr = await response.stream.bytesToString();
        _logger.e("Ошибка отправки сообщения в Telegram: ${response.statusCode} - $respStr");
      }
    } catch (e) {
      // Запись ошибки в логгер
      _logger.e("Ошибка отправки сообщения в Telegram: $e");
    }
  }
}
