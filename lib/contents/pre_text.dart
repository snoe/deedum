
import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';

import 'package:deedum/shared.dart';


class PreText extends StatefulWidget {
  final String actualText;
  final int maxLine;

  const PreText({Key? key, required this.actualText, required this.maxLine})
      : super(key: key);

  @override
  _PreTextState createState() => _PreTextState();
}

class _PreTextState extends State<PreText> {
  int? _scale;

  @override
  initState() {
    super.initState();
    if (widget.maxLine > 120) {
      _scale = -1;
    }
    if (widget.maxLine <= 32) {
      _scale = 32;
    }
  }

  setScale(s) {
    setState(() {
      _scale = s;
    });
  }

  @override
  Widget build(BuildContext context) {
    var availableWidth = MediaQuery.of(context).size.width - (padding * 2);
    Widget fit;

    if (_scale == -1) {
      fit = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ExtendedText(
            widget.actualText,
            selectionEnabled: true,
            style: const TextStyle(
              fontFamily: "DejaVu Sans Mono",
              fontSize: baseFontSize,
            ),
          ));
    } else if (_scale != null) {
      //selectionEnabled: true, //not sure if this is allowed here
      double size = (TextPainter(
          text: TextSpan(
            text: "0".padLeft(_scale!),
            style: const TextStyle(
              fontFamily: "DejaVu Sans Mono",
              fontSize: baseFontSize,
            ),
          ),
          maxLines: 1,
          textScaleFactor: MediaQuery.of(context).textScaleFactor,
          textDirection: TextDirection.ltr)
        ..layout())
          .size
          .width;

      fit = FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: size,
            child: ExtendedText(widget.actualText,
              selectionEnabled: true,
              softWrap: true,
              style: const TextStyle(
                  fontFamily: "DejaVu Sans Mono", fontSize: baseFontSize),
            ),
          ));
    } else {
      fit = FittedBox(
          child: ExtendedText(widget.actualText,
		      selectionEnabled: true,
              style: const TextStyle(
                  fontFamily: "DejaVu Sans Mono", fontSize: baseFontSize)),
          fit: BoxFit.fill);
    }
    var res = GestureDetector(
        onDoubleTap: () async {
          var picked = await showMenu(
            items: <PopupMenuEntry>[
              CheckedPopupMenuItem(
                  checked: _scale == null,
                  value: null,
                  child: const Text("Fit"))
            ] +
                [-1, 32, 40, 64, 80, 120]
                    .map((i) => CheckedPopupMenuItem(
                    checked: _scale == i,
                    value: i,
                    child: Text("${i == -1 ? "Scroll" : i}")))
                    .toList(),
            context: context,
            position: const RelativeRect.fromLTRB(20, 100, 400, 200),
          );
          setScale(picked);
        },
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: availableWidth, child: fit)));

    return res;
  }
}