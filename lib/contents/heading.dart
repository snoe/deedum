import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';

class Heading extends StatelessWidget {
  const Heading({
    Key? key,
    required this.content,
    required this.fontSize,
  }) : super(key: key);

  final String content;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
      child: ExtendedText(
        content,
        selectionEnabled: true,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
