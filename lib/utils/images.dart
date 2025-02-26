import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class ImageUtils {
  static Future<List<String>> searchImages(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final url =
        'https://images.search.yahoo.com/search/images?p=$encodedQuery&fr=yfp-t&fr2=p%3As%2Cv%3Ai%2Cm%3Asb-top&ei=UTF-8&x=wrt';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        },
      );

      if (response.statusCode == 200) {
        return _extractImageUrls(response.body);
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка при поиске изображений: $e');
    }
  }

  static List<String> _extractImageUrls(String htmlContent) {
    final document = parse(htmlContent);
    final List<String> imageUrls = [];

    document.querySelectorAll('img.process').forEach((img) {
      final url = img.attributes['data-src'];
      if (url != null && url.isNotEmpty) {
        imageUrls.add(url);
        if (imageUrls.length >= 20) return;
      }
    });

    return imageUrls;
  }
}
