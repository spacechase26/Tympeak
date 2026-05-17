import 'package:flutter/material.dart';

final appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF7C3AED),
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF08080F),
  fontFamily: 'sans-serif',
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: InputBorder.none,
  ),
);

const kPurple      = Color(0xFF7C3AED);
const kPurpleLight = Color(0xFFA78BFA);
const kPurpleDim   = Color(0xFF4C1D95);
const kBlue        = Color(0xFF1E40AF);
const kBgDeep      = Color(0xFF08080F);
const kBgCard      = Color(0xFF111118);
const kGlassColor  = Color(0x18FFFFFF);
const kGlassBorder = Color(0x28FFFFFF);
