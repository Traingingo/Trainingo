import 'package:flutter/material.dart';

class DuoButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final Color shadowColor;
  final Color textColor;
  final IconData? icon;

  const DuoButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = const Color(0xFF58CC02),
    this.shadowColor = const Color(0xFF46A302),
    this.textColor = Colors.white,
    this.icon,
  });

  @override
  State<DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<DuoButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onPressed != null;
    final Color buttonColor = isEnabled ? widget.color : Colors.grey.shade300;
    final Color bottomColor = isEnabled ? widget.shadowColor : Colors.grey.shade400;

    return GestureDetector(
      onTapDown: isEnabled
          ? (_) {
              setState(() {
                _isPressed = true;
              });
            }
          : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() {
                _isPressed = false;
              });
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: isEnabled
          ? () {
              setState(() {
                _isPressed = false;
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        margin: EdgeInsets.only(
          top: _isPressed ? 4.0 : 0.0,
          bottom: _isPressed ? 0.0 : 4.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        height: 52,
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            bottom: BorderSide(
              color: bottomColor,
              width: _isPressed ? 0 : 4,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: widget.textColor, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              widget.text,
              style: TextStyle(
                color: isEnabled ? widget.textColor : Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
