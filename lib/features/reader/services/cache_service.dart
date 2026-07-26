import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class CacheService {
  // Generate a unique, safe filename based on the original file path
  static String _generateCacheFileName(String originalPath) {
    final bytes = utf8.encode(originalPath);
    final hash = md5.convert(bytes);
    return '$hash.json';
  }

  static Future<File> _getCacheFile(String originalPath) async {
    final directory = await getApplicationSupportDirectory();
    final fileName = _generateCacheFileName(originalPath);
    return File('${directory.path}/$fileName');
  }

  // Save the parsed book to a local JSON file
  static Future<void> saveBookCache(String originalPath, List<List<String>> pages) async {
    final file = await _getCacheFile(originalPath);
    final String jsonString = jsonEncode(pages);
    await file.writeAsString(jsonString);
  }

  // Load the parsed book from the JSON file (if it exists)
  static Future<List<List<String>>?> loadBookCache(String originalPath) async {
    final file = await _getCacheFile(originalPath);
    
    if (await file.exists()) {
      try {
        final String jsonString = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(jsonString);
        
        // Cast back to List<List<String>>
        return decoded.map((page) => List<String>.from(page)).toList();
      } catch (e) {
        // If the cache is corrupted, return null so we fall back to re-parsing
        return null; 
      }
    }
    return null; // No cache found
  }
}