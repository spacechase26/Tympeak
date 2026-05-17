import 'package:flutter/material.dart';

final appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF7C3AED),
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF0A0A0F),
  fontFamily: 'sans-serif',
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
  ),
);

const kGlassColor = Color(0x1AFFFFFF);
const kGlassBorder = Color(0x33FFFFFF);
const kPurple = Color(0xFF7C3AED);
const kPurpleLight = Color(0xFFA78BFA);
const kBgDeep = Color(0xFF0A0A0F);
const kBgCard = Color(0xFF13131A);
