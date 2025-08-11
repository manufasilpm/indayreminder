import 'package:flutter/material.dart';

ThemeData lightTheme = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true);
ThemeData dartTheme = ThemeData.dark().copyWith(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark),
);
