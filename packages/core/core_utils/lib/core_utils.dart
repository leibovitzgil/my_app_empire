library core_utils;

import 'package:intl/intl.dart';

/// Shared utility functions for date formatting and extensions.
class CoreUtils {
  static String formatDate(DateTime date) {
    return DateFormat.yMd().format(date);
  }
}
