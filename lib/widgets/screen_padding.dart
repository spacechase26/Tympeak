import 'package:flutter/material.dart';

// Small bottom buffer for scrollable content. Actual nav-bar clearance is
// reserved at the screen-content level by main.dart's outer Padding, so
// individual screens don't need to compute nav geometry here.
double navBottomPadding(BuildContext context) {
  return 16;
}
