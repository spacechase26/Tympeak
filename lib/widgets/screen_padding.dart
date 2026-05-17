import 'package:flutter/material.dart';

// Bottom padding for list views — clears the floating nav bar + system nav bar
// Nav: 62 (height) + 12 (outer margin) + viewPadding.bottom (gesture inset)
// + generous 28 buffer so cards / text never touch the glass nav strip.
double navBottomPadding(BuildContext context) {
  return 102 + MediaQuery.of(context).viewPadding.bottom;
}
