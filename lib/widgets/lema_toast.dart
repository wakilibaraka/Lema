import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/apple_theme.dart';

/// Frosted transient feedback (Slice 4, density rule §5).
///
/// Single-instance (clears previous), floats above the tab bar,
/// three variants: Saved (green) / Moved (blue, hosts the Undo action)
/// / Error (red). Sub-500ms ops never show blocking spinners.
enum LemaToastKind { saved, moved, error }

class LemaToast {
  static void show(
    BuildContext context,
    String message, {
    LemaToastKind kind = LemaToastKind.saved,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final Color accent;
    final IconData icon;
    switch (kind) {
      case LemaToastKind.saved:
        accent = AppleTheme.systemGreen;
        icon = CupertinoIcons.checkmark_alt_circle_fill;
        break;
      case LemaToastKind.moved:
        accent = AppleTheme.systemBlue;
        icon = CupertinoIcons.arrow_2_squarepath;
        break;
      case LemaToastKind.error:
        accent = AppleTheme.systemRed;
        icon = CupertinoIcons.exclamationmark_circle_fill;
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 108),
        duration: Duration(
            seconds: kind == LemaToastKind.moved ? 5 : 2,
            milliseconds: kind == LemaToastKind.moved ? 0 : 500),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1F).withAlpha(225),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Colors.white.withAlpha(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(70),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: accent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        messenger.clearSnackBars();
                        onAction?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          actionLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
