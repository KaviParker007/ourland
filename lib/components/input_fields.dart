import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BasicInputField extends StatelessWidget {
  final bool readOnly;
  final bool enabled;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? hintText;
  final double padding;
  final int? maxLines;
  final TextInputType? keyboardType;
  const BasicInputField({
    super.key,
    this.readOnly = false,
    this.enabled = true,
    required this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.hintText,
    this.padding = 0,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: readOnly,
      enabled: enabled,
      controller: controller,
      obscureText: obscureText,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        suffixIcon: suffixIcon,
        hintText: hintText,
        contentPadding: padding != 0 ? EdgeInsets.all(padding) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
      ),
    );
  }
}

class TextAreaField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final double padding;
  const TextAreaField({
    super.key,
    required this.controller,
    this.hintText,
    this.padding = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        contentPadding: padding != 0 ? EdgeInsets.all(padding) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
      ),
      keyboardType: TextInputType.multiline,
      minLines: 3,
      maxLines: 8,
    );
  }
}

class NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final double padding;
  final List<TextInputFormatter>? inputFormatters;
  const NumberField({
    super.key,
    required this.controller,
    this.hintText,
    this.padding = 0,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        contentPadding: padding != 0 ? EdgeInsets.all(padding) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
      ),
      inputFormatters: inputFormatters ?? [
        FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
      ],
      keyboardType: TextInputType.number,
    );
  }
}
