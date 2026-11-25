import 'package:flutter/material.dart';

void showMessage(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: onAction == null ? 3 : 5),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}
