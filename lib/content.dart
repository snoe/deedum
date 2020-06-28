import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/services.dart';

final baseFontSize = 17.0;

class Content extends StatefulWidget {
  Content({this.contentData, this.onLink, this.onSearch});

  final ContentData contentData;
  final Function onLink;
  final Function onSearch;

  @override
  _ContentState createState() => _ContentState(contentData: contentData, onLink: onLink, onSearch: onSearch);
}

class _ContentState extends State<Content> {
  _ContentState({this.contentData, this.onLink, this.onSearch});

  final ContentData contentData;
  final Function onLink;
  final Function onSearch;

  var plainTextControls = false;
  bool _inputError = false;
  int _inputLength = 0;

  _setInputError(value, length) {
    setState(() {
      _inputError = value;
      _inputLength = length;
    });
  }

  showControls(show) {
    setState(() {
      plainTextControls = show;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget widget;
    if (contentData == null) {
      widget = Text("");
    } else if (contentData.mode == "content") {
      widget = buildFold(context);
    } else if (contentData.mode == "search") {
      widget = Column(
          children: <Widget>[
                ExtendedText(contentData.content),
                DecoratedBox(
                    decoration: BoxDecoration(color: _inputError ? Colors.deepOrange : null),
                    child: TextField(onSubmitted: (value) {
                      var encodedSearch = Uri.encodeComponent(value);
                      if (encodedSearch.length <= 1024) {
                        onSearch(encodedSearch);
                        _setInputError(false, encodedSearch.length);
                      } else {
                        _setInputError(true, encodedSearch.length);
                      }
                    }))
              ] +
              (_inputError ? [ExtendedText("\n\nInput too long: $_inputLength")] : []));
    } else if (contentData.mode == "error") {
      widget = ExtendedText("An error occurred\n\n" + contentData.content);
    } else if (contentData.mode == "image") {
      widget = Image.memory(contentData.bytes,
          errorBuilder: (BuildContext context, Object exception, StackTrace stackTrace) {
        return ExtendedText("broken image ¯\\_(ツ)_/¯");
      });
    } else if (contentData.mode == "plain") {
      widget = PreText(contentData.content);
    } else {
      widget = ExtendedText("Unknown mode ${contentData.mode}");
    }
    return widget;
  }

  buildFold(context) {
    var lineInfo = LineSplitter.split(contentData.content).fold({"groups": [], "parse?": true}, (r, line) {
      if (line.startsWith("```")) {
        r["parse?"] = !r["parse?"];
      } else if (!r["parse?"]) {
        addToGroup(r, "pre", line);
      } else if (line.startsWith(">")) {
        addToGroup(r, "quote", line.substring(1));
      } else if (line.startsWith("#")) {
        var m = RegExp(r'^(#*)\s*(.*)$').firstMatch(line);
        var hashCount = math.min(m.group(1).length, 3);
        r["groups"].add({"type": "header", "data": m.group(2), "size": hashCount});
      } else if (line.startsWith("=>")) {
        var m = RegExp(r'^=>\s*(\S+)\s*(.*)$').firstMatch(line);
        if (m != null) {
          var link = m.group(1);
          var rest = m.group(2).trim();
          var title = rest.isEmpty ? link : rest;
          r["groups"].add({"type": "link", "link": link, "data": title});
        }
      } else {
        addToGroup(r, "line", line);
      }
      return r;
    });
    List groups = lineInfo["groups"];
    return groupsToWidget(groups);
  }

  void addToGroup(r, String type, String line) {
    if (r["groups"].isNotEmpty && r["groups"].last["type"] == type) {
      var group = r["groups"].removeLast();
      group["data"] += "\n" + line;
      r["groups"].add(group);
    } else {
      r["groups"].add({"type": type, "data": line});
    }
  }

  groupsToWidget(groups) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groups.fold(<Widget>[], (widgets, r) {
          var type = r["type"];
          if (type == "pre") {
            widgets.add(PreText(r["data"]));
          } else if (type == "header") {
            widgets.add(heading(r["data"], baseFontSize + (15 - math.max(r['size'] * 5, 15))));
          } else if (type == "quote") {
            widgets.add(blockQuote(r["data"]));
          } else if (type == "link") {
            widgets.add(link(r["data"], r['link'], onLink, context));
          } else {
            widgets.add(plainText(r["data"]));
          }
          return widgets;
        }));
  }
}

class PreText extends StatefulWidget {
  final actualText;

  PreText(this.actualText);

  @override
  _PreTextState createState() => _PreTextState(actualText);
}

class _PreTextState extends State<PreText> {
  final actualText;

  int _scale = null;

  _PreTextState(this.actualText);

  setScale(s) {
    setState(() {
      _scale = s;
    });
  }

  @override
  Widget build(BuildContext context) {
    var availableWidth = MediaQuery.of(context).size.width - (padding * 2);
    var fit;
    var wrap = _scale != null;

    if (wrap) {
      double size = (TextPainter(
              text: TextSpan(
                  text: "0123456789", style: TextStyle(fontFamily: "DejaVu Sans Mono", fontSize: baseFontSize)),
              maxLines: 1,
              textScaleFactor: MediaQuery.of(context).textScaleFactor,
              textDirection: TextDirection.ltr)
            ..layout())
          .size
          .width;

      var ratio = wrap ? ((availableWidth / size) / _scale) : 1;

      fit = SizedBox(
          child: ExtendedText(actualText,
              softWrap: wrap,
              style: TextStyle(fontFamily: "DejaVu Sans Mono", fontSize: ratio * baseFontSize),
              selectionEnabled: true),
          width: availableWidth);
    } else {
      fit = FittedBox(
          child: SelectableText(actualText, //selectionEnabled: true,
              style: TextStyle(fontFamily: "DejaVu Sans Mono", fontSize: baseFontSize)),
          fit: BoxFit.fill);
    }
    var widget = GestureDetector(
        onDoubleTap: () {
          showMenu(
            items: <PopupMenuEntry>[
              PopupMenuItem(
                  value: null,
                  child: Row(children: [
                    IconButton(
                        icon: Icon(Icons.format_clear),
                        onPressed: () {
                          setScale(null);
                        }),
                    IconButton(
                        icon: Text("20"),
                        onPressed: () {
                          setScale(2);
                        }),
                    IconButton(
                        icon: Text("40"),
                        onPressed: () {
                          setScale(4);
                        }),
                    IconButton(
                        icon: Text("80"),
                        onPressed: () {
                          setScale(8);
                        }),
                    IconButton(
                        icon: Text("120"),
                        onPressed: () {
                          setScale(12);
                        }),
                  ])),
            ],
            context: context,
            position: RelativeRect.fromLTRB(0, 100, 0, 100),
          );
        },
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal, child: Container(width: availableWidth, child: fit)));

    return widget;
  }
}

Widget plainText(data) {
  return SelectableText(data, style: TextStyle(fontWeight: FontWeight.w300, fontFamily: "Merriweather", height: 1.7));
}

Widget heading(actualText, fontSize) {
  return Padding(
      padding: EdgeInsets.fromLTRB(0, fontSize, 0, fontSize),
      child: SelectableText(actualText,
          style: TextStyle(fontFamily: "Merriweather", fontWeight: FontWeight.bold, fontSize: fontSize)));
}

Widget link(title, link, onLink, context) {
  return GestureDetector(
      child: Padding(
          padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
          child: Text(title, style: TextStyle(fontFamily: "Merriweather", color: Color.fromARGB(255, 0, 0, 255)))),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: link)).then((result) {
          final snackBar = SnackBar(content: Text('Copied to Clipboard'));
          Scaffold.of(context).showSnackBar(snackBar);
        });
      },
      onTap: () {
        onLink(link);
      });
}

Widget blockQuote(actualText) {
  return DecoratedBox(
      decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.orange, width: 3))),
      child: Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
          child: SelectableText(actualText,
              style: TextStyle(fontWeight: FontWeight.w300, fontFamily: "Merriweather", height: 1.7))));
}
