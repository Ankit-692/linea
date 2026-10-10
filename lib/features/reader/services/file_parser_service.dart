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

        // --- Junk Page Filtering ---
        bool isJunkPdfPage(String pageText) {
          if (pageText.trim().isEmpty) return true;
          final lowerPage = pageText.toLowerCase();
          
          // Copyright checks
          if (lowerPage.contains('all rights reserved') && (lowerPage.contains('isbn') || lowerPage.contains('©') || lowerPage.contains('copyright'))) {
            return true;
          }

          final lines = pageText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
          if (lines.isEmpty) return true;
          
          // Title checks
          final firstLine = lines.first.toLowerCase();
          final junkHeadings = [
            'cover', 'title page', 'copyright', 'dedication', 
            'acknowledgment', 'acknowledgement', 'contents', 
            'table of contents', 'index', 'about the author', 
            'praise', 'bibliography', 'translator', 'foreword', 
            'preface', 'epigraph', 'also by'
          ];
          for (var heading in junkHeadings) {
            if (firstLine == heading || firstLine.contains(heading)) return true;
          }
          
          // TOC density check (looking for lines like "Chapter 1 ....... 5")
          int tocLines = 0;
          for (var line in lines) {
            if (line.contains('...') || line.contains('. . .')) {
               if (RegExp(r'\d+$').hasMatch(line.trim())) {
                 tocLines++;
               }
            }
          }
          if (tocLines >= 4) return true;

          return false;
        }

        List<String> validPageTexts = [];
        for (int i = 0; i < rawPageTexts.length; i++) {
          var page = rawPageTexts[i];
          if (isJunkPdfPage(page)) continue;

          // Aggressive volume filter for the first 10 pages of the PDF
          if (i < 10) {
            int wordCount = page.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).length;
            // PDF pages usually have 200+ words. If < 100, it's likely a title or dedication page.
            if (wordCount < 100) {
              String lowerPage = page.toLowerCase();
              if (!lowerPage.contains('prologue')) {
                continue; // Skip this short front-matter page
              }
            }
          }
          
          validPageTexts.add(page);
        }

        // Very basic header detection
        Map<String, int> topLineCounts = {};
        for (var page in validPageTexts) {
          final lines = page.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
          if (lines.isNotEmpty) {
            final firstLine = lines.first;
            if (firstLine.length < 60) {
              topLineCounts[firstLine] = (topLineCounts[firstLine] ?? 0) + 1;
            }
          }
        }

        String? detectedHeader;
        if (validPageTexts.isNotEmpty) {
          topLineCounts.forEach((line, count) {
            if (count > (validPageTexts.length * 0.3)) {
              detectedHeader = line;
            }
          });
        }

        StringBuffer fullTextBuffer = StringBuffer();

        for (var rawText in validPageTexts) {
          String cleanText = rawText;
          
          // Strip detected header
          if (detectedHeader != null && cleanText.startsWith(detectedHeader!)) {
            cleanText = cleanText.substring(detectedHeader!.length).trim();
          }

          // Strip simple standalone numbers at the end (likely page numbers)
          cleanText = cleanText.replaceAll(RegExp(r'\s\d+\s*$'), ' ');

          // Try to inject block breaks for paragraphs
          // In PDF, double newlines often indicate paragraphs or headings.
          cleanText = cleanText.replaceAll(RegExp(r'\n\s*\n'), ' __BLOCK__ ');
          cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();

          if (cleanText.isEmpty) continue;
          fullTextBuffer.write(cleanText);
          
          // Treat the end of a physical PDF page as a structural block break
          // This prevents the last word of Page A from gluing to the first word of Page B
          fullTextBuffer.write(' __BLOCK__ ');
        }
            
        final String combinedText = fullTextBuffer.toString();
        List<String> blocks = combinedText.split('__BLOCK__');

        // --- Smart Chunking (Approach B) ---
        List<String> allLines = [];
        
        for (var block in blocks) {
          String cleanBlock = block.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (cleanBlock.isEmpty) continue;
          
          final List<String> words = cleanBlock.split(' ');
          List<String> currentLineWords = [];
          
          for (int i = 0; i < words.length; i++) {
            String word = words[i];
            if (word.isEmpty) continue;
            
            currentLineWords.add(word);
            
            bool isPunctuation = word.endsWith('.') || word.endsWith(',') || word.endsWith(';') || 
                                 word.endsWith(':') || word.endsWith('?') || word.endsWith('!') || 
                                 word.endsWith('"') || word.endsWith('”');
            
            bool forceBreak = currentLineWords.length >= 12; 
            bool smartBreak = currentLineWords.length >= 6 && isPunctuation;
            
            if (forceBreak || smartBreak || i == words.length - 1) {
              allLines.add(currentLineWords.join(' '));
              currentLineWords = [];
            }
          }
        }

        // --- Smart Pagination ---
        const int linesPerPage = 30; // 30 lines per continuous virtual page
        List<List<String>> allPages = [];
        List<String> currentPageLines = [];

        for (int i = 0; i < allLines.length; i++) {
          String line = allLines[i];
          currentPageLines.add(line);
          
          bool isEndOfSentence = line.endsWith('.') || line.endsWith('?') || line.endsWith('!') || line.endsWith('"') || line.endsWith('”');
          bool isNearEnd = currentPageLines.length >= (linesPerPage - 4);
          bool isPageFull = currentPageLines.length >= linesPerPage;
          
          if (isPageFull || (isNearEnd && isEndOfSentence) || i == allLines.length - 1) {
            allPages.add(List.from(currentPageLines));
            currentPageLines = [];
          }
        }

        if (allPages.isEmpty) {
          allPages.add(['No readable text found in this PDF.']);
        }

        return allPages;
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

        // Helper to filter out non-story chapters
        bool isJunkChapter(String? title) {
          if (title == null) return false;
          final lowerTitle = title.toLowerCase().trim();
          final junkKeywords = [
            'cover', 'title page', 'copyright', 'dedication', 
            'acknowledgment', 'acknowledgement', 'contents', 
            'table of contents', 'index', 'about the author', 
            'praise', 'bibliography', 'translator', 'foreword', 
            'preface', 'epigraph', 'also by'
          ];
          for (var keyword in junkKeywords) {
            if (lowerTitle == keyword || lowerTitle.contains(keyword)) return true;
          }
          return false;
        }

        // Flatten chapters to process them sequentially
        List<epubx.EpubChapter> allChapters = [];
        void flattenChapters(List<epubx.EpubChapter> chapters) {
          for (var chapter in chapters) {
            allChapters.add(chapter);
            if (chapter.SubChapters != null) {
              flattenChapters(chapter.SubChapters!);
            }
          }
        }
        
        if (epubBook.Chapters != null) {
          flattenChapters(epubBook.Chapters!);
        }

        const int linesPerPage = 30;
        List<List<String>> allPages = [];

        // Pre-filter chapters to aggressively drop front-matter
        List<epubx.EpubChapter> validChapters = [];
        for (int i = 0; i < allChapters.length; i++) {
          var chapter = allChapters[i];
          if (isJunkChapter(chapter.Title)) continue;

          // Aggressive volume filter for the very beginning of the book
          // Drops generic "Book Details" or blank pages that don't have titles
          if (i < 5 && chapter.HtmlContent != null) {
            String tempText = chapter.HtmlContent!.replaceAll(RegExp(r'<[^>]*>'), ' ');
            int wordCount = tempText.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).length;
            
            // If it has fewer than 150 words, it's almost certainly front-matter
            if (wordCount < 150) {
              String lowerTitle = (chapter.Title ?? '').toLowerCase();
              if (!lowerTitle.contains('prologue')) {
                continue; // Skip this short front-matter chapter
              }
            }
          }
          validChapters.add(chapter);
        }

        // Process each valid chapter in complete isolation
        for (var chapter in validChapters) {
          if (isJunkChapter(chapter.Title)) continue;
          if (chapter.HtmlContent == null) continue;

          String plainText = chapter.HtmlContent!;
          
          // Inject a special block separator after block-level elements
          plainText = plainText.replaceAll(RegExp(r'</(h[1-6]|p|div|li|blockquote|td|th)>', caseSensitive: false), ' __BLOCK__ ');
          plainText = plainText.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' __BLOCK__ ');

          // Strip all remaining HTML tags
          plainText = plainText.replaceAll(RegExp(r'<[^>]*>'), ' ');
          
          // Decode some basic HTML entities
          plainText = plainText.replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>');
          
          // Split text by our injected block separators
          List<String> blocks = plainText.split('__BLOCK__');
          
          List<String> chapterLines = [];
          
          for (var block in blocks) {
            String cleanBlock = block.replaceAll(RegExp(r'\s+'), ' ').trim();
            if (cleanBlock.isEmpty) continue;
            
            final List<String> words = cleanBlock.split(' ');
            List<String> currentLineWords = [];
            
            for (int i = 0; i < words.length; i++) {
              String word = words[i];
              if (word.isEmpty) continue;
              
              currentLineWords.add(word);
              
              bool isPunctuation = word.endsWith('.') || word.endsWith(',') || word.endsWith(';') || 
                                   word.endsWith(':') || word.endsWith('?') || word.endsWith('!') || 
                                   word.endsWith('"') || word.endsWith('”');
              
              bool forceBreak = currentLineWords.length >= 12; 
              bool smartBreak = currentLineWords.length >= 6 && isPunctuation;
              
              if (forceBreak || smartBreak || i == words.length - 1) {
                chapterLines.add(currentLineWords.join(' '));
                currentLineWords = [];
              }
            }
          }
          
          // If this chapter has no readable text, skip paginating it
          if (chapterLines.isEmpty) continue;

          // --- Smart Pagination (Per Chapter) ---
          List<String> currentPageLines = [];
          
          for (int i = 0; i < chapterLines.length; i++) {
            String line = chapterLines[i];
            currentPageLines.add(line);
            
            bool isEndOfSentence = line.endsWith('.') || line.endsWith('?') || line.endsWith('!') || line.endsWith('"') || line.endsWith('”');
            bool isNearEnd = currentPageLines.length >= (linesPerPage - 4);
            bool isPageFull = currentPageLines.length >= linesPerPage;
            
            // Push to allPages if page is full, near end, OR if it's the absolute last line of the chapter!
            if (isPageFull || (isNearEnd && isEndOfSentence) || i == chapterLines.length - 1) {
              allPages.add(List.from(currentPageLines));
              currentPageLines = [];
            }
          }
          // By breaking pagination here, we guarantee the NEXT chapter will start on a brand new page.
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