import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/services.dart';

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

  final baseFontSize = 17.0;
  bool _inputError = false;
  int _inputLength = 0;

  _setInputError(value, length) {
    setState(() {
      _inputError = value;
      _inputLength = length;
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
      var availableWidth = MediaQuery.of(context).size.width - (padding * 2);

      widget = Container(
          width: availableWidth,
          child: FittedBox(
              fit: BoxFit.fill,
              child: ExtendedText(contentData.content,
                  style: TextStyle(fontFamily: "DejaVu Sans Mono"), selectionEnabled: true)));
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
    var availableWidth = MediaQuery.of(context).size.width;
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groups.fold(<Widget>[], (widgets, r) {
          var type = r["type"];
          if (type == "pre") {
            widgets.add(preText(r["data"], availableWidth));
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

Widget plainText(data) {
  return SelectableText(data, style: TextStyle(fontWeight: FontWeight.w300, fontFamily: "Merriweather", height: 1.7));
}

Widget preText(actualText, availableWidth) {
  return Container(
      width: availableWidth - (padding * 2),
      child: FittedBox(
          fit: BoxFit.fill, child: SelectableText(actualText, style: TextStyle(fontFamily: "DejaVu Sans Mono"))));
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
