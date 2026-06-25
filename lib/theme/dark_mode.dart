import 'package:flutter/material.dart';

ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    background: Color.fromARGB(255, 19, 18, 23),
    primary: Color.fromARGB(255, 105, 108, 255),
    onPrimary: Colors.white,
    secondary: Color.fromARGB(255, 133, 146, 163),
    tertiary: Color.fromARGB(255, 113, 221, 55),
    error: Color.fromARGB(255, 255, 62, 29),
    inversePrimary: Color.fromARGB(255, 35, 52, 70),
  ),
  cardTheme:  CardThemeData(
    color: Color.fromARGB(255, 29, 28, 36),
    elevation: 0,
  ),
  dividerTheme: const DividerThemeData(color: Colors.transparent),
  textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: Colors.grey[300],
        displayColor: Colors.white,
      ),
);
