import 'dart:io';
import 'dart:isolate';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:epubx/epubx.dart' as epubx;

class FileParserService {
  
  // Master entry point that detects file type
  static Future<List<List<String>>> parseFile(String filePath) async {
    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.pdf')) {
      return await _parsePdf(filePath);
    } else if (lowerPath.endsWith('.epub')) {
      return await _parseEpub(filePath);
    } else {
      throw Exception('Unsupported file format');
    }
  }

  // --- PDF PARSER ---
  static Future<List<List<String>>> _parsePdf(String filePath) async {
    return await Isolate.run(() {
      try {
        final bytes = File(filePath).readAsBytesSync();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        
        List<String> rawPageTexts = [];
        for (int i = 0; i < document.pages.count; i++) {
          final String rawText = extractor.extractText(startPageIndex: i, endPageIndex: i);
          rawPageTexts.add(rawText);
        }
        document.dispose();

        Map<String, int> topLineCounts = {};
        for (var page in rawPageTexts) {
          final lines = page.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
          if (lines.isNotEmpty) {
            final firstLine = lines.first;
            if (firstLine.length < 60) {
              topLineCounts[firstLine] = (topLineCounts[firstLine] ?? 0) + 1;
            }
          }
        }

        String? detectedHeader;
        if (rawPageTexts.isNotEmpty) {
          topLineCounts.forEach((line, count) {
            if (count > (rawPageTexts.length * 0.3)) {
              detectedHeader = line;
            }
          });
        }

        final List<List<String>> readablePages = [];
        const int wordsPerLine = 10;

        for (var rawText in rawPageTexts) {
          String cleanText = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
          
          if (detectedHeader != null && cleanText.startsWith(detectedHeader!)) {
            cleanText = cleanText.substring(detectedHeader!.length).trim();
          }

          if (cleanText.isEmpty) continue;

          final List<String> words = cleanText.split(' ');
          final List<String> pageLines = [];
          
          for (int j = 0; j < words.length; j += wordsPerLine) {
            int end = j + wordsPerLine;
            if (end > words.length) end = words.length;
            pageLines.add(words.sublist(j, end).join(' '));
          }
          
          if (pageLines.isNotEmpty) {
            readablePages.add(pageLines);
          }
        }
            
        return readablePages;
      } catch (e) {
        throw Exception('Failed to parse PDF: $e');
      }
    });
  }

  // --- EPUB PARSER ---
  static Future<List<List<String>>> _parseEpub(String filePath) async {
    return await Isolate.run(() async {
      try {
        final List<int> fileBytes = File(filePath).readAsBytesSync();
        epubx.EpubBook epubBook = await epubx.EpubReader.readBook(fileBytes);

        StringBuffer fullTextBuffer = StringBuffer();

        // Recursive function to extract HTML text from nested chapters
        void extractChapterText(epubx.EpubChapter chapter) {
          if (chapter.HtmlContent != null) {
            // Strip HTML tags using regex to leave only plain text
            String plainText = chapter.HtmlContent!.replaceAll(RegExp(r'<[^>]*>'), ' ');
            fullTextBuffer.write(plainText);
            fullTextBuffer.write(' ');
          }
          if (chapter.SubChapters != null) {
            for (var sub in chapter.SubChapters!) {
              extractChapterText(sub);
            }
          }
        }

        if (epubBook.Chapters != null) {
          for (var chapter in epubBook.Chapters!) {
            extractChapterText(chapter);
          }
        }

        String rawText = fullTextBuffer.toString();
        String cleanText = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
        
        final List<String> words = cleanText.split(' ');
        const int wordsPerLine = 10;
        const int linesPerPage = 30; // Virtual pages since EPUBs flow continuously
        
        List<List<String>> allPages = [];
        List<String> currentPageLines = [];
        List<String> currentLineWords = [];

        for (int i = 0; i < words.length; i++) {
          currentLineWords.add(words[i]);
          if (currentLineWords.length == wordsPerLine || i == words.length - 1) {
            currentPageLines.add(currentLineWords.join(' '));
            currentLineWords = [];

            if (currentPageLines.length == linesPerPage || i == words.length - 1) {
              allPages.add(List.from(currentPageLines));
              currentPageLines = [];
            }
          }
        }

        if (allPages.isEmpty) {
          allPages.add(['No readable text found in this ePub.']);
        }

        return allPages;
      } catch (e) {
        throw Exception('Failed to parse ePub: $e');
      }
    });
  }
}