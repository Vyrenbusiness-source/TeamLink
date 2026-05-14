// ignore_for_file: public_member_api_docs

import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/models/task.dart';
import 'package:flutter/material.dart';

/// Returns a localized `(label, color)` mapping for each [TaskStatus].
///
/// Strings come from [AppStrings] so callers should pass the current
/// locale's strings (e.g. via `ref.watch(appStringsProvider)`).
Map<TaskStatus, (String, Color)> taskStatusTheme(AppStrings s) => {
      TaskStatus.open: (s.taskStatusOpen, Colors.blue),
      TaskStatus.taken: (s.taskStatusTaken, Colors.indigo),
      TaskStatus.done: (s.taskStatusDone, Colors.green),
    };
