library ui_kit;

import 'package:flutter/material.dart';

export 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  
  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Theme.of(context).primaryColor,
      ),
      child: Text(text),
    );
  }
}

class AppDialog {
  static Future<void> showAlert(
    BuildContext context, {
    required String title,
    required String content,
    String okText = 'OK',
  }) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(okText),
            ),
          ],
        );
      },
    );
  }
}
