import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  String _userName = 'Alex R.'; // Default name

  String get userName => _userName;

  void setUserName(String name) {
    if (name.isNotEmpty) {
      _userName = name;
      notifyListeners();
    }
  }
}
