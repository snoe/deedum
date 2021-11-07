import 'package:flutter/material.dart';

class PlainText extends StatelessWidget {
  const PlainText({Key key, @required this.content}) : super(key: key);

  final String content;

  @override
  Widget build(BuildContext context) {
    return SelectableText(content,
        style: const TextStyle(fontWeight: FontWeight.w400, height: 1.5));
  }
}
