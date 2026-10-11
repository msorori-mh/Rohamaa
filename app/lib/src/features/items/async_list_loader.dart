import 'package:flutter/material.dart';

import '../../core/app_error.dart';

/// Loads a list once, keeps it on screen while it is refreshed, and gives
/// every state (loading, error, empty, data) a working pull-to-refresh.
///
/// The [RefreshIndicator] stays mounted across states, so a refresh that is
/// in flight is never torn down by the result arriving.
mixin AsyncListLoader<W extends StatefulWidget, T> on State<W> {
  List<T>? loadedRows;
  Object? loadError;

  /// Fetches the rows from the backend.
  Future<List<T>> fetchRows();

  /// Reloads the rows. Never throws: a failure is kept in [loadError] when
  /// nothing is on screen yet, or shown as a snackbar when rows are visible.
  Future<void> reloadRows() async {
    try {
      final rows = await fetchRows();
      if (!mounted) return;
      setState(() {
        loadedRows = rows;
        loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (loadedRows == null) {
        setState(() => loadError = error);
      } else {
        showErrorSnack(context, error);
      }
    }
  }

  /// Clears a load error and tries again, showing the loading state.
  void retryRows() {
    setState(() => loadError = null);
    reloadRows();
  }

  /// Builds the list area. [builder] must return a scrollable with
  /// [AlwaysScrollableScrollPhysics]. It receives a non-empty list, unless
  /// [empty] is null: then it is also called for an empty list, for screens
  /// that keep a header above their own empty message.
  Widget buildAsyncList({
    required Widget? empty,
    required Widget Function(List<T> rows) builder,
  }) {
    final rows = loadedRows;
    final error = loadError;
    final Widget child;
    if (rows == null && error != null) {
      child = ErrorRetry(error: error, onRetry: retryRows);
    } else if (rows == null) {
      child = const Center(child: CircularProgressIndicator());
    } else if (rows.isEmpty && empty != null) {
      child = ScrollableEmpty(child: empty);
    } else {
      child = builder(rows);
    }
    return RefreshIndicator(onRefresh: reloadRows, child: child);
  }
}
