import 'dart:math' as math;
import 'package:deedum/browser_tab.dart';
import 'package:deedum/main.dart';
import 'package:deedum/shared.dart';

import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Bookmarks extends StatelessWidget {
  final onNewTab;
  final onBookmark;
  final Set<String> bookmarks;

  final bookmarkKey = GlobalObjectKey(DateTime.now().millisecondsSinceEpoch);

  Bookmarks(this.bookmarks, this.onNewTab, this.onBookmark);

  String get title => [
        "██████╗  ██████╗  ██████╗ ██╗  ██╗███╗   ███╗ █████╗ ██████╗ ██╗  ██╗███████╗",
        "██╔══██╗██╔═══██╗██╔═══██╗██║ ██╔╝████╗ ████║██╔══██╗██╔══██╗██║ ██╔╝██╔════╝",
        "██████╔╝██║   ██║██║   ██║█████╔╝ ██╔████╔██║███████║██████╔╝█████╔╝ ███████╗",
        "██╔══██╗██║   ██║██║   ██║██╔═██╗ ██║╚██╔╝██║██╔══██║██╔══██╗██╔═██╗ ╚════██║",
        "██████╔╝╚██████╔╝╚██████╔╝██║  ██╗██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██╗███████║",
        "╚═════╝  ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝"
      ].join("\n");

  @override
  Widget build(BuildContext context) {
    var children;

    if (bookmarks.isNotEmpty) {
      children = bookmarks.map((bookmarkLocation) {
        var bookmarkUri = Uri.parse(bookmarkLocation);
        return Padding(
            padding: EdgeInsets.only(top: 8),
            child: Card(
                child: Row(children: [
              Expanded(
                  flex: 1,
                  child: ListTile(
                    onTap: () {
                      onNewTab(initialLocation: bookmarkLocation);
                    },
                    leading: Icon(Icons.description),
                    title: Text("${bookmarkUri.host}", style: TextStyle(fontSize: 14)),
                    subtitle:
                        bookmarkUri.path != "/" ? Text("${bookmarkUri.path}", style: TextStyle(fontSize: 12)) : null,
                  )),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  onBookmark(bookmarkLocation);
                },
              ),
            ])));
      }).toList();
    } else {
      children = [
        Card(
          color: Colors.black12,
          child: ListTile(
            onTap: onNewTab,
            leading: Icon(Icons.explore, color: Colors.white),
            title: Text("No Bookmarks", style: TextStyle(color: Colors.white)),
            subtitle: Text("Go forth, explore", style: TextStyle(color: Colors.white)),
          ),
        )
      ];
    }
    return SingleChildScrollView(child: Column(children: children));
  }
}
