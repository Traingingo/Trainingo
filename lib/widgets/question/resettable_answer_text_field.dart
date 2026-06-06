import 'package:flutter/material.dart';

class ResettableAnswerTextField extends StatefulWidget {
  final String resetKey;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final int maxLines;
  final String hintText;
  final TextStyle? style;

  const ResettableAnswerTextField({
    super.key,
    required this.resetKey,
    required this.value,
    required this.onChanged,
    required this.enabled,
    required this.maxLines,
    required this.hintText,
    this.style,
  });

  @override
  State<ResettableAnswerTextField> createState() => _ResettableAnswerTextFieldState();
}

class _ResettableAnswerTextFieldState extends State<ResettableAnswerTextField> {
  late final TextEditingController _controller;
  late String _lastResetKey;

  @override
  void initState() {
    super.initState();
    _lastResetKey = widget.resetKey;
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant ResettableAnswerTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextText = widget.value ?? '';
    final shouldReset = oldWidget.resetKey != widget.resetKey || _lastResetKey != widget.resetKey;

    if (shouldReset) {
      _lastResetKey = widget.resetKey;
      _controller.text = nextText;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      return;
    }

    if (_controller.text != nextText && nextText.isEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
      style: widget.style,
      decoration: InputDecoration(
        hintText: widget.hintText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1899D6), width: 2),
        ),
      ),
    );
  }
}
