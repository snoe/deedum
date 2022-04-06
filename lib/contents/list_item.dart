import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';

class ListItem extends StatelessWidget {
  const ListItem({Key? key, required this.content}) : super(key: key);

  final String content;

  @override
  Widget build(BuildContext context) {
    return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Text("•"),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
              child: ExtendedText(
                content,
                selectionEnabled: true,
                style:
                    const TextStyle(fontWeight: FontWeight.w400, height: 1.7),
              ),
            ),
          )
        ]);
  }
}
