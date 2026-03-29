import 'package:flutter/material.dart';

class DashProps {
  // Use this for the White Header Bar
  static Widget header(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(5)),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF4A148C))),
      );

  // Use this for the colored Stat Boxes
  static Widget statBox(String label, String value, Color bg, Color textC) =>
      Expanded(
        child: Container(
          height: 150,
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(value,
                  style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold, color: textC)),
            ],
          ),
        ),
      );

  // Use this for the Submission Status/Request Status containers
  static Widget contentBox(
          {required String title, required List<Widget> children}) =>
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(5)),
        child: Column(children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF4A148C))),
          const SizedBox(height: 15),
          ...children,
        ]),
      );
}
