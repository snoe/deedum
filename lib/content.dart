// ignore: unused_import
import 'dart:developer';
import 'dart:math' as math;

import 'package:deedum/contents/blockquote.dart';
import 'package:deedum/contents/heading.dart';
import 'package:deedum/contents/link.dart';
import 'package:deedum/contents/list_item.dart';
import 'package:deedum/contents/pre_text.dart';
import 'package:deedum/contents/plain_text.dart';
import 'package:deedum/models/content_data.dart';
import 'package:deedum/parser.dart';
import 'package:deedum/shared.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contents/ansi_pre_text.dart';


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
  int ansiLevel = 1;

  @override
  void initState() {
    super.initState();
    changeAnsi();
  }

  changeAnsi() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      ansiLevel = int.parse(prefs.getString('ansiColors') ?? '0');
    });
  }


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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in groups)
            if (r["type"] == "pre")
              getPreTextWidget(r)
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

  getPreTextWidget(r) {
    changeAnsi();
    if (ansiLevel == 0){
      return PreText(actualText: r["data"], maxLine: r["maxLine"]);
    }
    return AnsiPreText(actualText: r["data"],
        maxLine: r["maxLine"],
        ansiLevel: ansiLevel);

  }
}
