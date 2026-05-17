import 'package:flutter/material.dart';

// Bottom padding for list views — clears the floating nav bar + system nav bar
double navBottomPadding(BuildContext context) {
  // 62 nav height + 12 margin + 12 buffer + system inset
  return 86 + MediaQuery.of(context).viewPadding.bottom;
}
