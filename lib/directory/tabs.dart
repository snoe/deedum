import 'dart:math' as math;

import 'package:deedum/browser_tab.dart';
import 'package:deedum/main.dart';
import 'package:deedum/shared.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Tabs extends StatelessWidget {
  final onNewTab;
  final onSelectTab;
  final onDeleteTab;
  final onBookmark;
  final List tabs;

  final tabKey = GlobalObjectKey(DateTime.now().millisecondsSinceEpoch);

  Tabs(this.tabs, this.onNewTab, this.onSelectTab, this.onDeleteTab,
      this.onBookmark);

  String get title => [
        "████████╗ █████╗ ██████╗ ███████╗",
        "╚══██╔══╝██╔══██╗██╔══██╗██╔════╝",
        "   ██║   ███████║██████╔╝███████╗",
        "   ██║   ██╔══██║██╔══██╗╚════██║",
        "   ██║   ██║  ██║██████╔╝███████║",
        "   ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚══════╝"
      ].join("\n");

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Column(
            children: <Widget>[
                  Card(
                    color: Colors.black12,
                    child: ListTile(
                      onTap: () => onNewTab(),
                      leading: Icon(
                        Icons.add,
                        color: Colors.white,
                      ),
                      title: Text("New Tab",
                          style: TextStyle(color: Colors.white)),
                    ),
                  )
                ] +
                tabs.mapIndexed((index, tab) {
                  var tabState = ((tab["key"] as GlobalObjectKey).currentState
                      as BrowserTabState);
                  var uriString = tabState?.uri?.toString();
                  var selected =
                      appKey.currentState.previousTabIndex == index + 1;

                  var bookmarked =
                      appKey.currentState.bookmarks.contains(uriString);
                  if (uriString != null && tabState.contentData != null) {
                    return Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Card(
                            shape: selected
                                ? RoundedRectangleBorder(
                                    side: BorderSide(
                                        color: Colors.black, width: 2),
                                    borderRadius: BorderRadius.circular(5))
                                : null,
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(left: 20, right: 10),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(Icons.description),
                                    Expanded(
                                        flex: 1,
                                        child: ListTile(
                                          contentPadding:
                                              EdgeInsets.only(left: 20),
                                          onTap: () => onSelectTab(index + 1),
                                          subtitle: ExtendedText(
                                            tabState.contentData.content
                                                .substring(
                                                    0,
                                                    math.min(
                                                        tabState.contentData
                                                            .content.length,
                                                        500)),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          title: Text("${tabState.uri.host}",
                                              style: TextStyle(fontSize: 14)),
                                        )),
                                    IconButton(
                                      icon: Icon(
                                          bookmarked
                                              ? Icons.bookmark
                                              : Icons.bookmark_border,
                                          color: bookmarked
                                              ? Colors.orange
                                              : null),
                                      onPressed: () {
                                        onBookmark(uriString);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete),
                                      onPressed: () {
                                        onDeleteTab(index);
                                      },
                                    ),
                                  ]),
                            )));
                  } else {
                    return Text("No tab?");
                  }
                }).toList()));
  }
}
