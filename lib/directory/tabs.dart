import 'dart:math' as math;

import 'package:deedum/directory/gem_item.dart';
import 'package:deedum/main.dart';
import 'package:deedum/shared.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../browser_tab.dart';

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
                    color: Theme.of(context).buttonColor,
                    child: ListTile(
                      onTap: () => onNewTab(),
                      leading: Icon(
                        Icons.add,
                        //color: Colors.black,
                      ),
                      title: Text("New Tab"),
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
                    return GemItem(
                      tabState.uri.host,
                      title: ExtendedText(
                        tabState.contentData.content.substring(0,
                            math.min(tabState.contentData.content.length, 500)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      selected: selected,
                      bookmarked: bookmarked,
                      showTitle: true,
                      showBookmarked: true,
                      showDelete: true,
                      onSelect: () => onSelectTab(index + 1),
                      onBookmark: () => onBookmark(uriString),
                      onDelete: () => onDeleteTab(index),
                    );
                  } else {
                    return Text("No tab?");
                  }
                }).toList()));
  }
}
