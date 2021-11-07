import 'package:flutter/material.dart';

class BlockQuote extends StatelessWidget {
  const BlockQuote({Key? key, required this.content}) : super(key: key);

  final String content;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Colors.orange, width: 3))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
        child: SelectableText(
          content,
          style: const TextStyle(fontWeight: FontWeight.w400, height: 1.7),
        ),
      ),
    );
  }
}
