import 'package:flutter/material.dart';
import 'package:terminal_color_parser/terminal_color_parser.dart';

import 'package:deedum/shared.dart';

import 'package:deedum/models/ansi_color.dart';


class AnsiPreText extends StatefulWidget {
  final String actualText;
  final int maxLine;
  final int ansiLevel;


  const AnsiPreText({Key? key, required this.actualText, required this.maxLine, required this.ansiLevel})
      : super(key: key);

  @override
  _AnsiPreTextState createState() => _AnsiPreTextState();
}

class _AnsiPreTextState extends State<AnsiPreText> {
  int? _scale;

  Color hexToColor(String code) {
    return  Color(int.parse(code.substring(1, 7), radix: 16) + 0xFF000000);
  }

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

    final coloredText = ColorParser(widget.actualText).parse();
    final spans = <TextSpan>[];

    for (final token in coloredText) {

      DefaultTextStyle defaultStyle = DefaultTextStyle.of(context);
      TextStyle style =  TextStyle(
        fontFamily: "DejaVu Sans Mono",
      );
      if (widget.ansiLevel >2) {
        style = TextStyle(
          fontFamily: "DejaVu Sans Mono",
          decoration: token.underline
              ? TextDecoration.underline
              : TextDecoration.none,
          fontWeight: token.bold ? FontWeight.bold : FontWeight.normal,
        );
      }
        style = style.merge(defaultStyle.style);

        if (token.hasFgColor) {
          if ( token.xterm256) { // get from the 256 colors "model"
            style = style.merge(TextStyle(
                color: hexToColor(AnsiColor.colors[token.fgColor])));
          }else{//8/16 colors
            style= style.merge( TextStyle(
                color: hexToColor(AnsiColor.simpleColors[token.fgColor].toString())));
          }
        }else if (token.rgbFg){
          int r,g,b;
          var rgbColors = token.rgbFgColor.split(';');
          r = int.parse(rgbColors[0]);
          g = int.parse(rgbColors[1]);
          b = int.parse(rgbColors[2]);
          style= style.merge( TextStyle(
              color: Color.fromRGBO(r, g, b, 1)
          ));
        }
        if (widget.ansiLevel >1) {
          if (token.hasBgColor) {
            if (token.xterm256) { // get from the 256 colors "model"
              style = style.merge(TextStyle(
                  backgroundColor: hexToColor(
                      AnsiColor.colors[token.bgColor].toString())));
            }
            else { //8/16 colors
              style = style.merge(TextStyle(
                  backgroundColor: hexToColor(
                      AnsiColor.simpleColors[token.bgColor].toString())));
            }
          } else if (token.rgbBg) {
            int r, g, b;
            var rgbColors = token.rgbBgColor.split(';');
            r = int.parse(rgbColors[0]);
            g = int.parse(rgbColors[1]);
            b = int.parse(rgbColors[2]);
            style = style.merge(TextStyle(
                backgroundColor: Color.fromRGBO(r, g, b, 1)
            ));
          }
        }
        //
      var span = TextSpan(text: token.text,
          style: style
      );

      spans.add(span);
    }
    TextSpan container = TextSpan(children: spans);
    RichText finalText = RichText(text: container);

    Widget fit;

    if (_scale == -1) {
      fit = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: finalText);
    } else if (_scale != null) {
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
              child: finalText
          )
        // ExtendedText(widget.actualText,
        //   softWrap: true,
        //   style: const TextStyle(
        //       fontFamily: "DejaVu Sans Mono", fontSize: baseFontSize),
        // ),
      );
    } else {
      fit = FittedBox(
          child: finalText,
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
