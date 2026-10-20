import 'package:flutter_test/flutter_test.dart';
import 'package:linea/features/reader/services/file_parser_service.dart';

void main() {
  group('FileParserService line chunking logic', () {
    test('Empty block returns empty list', () {
      expect(FileParserService.chunkBlockIntoLines(''), isEmpty);
      expect(FileParserService.chunkBlockIntoLines('   \n  \t  '), isEmpty);
    });

    test('Short block (< 7 words) emits as a single line on block end', () {
      final lines = FileParserService.chunkBlockIntoLines('Chapter One.');
      expect(lines, ['Chapter One.']);
      expect(lines.first.split(' ').length, 2);
    });

    test('Block with exactly 7 words and punctuation breaks at 7 words', () {
      final text = 'One two three four five six seven.';
      final lines = FileParserService.chunkBlockIntoLines(text);
      expect(lines, [text]);
      expect(lines.first.split(' ').length, 7);
      expect(lines.first.endsWith('.'), isTrue);
    });

    test('Punctuation before 7 words (e.g. at word 3 or 6) does not trigger smart break', () {
      // Word 3 has a comma, word 5 has a semicolon, word 7 has a period
      final text = 'One, two three; four five six seven.';
      final lines = FileParserService.chunkBlockIntoLines(text);
      expect(lines, [text]);
      expect(lines.first.split(' ').length, 7);
    });

    test('Block with exactly 10 words and punctuation breaks at 10 words', () {
      final text = 'One two three four five six seven eight nine ten.';
      final lines = FileParserService.chunkBlockIntoLines(text);
      expect(lines, [text]);
      expect(lines.first.split(' ').length, 10);
    });

    test('Block with 10 words without punctuation force breaks at 10 words', () {
      final text = 'One two three four five six seven eight nine ten eleven twelve thirteen.';
      final lines = FileParserService.chunkBlockIntoLines(text);
      expect(lines.length, 2);
      expect(lines[0], 'One two three four five six seven eight nine ten');
      expect(lines[0].split(' ').length, 10);
      expect(lines[1], 'eleven twelve thirteen.');
      expect(lines[1].split(' ').length, 3);
    });

    test('Smart break triggers between 7 and 10 words on all punctuation types', () {
      final punctuationMarks = ['.', ',', ';', ':', '?', '!', '"', '”'];
      for (final p in punctuationMarks) {
        final text = 'Word one two three four five seven$p And then four more words here.';
        final lines = FileParserService.chunkBlockIntoLines(text);
        expect(lines.length, 2, reason: 'Failed for punctuation $p');
        expect(lines[0], 'Word one two three four five seven$p');
        expect(lines[0].split(' ').length, 7);
        expect(lines[0].endsWith(p), isTrue);
      }
    });

    test('14-word block with punctuation at word 7 and 14 cleanly breaks into two 7-word lines', () {
      final text = 'One two three four five six seven. Eight nine ten eleven twelve thirteen fourteen.';
      final lines = FileParserService.chunkBlockIntoLines(text);
      expect(lines.length, 2);
      expect(lines[0].split(' ').length, 7);
      expect(lines[0].endsWith('.'), isTrue);
      expect(lines[1].split(' ').length, 7);
      expect(lines[1].endsWith('.'), isTrue);
    });

    test('Lines never exceed 10 words', () {
      final longBlock = '${List.generate(55, (i) => 'word$i').join(' ')}.';
      final lines = FileParserService.chunkBlockIntoLines(longBlock);
      for (final line in lines) {
        final count = line.split(' ').length;
        expect(count <= 10, isTrue, reason: 'Line "$line" exceeded 10 words: $count');
      }
    });
  });

  group('FileParserService pagination logic with sentence separator', () {
    test('Near end of page with sentence separator breaks page cleanly', () {
      // Create 26 lines, where line 26 ends with a period
      final lines = List.generate(25, (i) => 'Line number $i')
        ..add('This is the end of the sentence.');

      final List<List<String>> pages = [];
      FileParserService.paginateLines(lines, pages, linesPerPage: 30);

      // Line 26 is >= 26 (linesPerPage - 4) and ends with '.', so it should trigger a page break!
      expect(pages.length, 1);
      expect(pages[0].length, 26);
      expect(pages[0].last.endsWith('.'), isTrue);
    });

    test('Near end of page with comma does NOT break page early', () {
      // Create 26 lines, where line 26 ends with a comma (not a sentence separator)
      final lines = List.generate(25, (i) => 'Line number $i')
        ..add('This has a comma,')
        ..add('Next line 27')
        ..add('Next line 28')
        ..add('Next line 29')
        ..add('Next line 30.');

      final List<List<String>> pages = [];
      FileParserService.paginateLines(lines, pages, linesPerPage: 30);

      // Page should fill up to 30 lines before breaking
      expect(pages.first.length, 30);
    });
  });
}
