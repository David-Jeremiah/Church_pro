import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Shows a readable message for any error.
void showAppError(Object error) {
  var message = error.toString().replaceFirst('Exception: ', '');
  if (error is FirebaseException) {
    message = switch (error.code) {
      'permission-denied' => 'You do not have permission to do that.',
      'unavailable' => 'No internet connection. Changes will sync when you are back online.',
      _ => error.message ?? error.code,
    };
  }
  rootMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
