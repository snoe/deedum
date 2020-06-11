import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:deedum/shared.dart';

class Content extends StatelessWidget {
  Content({this.contentData, this.onLink, this.onSearch});
  final ContentData contentData;
  final Function onLink;
  final Function onSearch;
  final baseFontSize = 17.0;
  final _padding = 25.0;

  final _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    List<Widget> widgets;
    if (contentData == null) {
      widgets = [Text("Nothing to see here")];
    } else if (contentData.mode == "content") {
      widgets = buildFold(context);
    } else if (contentData.mode == "search") {
      widgets = [
        Text(contentData.content.join("\n")),
        TextField(onSubmitted: (value) {
          onSearch(value);
        })
      ];
    } else if (contentData.mode == "error") {
      widgets = [
        Text("An error occurred\n\n"),
        Text(contentData.content.join("\n"))
      ];
    } else if (contentData.mode == "image") {
      widgets = [Image.memory(contentData.bytes)];
    } else if (contentData.mode == "plain") {
      contentData.content.insert(0, "```");
      widgets = buildFold(context);
    } else {
      widgets = [Text("Unknown mode ${contentData.mode}")];
    }
    return Padding(
        padding: EdgeInsets.all(_padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: widgets,
          crossAxisAlignment: CrossAxisAlignment.start,
        ));
  }

  buildFold(context) {
    var lineInfo =
        contentData.content.fold({"lines": [], "parse?": true}, (r, line) {
      if (line.startsWith("```")) {
        r["parse?"] = !r["parse?"];
      } else if (!r["parse?"]) {
        if (r["lines"].isNotEmpty && r["lines"].last["type"] == "pre") {
          var last = r["lines"].removeLast();
          last["prelines"].add(line);
          var lastLine = last["max"];
          if (lastLine.length < line.length) {
            last["max"] = line;
          }
          r["lines"].add(last);
        } else {
          r["lines"].add({
            "type": "pre",
            "prelines": [line],
            "max": line
          });
        }
      } else if (line.startsWith(">")) {
        r["lines"].add({"type": "quote", "line": line.substring(1)});
      } else if (line.startsWith("#")) {
        var m = RegExp(r'^(#*)\s*(.*)$').firstMatch(line);
        var hashCount = math.min(m.group(1).length, 3);
        r["lines"]
            .add({"type": "header", "line": m.group(2), "size": hashCount});
      } else if (line.startsWith("=>")) {
        var m = RegExp(r'^=>\s*(\S+)\s*(.*)$').firstMatch(line);
        if (m != null) {
          var link = m.group(1);
          var rest = m.group(2).trim();
          var title = rest.isEmpty ? link : rest;
          r["lines"].add({"type": "link", "link": link, "title": title});
        }
      } else {
        r["lines"].add({"type": "line", "line": line});
      }
      return r;
    });
    List lines = lineInfo["lines"];

    return lines.fold(<Widget>[], (widgets, r) {
      var type = r["type"];
      if (type == "pre") {
        var availableWidth = MediaQuery.of(context).size.width;
        widgets.add(Container(
            width: availableWidth,
            child: FittedBox(
                fit: BoxFit.fill,
                child: Text(r["prelines"].join("\n"),
                    style: TextStyle(fontFamily: "DejaVu Sans Mono")))));
      } else if (type == "header") {
        var extraSize = (15 - math.max(r["size"] * 5, 15));
        widgets.add(Padding(
            padding: EdgeInsets.fromLTRB(
                0, baseFontSize + extraSize, 0, baseFontSize + extraSize),
            child: Text(r["line"],
                style: TextStyle(
                    fontFamily: "Merriweather",
                    fontWeight: FontWeight.bold,
                    fontSize: (baseFontSize + extraSize)))));
      } else if (type == "quote") {
        widgets.add(DecoratedBox(
            decoration: BoxDecoration(
                border:
                    Border(left: BorderSide(color: Colors.orange, width: 3))),
            child: Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
                child: Text(r["line"],
                    style: TextStyle(
                        fontSize: baseFontSize,
                        fontWeight: FontWeight.w300,
                        fontFamily: "Merriweather",
                        height: 1.7)))));
      } else if (type == "link") {
        widgets.add(GestureDetector(
            child: Padding(
                padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
                child: Text(r["title"],
                    style: TextStyle(
                        fontSize: baseFontSize,
                        fontFamily: "Merriweather",
                        color: Color.fromARGB(255, 0, 0, 255)))),
            onTap: () {
              onLink(r["link"]);
            }));
      } else {
        widgets.add(Text(r["line"],
            style: TextStyle(
                fontSize: baseFontSize,
                fontWeight: FontWeight.w300,
                fontFamily: "Merriweather",
                height: 1.7)));
      }
      return widgets;
    });
  }
}
