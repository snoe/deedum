import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:deedum/main.dart';
import 'package:deedum/parser.dart';
import 'package:deedum/shared.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final baseFontSize = 14.0;

class Content extends StatefulWidget {
  Content(
      {this.currentUri,
      this.contentData,
      this.viewSource,
      this.onLocation,
      this.onSearch,
      this.onNewTab});

  final Uri currentUri;
  final ContentData contentData;
  final bool viewSource;
  final Function onLocation;
  final Function onSearch;
  final Function onNewTab;

  @override
  _ContentState createState() => _ContentState(
        currentUri: currentUri,
        contentData: contentData,
        viewSource: viewSource,
        onLocation: onLocation,
        onSearch: onSearch,
        onNewTab: onNewTab,
      );
}

class _ContentState extends State<Content> {
  _ContentState(
      {this.currentUri,
      this.contentData,
      this.viewSource,
      this.onLocation,
      this.onSearch,
      this.onNewTab});

  final Uri currentUri;
  final ContentData contentData;
  final bool viewSource;
  final Function onLocation;
  final Function onSearch;
  final Function onNewTab;

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
    } else if (viewSource) {
      widget = SelectableText(contentData.content,
          style: TextStyle(
              fontFamily: "DejaVu Sans Mono", fontSize: baseFontSize));
    } else if (contentData.mode == "plain") {
      var groups = analyze(contentData.content, alwaysPre: true);
      widget = PreText(contentData.content, groups[0]["maxLine"]);
    } else if (contentData.mode == "content") {
      var groups = analyze(contentData.content);
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
    } else if (contentData.mode == "opening") {
      widget = ExtendedText(contentData.content);
    } else {
      widget = ExtendedText("Unknown mode ${contentData.mode}");
    }
    return widget;
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
            widgets.add(link(r["data"], r['link'], currentUri, onLocation,
                onNewTab, context));
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
      style: TextStyle(fontWeight: FontWeight.w400, height: 1.5));
}

Widget heading(actualText, fontSize) {
  return Padding(
      padding: EdgeInsets.fromLTRB(0, 2, 0, 2),
      child: SelectableText(actualText,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)));
}

void linkLongPressMenu(title, uri, onNewTab, oldContext) =>
    showModalBottomSheet<void>(
        context: oldContext,
        builder: (BuildContext context) {
          return Container(
            constraints: new BoxConstraints(
              minHeight: 50,
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            // color: Colors.amber,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(title: Center(child: Text(uri.toString()))),
                ListTile(
                  title: Center(child: Text("Copy link")),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: uri.toString()))
                        .then((result) {
                      final snackBar =
                          SnackBar(content: Text('Copied to Clipboard'));
                      Scaffold.of(oldContext).showSnackBar(snackBar);
                      Navigator.pop(context);
                    });
                  },
                ),
                ListTile(
                  title: Center(child: Text("Copy link text")),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: title))
                        .then((result) {
                      final snackBar =
                          SnackBar(content: Text('Copied to Clipboard'));
                      Scaffold.of(oldContext).showSnackBar(snackBar);
                      Navigator.pop(context);
                    });
                  },
                ),
                ListTile(
                  title: Center(child: Text("Open link in new tab")),
                  onTap: () {
                    Navigator.pop(context);
                    onNewTab(initialLocation: uri.toString());
                  },
                ),
              ],
            ),
          );
        });

Widget link(title, link, currentUri, onLocation, onNewTab, context) {
  Uri uri = resolveLink(currentUri, link);
  bool httpWarn = uri.scheme != "gemini";
  bool visited = appKey.currentState.recents.contains(uri.toString());
  return GestureDetector(
      child: Padding(
          padding: EdgeInsets.fromLTRB(0, 7, 0, 7),
          child: Text((httpWarn ? "[${uri.scheme}] " : "") + title,
              style: TextStyle(
                  color: httpWarn
                      ? (visited ? Colors.purple[100] : Colors.purple[300])
                      : (visited ? Colors.blueGrey : Colors.blue)))),
      onLongPress: () => linkLongPressMenu(title, uri, onNewTab, context),
      onTap: () {
        onLocation(uri);
      });
}

Widget listItem(actualText) {
  return Row(crossAxisAlignment: CrossAxisAlignment.baseline, children: [
    Text("•"),
    Flexible(
        child: Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
            child: SelectableText(actualText,
                style: TextStyle(fontWeight: FontWeight.w400, height: 1.7))))
  ]);
}

Widget blockQuote(actualText) {
  return DecoratedBox(
      decoration: BoxDecoration(
          border: Border(left: BorderSide(color: Colors.orange, width: 3))),
      child: Padding(
          padding: EdgeInsets.fromLTRB(15, 0, 0, 0),
          child: SelectableText(actualText,
              style: TextStyle(fontWeight: FontWeight.w400, height: 1.7))));
}
