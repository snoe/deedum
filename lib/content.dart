import 'dart:convert';
import 'dart:math' as math;

import 'package:deedum/shared.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final baseFontSize = 14.0;

class Content extends StatefulWidget {
  Content({this.contentData, this.onLink, this.onSearch});

  final ContentData contentData;
  final Function onLink;
  final Function onSearch;

  @override
  _ContentState createState() => _ContentState(
      contentData: contentData, onLink: onLink, onSearch: onSearch);
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
      var groups = buildGroups(context);
      widget = groupsToWidget(groups);
    } else if (contentData.mode == "search") {
      widget = Column(
          children: <Widget>[
                ExtendedText(contentData.content),
                DecoratedBox(
                    decoration: BoxDecoration(
                        color: _inputError ? Colors.deepOrange : null),
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
              (_inputError
                  ? [ExtendedText("\n\nInput too long: $_inputLength")]
                  : []));
    } else if (contentData.mode == "error") {
      widget = ExtendedText("An error occurred\n\n" + contentData.content);
    } else if (contentData.mode == "image") {
      widget = Image.memory(contentData.bytes, errorBuilder:
          (BuildContext context, Object exception, StackTrace stackTrace) {
        return ExtendedText("broken image ¯\\_(ツ)_/¯");
      });
    } else if (contentData.mode == "plain") {
      var groups = buildGroups(context, alwaysPre: true);
      widget = PreText(contentData.content, groups[0]["maxLine"]);
    } else if (contentData.mode == "opening") {
      widget = ExtendedText(contentData.content);
    } else {
      widget = ExtendedText("Unknown mode ${contentData.mode}");
    }
    return widget;
  }

  buildGroups(context, {alwaysPre = false}) {
    var lineInfo = LineSplitter.split(contentData.content)
        .fold({"groups": [], "parse?": true}, (r, line) {
      if (!alwaysPre && line.startsWith("```")) {
        r["parse?"] = !r["parse?"];
      } else if (alwaysPre || !r["parse?"]) {
        addToGroup(r, "pre", line);
      } else if (line.startsWith(">")) {
        addToGroup(r, "quote", line.substring(1));
      } else if (line.startsWith("#")) {
        var m = RegExp(r'^(#*)\s*(.*)$').firstMatch(line);
        var hashCount = math.min(m.group(1).length, 3);
        r["groups"]
            .add({"type": "header", "data": m.group(2), "size": hashCount});
      } else if (line.startsWith("=>")) {
        var m = RegExp(r'^=>\s*(\S+)\s*(.*)$').firstMatch(line);
        if (m != null) {
          var link = m.group(1);
          var rest = m.group(2).trim();
          var title = rest.isEmpty ? link : rest;
          r["groups"].add({"type": "link", "link": link, "data": title});
        }
      } else if (line.startsWith("* ")) {
        r["groups"].add({"type": "list", "data": line.substring(2)});
      } else {
        addToGroup(r, "line", line);
      }
      return r;
    });
    List groups = lineInfo["groups"];
    return groups;
  }

  void addToGroup(r, String type, String line) {
    if (r["groups"].isNotEmpty && r["groups"].last["type"] == type) {
      var group = r["groups"].removeLast();
      group["data"] += "\n" + line;
      group["maxLine"] = math.max(line.length, (group["maxLine"] as int));
      r["groups"].add(group);
    } else {
      r["groups"].add({"type": type, "data": line, "maxLine": line.length});
    }
  }

  groupsToWidget(groups) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groups.fold(<Widget>[], (widgets, r) {
          var type = r["type"];
          if (type == "pre") {
            widgets.add(PreText(r["data"], r["maxLine"]));
          } else if (type == "header") {
            widgets.add(heading(r["data"],
                baseFontSize + (20 - math.max(r['size'] * 5.4, 10))));
          } else if (type == "quote") {
            widgets.add(blockQuote(r["data"]));
          } else if (type == "link") {
            widgets.add(link(r["data"], r['link'], onLink, context));
          } else if (type == "list") {
            widgets.add(listItem(r["data"]));
          } else {
            widgets.add(plainText(r["data"]));
          }
          return widgets;
        }));
  }
}

class PreText extends StatefulWidget {
  final actualText;
  final maxLine;

  PreText(this.actualText, this.maxLine);

  @override
  _PreTextState createState() => _PreTextState(actualText, maxLine);
}

class _PreTextState extends State<PreText> {
  final actualText;

  int _scale;

  _PreTextState(this.actualText, maxLine) {
    if (maxLine > 120) {
      _scale = -1;
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
    var fit;
    var wrap = _scale != null;

    if (_scale == -1) {
      fit = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ExtendedText(
            actualText,
            selectionEnabled: true,
            style: TextStyle(
                fontFamily: "DejaVu Sans Mono", fontSize: baseFontSize),
          ));
    } else if (wrap) {
      double size = (TextPainter(
              text: TextSpan(
                  text: "0".padLeft(_scale),
                  style: TextStyle(
                      fontFamily: "DejaVu Sans Mono", fontSize: baseFontSize)),
              maxLines: 1,
              textScaleFactor: MediaQuery.of(context).textScaleFactor,
              textDirection: TextDirection.ltr)
            ..layout())
          .size
          .width;

      fit = FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
              child: ExtendedText(actualText,
                  softWrap: wrap,
                  style: TextStyle(
                      fontFamily: "DejaVu Sans Mono", fontSize: baseFontSize),
                  selectionEnabled: true),
              width: size));
    } else {
      fit = FittedBox(
          child: ExtendedText(actualText,
              selectionEnabled: true,
              style: TextStyle(
                  fontFamily: "DejaVu Sans Mono", fontSize: baseFontSize)),
          fit: BoxFit.fill);
    }
    var widget = GestureDetector(
        onDoubleTap: () async {
          var picked = await showMenu(
            items: <PopupMenuEntry>[
                  CheckedPopupMenuItem(
                      checked: _scale == null, value: null, child: Text("Fit"))
                ] +
                [-1, 32, 40, 64, 80, 120]
                    .map((i) => CheckedPopupMenuItem(
                        checked: _scale == i,
                        value: i,
                        child: Text("${i == -1 ? "Scroll" : i}")))
                    .toList(),
            context: context,
            position: RelativeRect.fromLTRB(20, 100, 400, 200),
          );
          setScale(picked);
        },
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(width: availableWidth, child: fit)));

    return widget;
  }
}

Widget plainText(data) {
  return SelectableText(data,
      style: TextStyle(
          fontWeight: FontWeight.w400,
          fontFamily: "Source Serif Pro",
          height: 1.5));
}

Widget heading(actualText, fontSize) {
  return Padding(
      padding: EdgeInsets.fromLTRB(0, 2, 0, 2),
      child: SelectableText(actualText,
          style: TextStyle(
              fontFamily: "Source Serif Pro",
              fontWeight: FontWeight.bold,
              fontSize: fontSize)));
}

Widget link(title, link, onLink, context) {
  Uri uri = Uri.parse(link);
  bool httpWarn = uri.scheme != "gemini" && uri.hasScheme;
  return GestureDetector(
      child: Padding(
          padding: EdgeInsets.fromLTRB(0, 7, 0, 7),
          child: Text((httpWarn ? "[${uri.scheme}] " : "") + title,
              style: TextStyle(
                  fontFamily: "Source Serif Pro",
                  color: httpWarn ? Colors.purple[300] : Colors.blue))),
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

Widget listItem(actualText) {
  return Row(crossAxisAlignment: CrossAxisAlignment.baseline, children: [
    Text("•"),
    Flexible(
        child: Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
            child: SelectableText(actualText,
                style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontFamily: "Source Serif Pro",
                    height: 1.7))))
  ]);
}

Widget blockQuote(actualText) {
  return DecoratedBox(
      decoration: BoxDecoration(
          border: Border(left: BorderSide(color: Colors.orange, width: 3))),
      child: Padding(
          padding: EdgeInsets.fromLTRB(15, 0, 0, 0),
          child: SelectableText(actualText,
              style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: "Source Serif Pro",
                  height: 1.7))));
}
