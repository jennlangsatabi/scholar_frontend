import 'package:flutter/material.dart';

class DashboardStyle {
  // Background color for all main dashboard areas
  static const Color bgColor = Color(0xFFD9D9D9);
  static const Color primaryPurple = Color(0xFF4A148C);

  // Standard Decoration for Boxes
  static BoxDecoration boxDecoration(Color color) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      );
}
