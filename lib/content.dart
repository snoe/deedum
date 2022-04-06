// ignore: unused_import
import 'dart:developer';
import 'dart:math' as math;

import 'package:deedum/contents/blockquote.dart';
import 'package:deedum/contents/heading.dart';
import 'package:deedum/contents/link.dart';
import 'package:deedum/contents/list_item.dart';
import 'package:deedum/contents/plain_text.dart';
import 'package:deedum/models/content_data.dart';
import 'package:deedum/parser.dart';
import 'package:deedum/shared.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';

const baseFontSize = 16.0;

class Content extends StatefulWidget {
  const Content({
    Key? key,
    required this.contentData,
    required this.viewSource,
    required this.onLocation,
    required this.onNewTab,
  }) : super(key: key);

  final ContentData? contentData;
  final bool viewSource;
  final Function onLocation;
  final Function onNewTab;

  @override
  State<Content> createState() => _ContentState();
}

class _ContentState extends State<Content> {
  var plainTextControls = false;

  showControls(show) {
    setState(() {
      plainTextControls = show;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.contentData == null) {
      return const Text("");
    } else if (widget.contentData!.mode == Modes.loading) {
      return const Text("Loading…");
    } else if (widget.viewSource) {
      return SelectableText(
        widget.contentData?.source() ?? "No source?",
        style: const TextStyle(
            fontFamily: "DejaVu Sans Mono", fontSize: baseFontSize),
      );
    } else if (widget.contentData!.mode == Modes.plain) {
      var lines = widget.contentData!.lines;
      var groups = analyze(lines, alwaysPre: true)!;
      return PreText(
        actualText: lines.join("\n"),
        maxLine: groups.isEmpty ? 1 : groups[0]["maxLine"] ?? 1,
      );
    } else if (widget.contentData!.mode == Modes.gem) {
      var lines = widget.contentData!.lines;
      var groups = analyze(lines)!;
      var result = groupsToWidget(groups);
      return result;
    } else if (widget.contentData!.mode == Modes.error) {
      return ExtendedText("An error occurred\n\n" +
          (widget.contentData!.static ?? "No message") +
          "\n\n-----------------------------------\n\n" +
          (widget.contentData!.source() ?? ""));
    } else if (widget.contentData!.mode == Modes.image) {
      return Image.memory(widget.contentData!.body()!, errorBuilder:
          (BuildContext context, Object exception, StackTrace? stackTrace) {
        return const ExtendedText("broken image ¯\\_(ツ)_/¯");
      });
    } else {
      return ExtendedText("Unknown mode ${widget.contentData!.mode}");
    }
  }

  Widget groupsToWidget(List<dynamic> groups) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in groups)
            if (r["type"] == "pre")
              PreText(actualText: r["data"], maxLine: r["maxLine"])
            else if (r["type"] == "header")
              Heading(
                content: r["data"],
                fontSize: baseFontSize + (20 - math.max(r['size'] * 5.4, 10)),
              )
            else if (r["type"] == "quote")
              BlockQuote(content: r["data"])
            else if (r["type"] == "link")
              Link(
                title: r['data'],
                link: r['link'],
                loadedUri: widget.contentData!.loadedUri!,
              )
            else if (r["type"] == "list")
              ListItem(content: r["data"])
            else
              PlainText(content: r["data"])
        ]);
  }
}

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
              child: ExtendedText(widget.actualText,
                  softWrap: true,
                  style: const TextStyle(
                      fontFamily: "DejaVu Sans Mono", fontSize: baseFontSize),
                  selectionEnabled: true),
              width: size));
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
