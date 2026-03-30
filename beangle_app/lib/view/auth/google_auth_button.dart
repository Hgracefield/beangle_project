import 'package:flutter/material.dart';

import 'google_auth_button_stub.dart'
    if (dart.library.html) 'google_auth_button_web.dart';

class GoogleAuthButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const GoogleAuthButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return buildGoogleAuthButton(onPressed: onPressed, label: label);
  }
}
