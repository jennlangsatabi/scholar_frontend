class Document {
  final String id;
  final String documentType;
  final String academicTerm;
  final String imageUrl;
  final double computedAverage;
  final String adminStatus;

  Document({
    required this.id,
    required this.documentType,
    required this.academicTerm,
    required this.imageUrl,
    required this.computedAverage,
    required this.adminStatus,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id']?.toString() ?? '',
      documentType: json['document_type'] ?? 'N/A',
      academicTerm: json['academic_term'] ?? 'N/A',
      // This key 'image_url' must match what your PHP returns
      imageUrl: json['image_url'] ?? '',
      computedAverage:
          double.tryParse(json['computed_average']?.toString() ?? '0.0') ?? 0.0,
      adminStatus: json['admin_status'] ?? 'Pending',
    );
  }
}
