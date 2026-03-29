import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  final Function(String) onRoleSelected;

  const RoleSelectionScreen({super.key, required this.onRoleSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/jmclogo.png', height: 100),
        const SizedBox(height: 10),
        const Text(
          'JOSE MARIA COLLEGE\nFOUNDATION, INC.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        const Divider(
            color: Colors.white38,
            thickness: 1,
            indent: 40,
            endIndent: 40),
        const SizedBox(height: 20),
        _roleBtn(
          Icons.vpn_key_outlined,
          'Admin',
          () => onRoleSelected('Admin'),
        ),
        const SizedBox(height: 12),
        _roleBtn(
          Icons.school_outlined,
          'Scholars',
          () => onRoleSelected('Scholars'),
        ),
      ],
    );
  }

  Widget _roleBtn(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 5,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
