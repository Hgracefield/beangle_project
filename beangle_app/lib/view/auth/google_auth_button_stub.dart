import 'package:flutter/material.dart';

Widget buildGoogleAuthButton({
  required VoidCallback onPressed,
  required String label,
}) {
  return OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(Icons.login),
    label: Text(label),
  );
}
