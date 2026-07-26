import 'package:hive/hive.dart';

class Book {
  final String title;
  final String filePath;
  int currentPageIndex;
  int currentLineIndex;

  Book({
    required this.title,
    required this.filePath,
    this.currentPageIndex = 0,
    this.currentLineIndex = 0,
  });
}

// Manual adapter so we don't have to run build_runner scripts
class BookAdapter extends TypeAdapter<Book> {
  @override
  final int typeId = 0;

  @override
  Book read(BinaryReader reader) {
    return Book(
      title: reader.readString(),
      filePath: reader.readString(),
      currentPageIndex: reader.readInt(),
      currentLineIndex: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Book obj) {
    writer.writeString(obj.title);
    writer.writeString(obj.filePath);
    writer.writeInt(obj.currentPageIndex);
    writer.writeInt(obj.currentLineIndex);
  }
}