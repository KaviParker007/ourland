import 'package:flutter/material.dart';

class LabelText extends StatelessWidget {
  final String text;
  final TextOverflow? overflow;
  const LabelText({
    super.key,
    required this.text,
    this.overflow
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 17,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.grey[600]
                : Colors.grey,
            overflow: overflow,
          ),
        ),
      ],
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color backgroundColor;
  final double fontsize;
  final double verticalPadding;
  const Pill({
    super.key,
    required this.text,
    required this.textColor,
    required this.backgroundColor,
    this.fontsize = 0,
    this.verticalPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      padding: const EdgeInsets.symmetric(
        vertical: 0,
        horizontal: 5,
      ),
      label: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontsize > 0 ? fontsize : null,
        ),
      ),
      backgroundColor: backgroundColor,
      labelPadding: EdgeInsets.symmetric(
        horizontal: 2,
        vertical: verticalPadding,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(22),
        ),
        side: BorderSide(color: Colors.transparent),
      ),
    );
  }
}
