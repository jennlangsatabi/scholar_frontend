import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

import 'services/api_config.dart';

class UploadFilesPage extends StatefulWidget {
  final String userId;

  const UploadFilesPage({super.key, required this.userId});

  @override
  State<UploadFilesPage> createState() => _UploadFilesPageState();
}

class _UploadFilesPageState extends State<UploadFilesPage> {
  final TextEditingController _remarksController = TextEditingController();

  String selectedDocType = 'Report of Grades';
  String selectedAcademicTerm = 'AY 2025-2026 1st Semester';
  PlatformFile? _selectedFile;
  bool _isProcessing = false;

  String lastExtractedText = '';
  double lastComputedAverage = 0.0;
  String lastSystemStatus = 'Pending';
  String lastAnalysisNotes = '';
  int? lastClientProcessingMs;
  double? lastServerProcessingSeconds;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

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

  String _requirementIdForDocType(String value) {
    final v = value.toLowerCase();
    if (v.contains('report') && v.contains('grade')) return '0';
    if (v.contains('renewal')) return '1';
    if (v.contains('enrollment')) return '2';
    return '';
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    setState(() {
      _selectedFile = result.files.single;
      lastExtractedText = '';
      lastComputedAverage = 0.0;
      lastSystemStatus = 'Pending';
      lastAnalysisNotes = '';
      lastClientProcessingMs = null;
      lastServerProcessingSeconds = null;
    });
  }

  Future<void> _processAndUpload() async {
    if (_selectedFile == null || _isProcessing) {
      if (_selectedFile == null && mounted) {
        _showSnackBar('Select a file first.', Colors.orange);
      }
      return;
    }

    if (!_matchesTypeByFilename(_selectedFile!.name, selectedDocType)) {
      _showSnackBar(
        'Selected document type does not match the file name. Please choose the correct type.',
        Colors.redAccent,
      );
      return;
    }

    setState(() => _isProcessing = true);
    final stopwatch = Stopwatch()..start();

    try {
      final clientAnalysis =
          _isReportOfGradesType(selectedDocType) ? await _tryAnalyzeLocally() : null;
      if (_isReportOfGradesType(selectedDocType) &&
          clientAnalysis != null &&
          clientAnalysis.extractedText.trim().isEmpty) {
        _showSnackBar(
          'Report of Grades requires readable grades. Please upload the correct file.',
          Colors.redAccent,
        );
        return;
      }
      final request = http.MultipartRequest(
        'POST',
        ApiConfig.uri('upload_document.php'),
      );
      request.files.add(await _buildMultipartFile('document'));
      // Backward compatibility for endpoints still using $_FILES['document_image'].
      request.files.add(await _buildMultipartFile('document_image'));

      request.fields['user_id'] = widget.userId;
      request.fields['document_type'] = selectedDocType;
      final requirementId = _requirementIdForDocType(selectedDocType);
      if (requirementId.isNotEmpty) {
        request.fields['requirement_id'] = requirementId;
      }
      request.fields['academic_term'] = selectedAcademicTerm;
      request.fields['original_filename'] = _selectedFile!.name;
      final remarks = _remarksController.text.trim();
      if (remarks.isNotEmpty) {
        request.fields['remarks'] = remarks;
      }
      if (clientAnalysis != null) {
        request.fields['extracted_text'] = clientAnalysis.extractedText;
        request.fields['computed_average'] =
            clientAnalysis.average.toStringAsFixed(2);
        request.fields['system_status'] = clientAnalysis.systemStatus;
        request.fields['analysis_source'] = 'client';
      }

      final streamedResponse = await request.send().timeout(
            const Duration(minutes: 3),
          );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 201) {
        final serverMessage = _extractServerErrorMessage(response.body);
        throw Exception(
          'Server returned ${response.statusCode}'
          '${serverMessage.isNotEmpty ? ': $serverMessage' : '.'}',
        );
      }

      final Map<String, dynamic> data = _decodeJsonResponse(response.body);

      if (!mounted) return;

      if (data['status'] != 'success') {
        final message = data['message']?.toString() ?? 'Upload failed.';
        throw Exception(message);
      }

      setState(() {
        lastExtractedText = data['extracted_text']?.toString() ?? 'Text processed';
        final average = data['average'];
        lastComputedAverage = average is num
            ? average.toDouble()
            : double.tryParse(average?.toString() ?? '') ?? 0.0;
        lastSystemStatus = data['system_status']?.toString() ?? 'Pending';
        lastAnalysisNotes = data['analysis_notes']?.toString() ?? '';
        lastClientProcessingMs = stopwatch.elapsedMilliseconds;
        final serverSecondsRaw =
            data['processing_seconds'] ?? data['analysis_seconds'];
        lastServerProcessingSeconds = serverSecondsRaw is num
            ? serverSecondsRaw.toDouble()
            : double.tryParse(serverSecondsRaw?.toString() ?? '');
      });

      final backendRemark = data['remarks']?.toString().trim() ?? '';
      final analysisFailed = _analysisFailed(data, backendRemark);
      final snackColor = analysisFailed
          ? Colors.redAccent
          : backendRemark.isNotEmpty &&
                  backendRemark.toLowerCase() != 'null'
              ? Colors.orange
              : Colors.green;
      final snackMessage = analysisFailed
          ? 'Upload saved, but analysis failed: ${_buildAnalysisFailureMessage(data, backendRemark)}'
          : backendRemark.isNotEmpty && backendRemark.toLowerCase() != 'null'
              ? 'Analysis complete: $backendRemark'
              : 'Analysis complete: $lastSystemStatus';
      if (snackMessage.trim().isNotEmpty) {
        _showSnackBar(snackMessage, snackColor);
      } else {
        _showSnackBar('Upload complete.', Colors.green);
      }
    } catch (e) {
      if (!mounted) return;
      final errText = e.toString();
      if (errText.toLowerCase().contains("unknown column 'remarks'")) {
        _showSnackBar(
          "Upload failed: backend DB/query still references a missing 'remarks' column.",
          Colors.redAccent,
        );
      } else {
        _showSnackBar('Upload failed: $e', Colors.redAccent);
      }
      debugPrint('Upload Error: $e');
    } finally {
      stopwatch.stop();
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<_ClientAnalysisResult?> _tryAnalyzeLocally() async {
    final file = _selectedFile;
    if (file == null || kIsWeb) return null;

    final lower = file.name.toLowerCase();
    final isImage = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
    if (!isImage || file.path == null) return null;

    final recognizer =
        TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(file.path!);
      final recognizedText = await recognizer.processImage(inputImage);
      final extractedText = recognizedText.text.trim();
      if (extractedText.isEmpty) return null;

      final average = _calculateAverage(extractedText);
      return _ClientAnalysisResult(
        extractedText: extractedText,
        average: average,
        systemStatus: _computeSystemStatus(average),
      );
    } catch (_) {
      return null;
    } finally {
      recognizer.close();
    }
  }

  double _calculateAverage(String text) {
    final regExp =
        RegExp(r'\b([7-9][0-9](?:\.[0-9]{1,2})?|100(?:\.0{1,2})?)\b');
    final matches = regExp.allMatches(text);
    if (matches.isEmpty) return 0.0;

    var sum = 0.0;
    var count = 0;
    for (final match in matches) {
      final grade = double.tryParse(match.group(0) ?? '');
      if (grade == null) continue;
      sum += grade;
      count++;
    }
    return count == 0 ? 0.0 : sum / count;
  }

  String _computeSystemStatus(double average) {
    return average >= 85.0 ? 'approved' : 'pending';
  }

  bool _analysisFailed(Map<String, dynamic> data, String backendRemark) {
    final explicitFlag = data['analysis_failed'];
    if (explicitFlag is bool) return explicitFlag;

    final notes = (data['analysis_notes']?.toString() ?? '').toLowerCase();
    if (notes.contains('tesseract not found') ||
        notes.contains('no text extracted') ||
        notes.contains('insufficient grade data')) {
      return true;
    }

    return backendRemark.toLowerCase().contains('analysis unavailable');
  }

  String _buildAnalysisFailureMessage(
      Map<String, dynamic> data, String backendRemark) {
    final notes = data['analysis_notes']?.toString().trim() ?? '';
    if (notes.isNotEmpty) return notes;
    if (backendRemark.isNotEmpty && backendRemark.toLowerCase() != 'null') {
      return backendRemark;
    }
    return 'The file was uploaded, but no grade analysis could be generated.';
  }

  Future<http.MultipartFile> _buildMultipartFile(String fieldName) async {
    final file = _selectedFile!;
    final bytes = file.bytes;
    if (bytes != null) {
      return http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: file.name,
      );
    }
    if (file.path != null) {
      return http.MultipartFile.fromPath(
        fieldName,
        file.path!,
        filename: file.name,
      );
    }
    throw const FormatException('Selected file bytes are unavailable.');
  }

  Map<String, dynamic> _decodeJsonResponse(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty response from upload endpoint.');
    }

    if (trimmed.startsWith('<')) {
      throw const FormatException(
          'PHP returned HTML instead of JSON. Check server warnings or fatal errors.');
    }

    final decoded = json.decode(trimmed);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Upload endpoint did not return a JSON object.');
    }

    return decoded;
  }

  String _extractServerErrorMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '';
    try {
      final decoded = json.decode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final msg = decoded['message']?.toString().trim() ?? '';
        if (msg.isNotEmpty) return msg;
      }
    } catch (_) {
      // Ignore parse errors and fall back to raw body.
    }
    return trimmed;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFC5B4E3),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 24),
                _buildScannerFrame(),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 640;
                    final docType = _buildDropdown(
                      'Document Type',
                      selectedDocType,
                      const [
                        'Report of Grades',
                        'Renewal Letter',
                        'Enrollment Form',
                      ],
                      (value) => setState(() => selectedDocType = value!),
                    );
                    final term = _buildDropdown(
                      'Academic Term',
                      selectedAcademicTerm,
                      const [
                        'AY 2025-2026 1st Semester',
                        'AY 2025-2026 2nd Semester',
                        'Summer 2026',
                      ],
                      (value) => setState(() => selectedAcademicTerm = value!),
                    );

                    if (compact) {
                      return Column(
                        children: [
                          docType,
                          const SizedBox(height: 16),
                          term,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: docType),
                        const SizedBox(width: 16),
                        Expanded(child: term),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildRemarksField(),
                const SizedBox(height: 24),
                _actionBtn(
                  'Analyze & Submit',
                  const Color(0xFF2D0D44),
                  Colors.white,
                  onPressed: _processAndUpload,
                  isLoading: _isProcessing,
                ),
                if (lastExtractedText.isNotEmpty ||
                    lastAnalysisNotes.trim().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _statusCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Scholarship Documents',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Attach your latest academic document, then send it for automated review.',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerFrame() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFAB47BC), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.document_scanner, color: Color(0xFF6A1B9A)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Document Preview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D0D44),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose File'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6A1B9A),
                  side: const BorderSide(color: Color(0xFF6A1B9A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF6EEF9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFD6B7E6),
                  style: BorderStyle.solid,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _selectedFile == null
                    ? _buildEmptyPreview()
                    : _buildFilePreview(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedFile == null
                ? 'No file selected.'
                : 'Selected file: ${_selectedFile!.name}',
            style: const TextStyle(
              color: Color(0xFF5E456E),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (kIsWeb)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Web note: the selected file stays in browser memory until you submit it.',
                style: TextStyle(color: Color(0xFF7B658A), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyPreview() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_search_rounded, size: 72, color: Color(0xFFB28BC8)),
          SizedBox(height: 12),
          Text(
            'Choose an image, PDF, or DOCX file to preview.',
            style: TextStyle(
              color: Color(0xFF6A527A),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePreview() {
    final file = _selectedFile;
    if (file == null) return _buildEmptyPreview();

    final lower = file.name.toLowerCase();
    final isImage =
        lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');
    if (isImage && file.bytes != null) {
      return Image.memory(file.bytes!, fit: BoxFit.contain);
    }

    final icon = lower.endsWith('.pdf')
        ? Icons.picture_as_pdf
        : lower.endsWith('.docx')
            ? Icons.description
            : Icons.insert_drive_file;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 80, color: const Color(0xFF7B5B92)),
          const SizedBox(height: 10),
          Text(
            file.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4F3A60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDABCE8)),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xFF6A1B9A),
            fontWeight: FontWeight.w700,
          ),
        ),
        items: items
            .map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildRemarksField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDABCE8)),
      ),
      child: TextField(
        controller: _remarksController,
        maxLines: 4,
        decoration: const InputDecoration(
          border: InputBorder.none,
          labelText: 'Remarks',
          alignLabelWithHint: true,
          labelStyle: TextStyle(
            color: Color(0xFF6A1B9A),
            fontWeight: FontWeight.w700,
          ),
          hintText: 'Optional note for the reviewing office.',
        ),
      ),
    );
  }

  Widget _actionBtn(String label, Color bg, Color text,
      {VoidCallback? onPressed, bool isLoading = false}) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _statusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detected Average: ${lastComputedAverage.toStringAsFixed(2)}%',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6A1B9A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'System Status: $lastSystemStatus',
              style: TextStyle(
                color: lastSystemStatus.toLowerCase().contains('approved')
                    ? Colors.green
                    : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Processing Time: ${_formatClientDuration()}'
              '${_formatServerDurationSuffix()}',
              style: const TextStyle(
                color: Color(0xFF4F3A60),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (lastAnalysisNotes.trim().isNotEmpty) ...[
              Text(
                'Notes: $lastAnalysisNotes',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Text(
              'Extracted Preview',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D0D44),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lastExtractedText,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  String _formatClientDuration() {
    final ms = lastClientProcessingMs;
    if (ms == null) return '-';
    if (ms < 1000) return '$ms ms';

    final seconds = ms / 1000.0;
    if (seconds < 60) return '${seconds.toStringAsFixed(2)} sec';

    final minutes = (seconds ~/ 60);
    final remaining = (seconds % 60);
    return '$minutes min ${remaining.toStringAsFixed(1)} sec';
  }

  String _formatServerDurationSuffix() {
    final s = lastServerProcessingSeconds;
    if (s == null) return '';
    if (s < 60) return ' (server: ${s.toStringAsFixed(2)} sec)';
    final mins = (s ~/ 60);
    final rem = s % 60;
    return ' (server: $mins min ${rem.toStringAsFixed(1)} sec)';
  }
}

class _ClientAnalysisResult {
  const _ClientAnalysisResult({
    required this.extractedText,
    required this.average,
    required this.systemStatus,
  });

  final String extractedText;
  final double average;
  final String systemStatus;
}
