import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

import 'services/api_config.dart';

class StudentUploadScreen extends StatefulWidget {
  final String userId;

  const StudentUploadScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _StudentUploadScreenState createState() => _StudentUploadScreenState();
}

class _StudentUploadScreenState extends State<StudentUploadScreen> {
  File? _imageFile;
  bool _isProcessing = false;

  String _selectedDocType = 'Report of Grades';
  String _selectedTerm = 'AY 2025-2026 1st Semester';
  final TextEditingController _remarksController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  bool _isReportOfGradesType(String value) {
    final v = value.toLowerCase();
    return v.contains('report') && v.contains('grade');
  }

  bool _isRenewalLetterType(String value) {
    return value.toLowerCase().contains('renewal');
  }

  bool _isEnrollmentFormType(String value) {
    return value.toLowerCase().contains('enrollment');
  }

  bool _matchesTypeByFilename(String filename, String docType) {
    final name = filename.toLowerCase();
    if (_isReportOfGradesType(docType)) {
      return !(name.contains('renewal') || name.contains('letter'));
    }
    if (_isRenewalLetterType(docType)) {
      return !(name.contains('grade') || name.contains('report'));
    }
    if (_isEnrollmentFormType(docType)) {
      return !(name.contains('grade') || name.contains('report') || name.contains('renewal'));
    }
    return true;
  }

  // --- 1. PICK IMAGE ---
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to select image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- 2. EXTRACT GRADES & CALCULATE AVERAGE ---
  double _calculateAverage(String text) {
    RegExp regExp =
        RegExp(r'\b([7-9][0-9](?:\.[0-9]{1,2})?|100(?:\.0{1,2})?)\b');
    Iterable<RegExpMatch> matches = regExp.allMatches(text);

    if (matches.isEmpty) return 0.0;

    double sum = 0;
    int count = 0;

    for (final match in matches) {
      double? grade = double.tryParse(match.group(0)!);
      if (grade != null) {
        sum += grade;
        count++;
      }
    }
    return count > 0 ? sum / count : 0.0;
  }

  // --- 3. PROCESS & UPLOAD ---
  Future<void> _processAndUpload() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first.')),
      );
      return;
    }

    if (!_matchesTypeByFilename(_imageFile!.path, _selectedDocType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Selected document type does not match the file name. Please choose the correct type.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      String extractedText = '';
      double average = 0.0;
      String systemStatus = 'Pending';

      if (_isReportOfGradesType(_selectedDocType)) {
        final inputImage = InputImage.fromFile(_imageFile!);
        final RecognizedText recognizedText =
            await _textRecognizer.processImage(inputImage);
        extractedText = recognizedText.text;

        average = _calculateAverage(extractedText);
        systemStatus = (average >= 85.0) ? 'Auto-Approved' : 'Pending';
        if (extractedText.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Report of Grades requires readable grades. Please upload the correct file.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }

      // UPDATED: Using your Computer IP Address instead of localhost
      var request = http.MultipartRequest(
        'POST',
        ApiConfig.uri('upload_document.php'),
      );

      // Sending all required fields to match your database columns
      request.fields['user_id'] = widget.userId;
      request.fields['document_type'] = _selectedDocType;
      request.fields['academic_term'] = _selectedTerm;
      request.fields['remarks'] = _remarksController.text;
      if (extractedText.isNotEmpty) {
        request.fields['extracted_text'] = extractedText;
      }
      if (_isReportOfGradesType(_selectedDocType)) {
        request.fields['computed_average'] = average.toStringAsFixed(2);
        request.fields['system_status'] = systemStatus;
      }

      // UPDATED: Key changed to 'document' to match PHP $_FILES['document']
      request.files
          .add(await http.MultipartFile.fromPath('document', _imageFile!.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Document successfully uploaded!'),
              backgroundColor: Colors.green),
        );
        setState(() {
          _imageFile = null;
          _remarksController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: ${response.body}'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('An error occurred. Check your connection.'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _remarksController.dispose();
    super.dispose();
  }

  // UI Build remains the same as your previous logic...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD1C4E9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Document Submission & Processing',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B125A)),
            ),
            const SizedBox(height: 30),
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE6DDF2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFF9E47BE), width: 2),
              ),
              child: _imageFile != null
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.file(_imageFile!, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: CircleAvatar(
                            backgroundColor: Colors.white.withOpacity(0.8),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () =>
                                  setState(() => _imageFile = null),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.document_scanner,
                            size: 60, color: Color(0xFF9E47BE)),
                        const SizedBox(height: 15),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9E47BE)),
                          onPressed: _pickImage,
                          icon: const Icon(Icons.upload_file,
                              color: Colors.white),
                          label: const Text('Upload Photo',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 30),
            _buildDropdownRow(
                'Document Type',
                ['Report of Grades', 'Renewal Letter'],
                _selectedDocType, (val) {
              setState(() => _selectedDocType = val!);
            }),
            const SizedBox(height: 20),
            _buildDropdownRow(
                'Academic Term',
                ['AY 2025-2026 1st Semester', 'AY 2025-2026 2nd Semester'],
                _selectedTerm, (val) {
              setState(() => _selectedTerm = val!);
            }),
            const SizedBox(height: 20),
            TextField(
              controller: _remarksController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter remarks...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9E47BE),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 20)),
                onPressed: _isProcessing ? null : _processAndUpload,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Start Processing',
                        style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownRow(String label, List<String> items,
      String currentValue, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              underline: const SizedBox(),
              items: items
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
