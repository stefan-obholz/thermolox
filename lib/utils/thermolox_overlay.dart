import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ThermoloxOverlay {
  const ThermoloxOverlay._();

  static Future<T?> showSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    bool useSafeArea = false,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    ShapeBorder? shape,
    bool useRootNavigator = false,
  }) {
    final tokens = context.thermoloxTokens;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useRootNavigator: useRootNavigator,
      backgroundColor:
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      shape: shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(tokens.radiusSheet),
            ),
          ),
      builder: builder,
    );
  }

  static Future<T?> showAppDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    String? barrierLabel,
    bool useRootNavigator = true,
  }) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final dialogTheme = theme.dialogTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
    );

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      useRootNavigator: useRootNavigator,
      builder: (dialogContext) {
        return Theme(
          data: theme.copyWith(dialogTheme: dialogTheme),
          child: Builder(builder: builder),
        );
      },
    );
  }

  static Future<T?> showGlassDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    String? barrierLabel,
    Color? barrierColor,
    Duration? transitionDuration,
    bool useRootNavigator = true,
    RouteTransitionsBuilder? transitionBuilder,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: barrierColor ?? Colors.black54,
      transitionDuration:
          transitionDuration ?? const Duration(milliseconds: 220),
      transitionBuilder: transitionBuilder,
      pageBuilder: (dialogContext, _, __) => builder(dialogContext),
      useRootNavigator: useRootNavigator,
    );
  }

  static void showSnack(
    BuildContext context,
    String message, {
    bool isError = false,
    SnackBarAction? action,
  }) {
    final theme = Theme.of(context);
    final background = isError
        ? theme.colorScheme.error
        : (theme.snackBarTheme.backgroundColor ?? Colors.black87);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: background,
          action: action,
        ),
      );
  }

  static Future<String?> promptText({
    required BuildContext context,
    required String title,
    String? hintText,
    String? initialValue,
    String confirmLabel = 'OK',
    String cancelLabel = 'Abbrechen',
    bool autofocus = true,
  }) async {
    var value = initialValue ?? '';
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: value,
          decoration: InputDecoration(hintText: hintText),
          autofocus: autofocus,
          onChanged: (next) => value = next,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    final trimmed = value.trim();
    if (ok == true && trimmed.isNotEmpty) {
      return trimmed;
    }
    return null;
  }

  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    String? message,
    String confirmLabel = 'OK',
    String cancelLabel = 'Abbrechen',
  }) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }
}
