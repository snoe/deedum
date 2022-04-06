import 'package:flutter/material.dart';
import 'package:extended_text/extended_text.dart';

class PlainText extends StatelessWidget {
  const PlainText({Key? key, required this.content}) : super(key: key);

  final String content;

  @override
  Widget build(BuildContext context) {
    return ExtendedText(content,
        selectionEnabled: true,
        style: const TextStyle(fontWeight: FontWeight.w400, height: 1.5));
  }
}
