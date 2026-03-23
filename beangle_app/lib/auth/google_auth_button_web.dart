import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

Widget buildGoogleAuthButton({
  required VoidCallback onPressed,
  required String label,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      gsi_web.renderButton(
        configuration: gsi_web.GSIButtonConfiguration(
          type: gsi_web.GSIButtonType.standard,
          text: gsi_web.GSIButtonText.continueWith,
          shape: gsi_web.GSIButtonShape.rectangular,
          size: gsi_web.GSIButtonSize.large,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ],
  );
}
