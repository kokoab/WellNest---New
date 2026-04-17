import 'package:flutter/material.dart';
import 'package:my_app/theme/app_theme.dart';

const String _refusalPrefix = 'I cannot help you with that';

bool isAssistantRefusal(String content) {
  return content.trimLeft().startsWith(_refusalPrefix);
}

/// A chat bubble styled for assistant topic-violation refusals:
/// light red background, info icon, and a one-time horizontal shake.
class SystemRefusalBubble extends StatefulWidget {
  final String text;

  const SystemRefusalBubble({super.key, required this.text});

  @override
  State<SystemRefusalBubble> createState() => _SystemRefusalBubbleState();
}

class _SystemRefusalBubbleState extends State<SystemRefusalBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 6, end: -5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5, end: 4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4, end: -2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -2, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeOut));

    _shakeCtrl.forward();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF3B1E1E)
        : const Color(0xFFFDEDED);
    final textColor = isDark
        ? const Color(0xFFFFB4AB)
        : const Color(0xFF6B1A1A);
    final iconColor = isDark
        ? const Color(0xFFFFB4AB)
        : kAccentOrange;

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: isDark
                ? const Color(0xFF5C2B2B)
                : const Color(0xFFF5C6C6),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Icon(Icons.info_outline, size: 20, color: iconColor),
            ),
            Expanded(
              child: Text(
                widget.text,
                style: TextStyle(
                  fontFamily: kFontAppFamily,
                  fontSize: 17,
                  color: textColor,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
