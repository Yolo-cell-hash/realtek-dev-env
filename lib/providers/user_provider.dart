import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  String _userId = '';
  String? _propertyName;
  String? _deviceName;


  String get userId => _userId;
  String? get propertyName => _propertyName;
  String? get deviceName => _deviceName;


  void setUserId(String userId) {
    _userId = userId;
    notifyListeners();
  }

  void setPropertyName(String name) {
    _propertyName = name;
    notifyListeners();
  }

  void setDeviceName(String name){
    _deviceName = name;
    notifyListeners();
  }
}
