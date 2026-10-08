import 'package:hive/hive.dart';

class Book {
  final String title;
  final String filePath;
  int currentPageIndex;
  int currentLineIndex;
  int totalPages;

  Book({
    required this.title,
    required this.filePath,
    this.currentPageIndex = 0,
    this.currentLineIndex = 0,
    this.totalPages = 1,
  });
}

// Manual adapter so we don't have to run build_runner scripts
class BookAdapter extends TypeAdapter<Book> {
  @override
  final int typeId = 0;

  @override
  Book read(BinaryReader reader) {
    final title = reader.readString();
    final filePath = reader.readString();
    final currentPageIndex = reader.readInt();
    final currentLineIndex = reader.readInt();
    
    int totalPages = 1;
    try {
      totalPages = reader.readInt();
    } catch (_) {
      // Ignore if reading old format books without totalPages
    }

    return Book(
      title: title,
      filePath: filePath,
      currentPageIndex: currentPageIndex,
      currentLineIndex: currentLineIndex,
      totalPages: totalPages,
    );
  }

  @override
  void write(BinaryWriter writer, Book obj) {
    writer.writeString(obj.title);
    writer.writeString(obj.filePath);
    writer.writeInt(obj.currentPageIndex);
    writer.writeInt(obj.currentLineIndex);
    writer.writeInt(obj.totalPages);
  }
}