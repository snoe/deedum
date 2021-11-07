import 'dart:math' as math;

import 'package:deedum/directory/directory_element.dart';
import 'package:deedum/directory/gem_item.dart';
import 'package:deedum/main.dart';
import 'package:deedum/shared.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../browser_tab.dart';

class Tabs extends DirectoryElement {
  final void Function(String?, bool?) onNewTab;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<int> onDeleteTab;
  final ValueChanged<String> onBookmark;
  final ValueChanged<String> onFeed;
  final List tabs;

  final tabKey = GlobalObjectKey(DateTime.now().millisecondsSinceEpoch);

  Tabs({
    Key? key,
    required this.tabs,
    required this.onNewTab,
    required this.onSelectTab,
    required this.onDeleteTab,
    required this.onBookmark,
    required this.onFeed,
  }) : super(key: key);

  @override
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
                    color: Theme.of(context).buttonTheme.colorScheme!.primary,
                    child: ListTile(
                      onTap: () {
                        onNewTab(null, null);
                        Navigator.pop(navigatorKey.currentContext!);
                      },
                      leading: const Icon(
                        Icons.add,
                        //color: Colors.black,
                      ),
                      title: const Text("New Tab"),
                    ),
                  )
                ] +
                tabs.mapIndexed((index, tab) {
                  var tabState = ((tab["key"] as GlobalObjectKey).currentState
                      as BrowserTabState?);
                  var uriString = tabState?.uri?.toString();
                  var selected = appKey.currentState!.tabIndex == index;

                  var bookmarked =
                      appKey.currentState!.bookmarks.contains(uriString);
                  var feedActive = appKey.currentState!.feeds
                      .any((element) => element!.uri.toString() == uriString);
                  var host = tabState?.uri?.host;
                  if (host == "") {
                    host = tabState!.uri.toString();
                  }
                  if (uriString != null && tabState!.contentData != null) {
                    var tab = GemItem(
                      url: Uri.decodeFull(host!),
                      title: ExtendedText(
                        tabState.contentData!.content!.substring(0,
                            math.min(tabState.contentData!.content!.length, 500)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      selected: selected,
                      bookmarked: bookmarked,
                      feedActive: feedActive,
                      showTitle: true,
                      showBookmarked: true,
                      showDelete: true,
                      disableDelete: index == 0,
                      showFeed: true,
                      onSelect: () {
                        onSelectTab(index);
                        Navigator.pop(navigatorKey.currentContext!);
                      },
                      onBookmark: () => onBookmark(uriString),
                      onDelete: () {
                        if (index != 0) {
                          onDeleteTab(index);
                        }
                      },
                      onFeed: () => onFeed(uriString),
                    );
                    if (index == 0) {
                      return tab;
                    } else {
                      return Dismissible(
                        background: Container(color: Colors.red),
                        key: UniqueKey(),
                        onDismissed: (direction) {
                          if (index != 0) {
                            onDeleteTab(index);
                          }
                        },
                        child: tab,
                      );
                    }
                  } else {
                    return const Text("No tab?");
                  }
                }).toList()));
  }
}
