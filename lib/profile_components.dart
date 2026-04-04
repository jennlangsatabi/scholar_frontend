import 'package:flutter/material.dart';

// 1. Base Profile Layout Template
class BaseProfileLayout extends StatelessWidget {
  final String title, role, name, course;
  final String? semester;
  final List<Widget> filters;
  final VoidCallback onFilter;
  final Widget content;
  final String? imageUrl;
  final VoidCallback? onEditProfile;
  final VoidCallback? onUploadImage;

  const BaseProfileLayout({
    super.key,
    required this.title,
    required this.role,
    required this.name,
    required this.course,
    this.semester,
    required this.filters,
    required this.onFilter,
    required this.content,
    this.imageUrl,
    this.onEditProfile,
    this.onUploadImage,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D0D44))),
          const SizedBox(height: 25),
          // Filter section using Wrap for responsiveness
          Wrap(
            spacing: 15,
            runSpacing: 15,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...filters,
              ElevatedButton(
                onPressed: onFilter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFAB47BC),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 22),
                ),
                child: const Text("Filter",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _HeaderBanner(
              role: role,
              name: name,
              course: course,
              semester: semester,
              imageUrl: imageUrl,
              onEditProfile: onEditProfile,
              onUploadImage: onUploadImage),
          content,
        ],
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  final String role, name, course;
  final String? semester;
  final String? imageUrl;
  final VoidCallback? onEditProfile;
  final VoidCallback? onUploadImage;
  const _HeaderBanner(
      {required this.role,
      required this.name,
      required this.course,
      this.semester,
      this.imageUrl,
      this.onEditProfile,
      this.onUploadImage});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
        color: Color(0xFF6A1B9A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white24,
                backgroundImage:
                    (imageUrl != null && imageUrl!.isNotEmpty)
                        ? NetworkImage(imageUrl!)
                        : null,
                child: (imageUrl == null || imageUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white, size: 40)
                    : null,
              ),
              if (onUploadImage != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: onUploadImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 16, color: Color(0xFF2D0D44)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 25),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Name: $name",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text("Course: $course",
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text("Type: $role",
                      style: const TextStyle(
                          color: Color(0xFF2D0D44),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
          if (onEditProfile != null)
            FilledButton.icon(
              onPressed: onEditProfile,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4A148C),
              ),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
            ),
        ],
      ),
    );
  }
}

// 2. Data Table Component
class ProfileDataTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows; // Fixed to List<List<String>>

  const ProfileDataTable(
      {super.key, required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 560;

        if (isMobile) {
          return _buildMobileCards(context, width);
        }
        return _buildDesktopTable();
      },
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(16))),
      child: Table(
        children: [
          // Header Row
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade50),
            children: headers.map((h) => _buildCell(h, true)).toList(),
          ),
          // Dynamic Data Rows
          ...rows.map((row) => TableRow(
                children: row.map((cell) => _buildCell(cell, false)).toList(),
              )),
        ],
      ),
    );
  }

  Widget _buildMobileCards(BuildContext context, double width) {
    final labelFontSize = (width * 0.034).clamp(11.5, 13.5);
    final valueFontSize = (width * 0.038).clamp(12.5, 15.0);
    final labelWidth = (width * 0.40).clamp(120.0, 170.0);

    final labelStyle = TextStyle(
      fontWeight: FontWeight.w800,
      color: const Color(0xFF2D0D44),
      fontSize: labelFontSize,
    );
    final valueStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: Colors.black87,
      fontSize: valueFontSize,
      height: 1.25,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            ...rows.asMap().entries.map((entry) {
              final rowIndex = entry.key;
              final row = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: rowIndex == rows.length - 1 ? 0 : 12),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6DFF0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        ...headers.asMap().entries.map((headerEntry) {
                          final i = headerEntry.key;
                          final header = headerEntry.value;
                          final value =
                              i < row.length ? row[i].toString() : '';

                          return Padding(
                            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: labelWidth,
                                  child: Text(
                                    header,
                                    style: labelStyle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    value.isEmpty ? '\u2014' : value,
                                    textAlign: TextAlign.right,
                                    style: valueStyle,
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(String text, bool isHeader) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              color: isHeader ? const Color(0xFF2D0D44) : Colors.black87)),
    );
  }
}

// 3. Helper: Empty State Widget
Widget buildEmptyState(String message) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(50),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
    ),
    child: Column(
      children: [
        Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 15),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      ],
    ),
  );
}

// 4. Helper: Dropdown Widget
Widget buildProfileDropdown(
  String? value,
  String hint,
  List<String> items,
  void Function(String?) onChanged, {
  double? width = 250,
}) {
  return Container(
    width: width,
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        hint: Text(
          hint,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        items: items.map((String item) {
          return DropdownMenuItem(
            value: item,
            child: Text(
              item,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        }).toList(),
        selectedItemBuilder: (context) {
          return items
              .map((item) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ))
              .toList();
        },
        onChanged: onChanged,
      ),
    ),
  );
}
