import 'dart:developer';

import 'package:deedum/models/app_state.dart';
import 'package:deedum/directory/directory_element.dart';
import 'package:deedum/directory/gem_item.dart';
import 'package:deedum/next/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Tabs extends DirectoryElement {
  const Tabs({
    Key? key,
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
  Widget build(BuildContext context, WidgetRef ref) {
    var appState = ref.watch(appStateProvider);
    List<Widget> list = appState.indexedTabs((index, tab) {
      var uriString = tab.uri.toString();
      var selected = appState.currentTabIndex() == index;
      var bookmarked = appState.bookmarks.contains(uriString);
      var feedActive =
          appState.feeds.any((element) => element.uri.toString() == uriString);
      var host = tab.uri?.host;
      if (host == "") {
        host = tab.uri.toString();
      }
      log("${tab.contentData}");
      var tabItem = GemItem(
        url: host != null ? Uri.decodeFull(host) : null,
        title: Text(
          tab.contentData?.summaryLine() ?? (host != null ? "Loading…" : ""),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        selected: selected,
        bookmarked: bookmarked,
        feedActive: feedActive,
        showTitle: true,
        showBookmarked: true,
        showDelete: true,
        disableDelete: false,
        showFeed: true,
        onSelect: () {
          appState.onSelectTab(index);
          Navigator.pop(navigatorKey.currentContext!);
        },
        onBookmark: () => appState.onBookmark(uriString),
        onDelete: () {
          appState.onDeleteTab(index);
        },
        onFeed: () => appState.onFeed(uriString),
      );
      return Dismissible(
        background: Container(color: Colors.red),
        key: UniqueKey(),
        onDismissed: (direction) {
          appState.onDeleteTab(index);
        },
        child: tabItem,
      );
    }).toList();
    return SingleChildScrollView(
        child: Column(
            children: <Widget>[
                  Card(
                    color: Theme.of(context).buttonTheme.colorScheme!.primary,
                    child: ListTile(
                      onTap: () {
                        appState.onNewTab(null);
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
                list));
  }
}
