import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../reader/screens/reader_screen.dart';
import '../reader/services/file_parser_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Extracted logic to keep the build method clean
  Future<void> _pickAndParseFile(BuildContext context) async {
    // 1. Open native file picker (Filters for PDFs only right now)
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf','epub'],
      lockParentWindow: true,
    );

    if (result != null && result.files.single.path != null) {
      final String filePath = result.files.single.path!;
      final String fileName = result.files.single.name;

      // 2. Show a loading indicator (Dialog)
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // 3. Parse the text
        List<List<String>> extractedLines = await FileParserService.parseFile(filePath);

        // 4. Update the state
        if (!context.mounted) return;
        context.read<AppState>().loadNewBook(fileName, extractedLines);

        // 5. Close the loading dialog
        Navigator.pop(context);

        // 6. Navigate to the Reader Screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReaderScreen()),
        );
      } catch (e) {
        // Close the dialog and show an error if it fails
        if (!context.mounted) return;
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linea Library'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'No books here yet.\nTap the + button to open a file.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.black54),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickAndParseFile(context),
        icon: const Icon(Icons.add),
        label: const Text('Open File'),
      ),
    );
  }
}