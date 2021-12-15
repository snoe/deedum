// ignore: unused_import
import 'dart:developer';

import 'package:deedum/browser_tab.dart';
import 'package:deedum/main.dart';

import 'package:flutter/material.dart';

enum _MenuSelection { logs, source, bookmark, feed, root, parent, forward }

class TabMenuWidget extends StatelessWidget {
  const TabMenuWidget(
      {Key? key,
      required this.tab,
      required this.onBookmark,
      required this.onFeed,
      required this.onLocation,
      required this.onForward})
      : super(key: key);

  final BrowserTabState tab;
  final ValueChanged<String> onBookmark;
  final ValueChanged<String> onFeed;
  final Function(Uri) onLocation;
  final Function() onForward;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuSelection>(
      icon: Icon(Icons.adaptive.more, color: Theme.of(context).shadowColor),
      itemBuilder: (BuildContext context) {
        var uriString = tab.uri?.toString();
        var bookmarked = appKey.currentState!.bookmarks.contains(uriString);
        var feedActive = appKey.currentState!.feeds
            .any((element) => tab.uri?.toString() == uriString);
        return [
          PopupMenuItem(
            child: ListTile(
                leading: const Text("", textAlign: TextAlign.center),
                title: Text("Go to root",
                    style: TextStyle(
                        color: tab.uri?.pathSegments.isNotEmpty ?? false
                            ? null
                            : Theme.of(context).disabledColor))),
            enabled: tab.uri?.pathSegments.isNotEmpty ?? false,
            value: _MenuSelection.root,
          ),
          PopupMenuItem(
            child: ListTile(
              leading: const Text("", textAlign: TextAlign.center),
              title: Text("Go to parent",
                  style: TextStyle(
                      color: tab.uri?.pathSegments.isNotEmpty ?? false
                          ? null
                          : Theme.of(context).disabledColor)),
            ),
            enabled: tab.uri?.pathSegments.isNotEmpty ?? false,
            value: _MenuSelection.parent,
          ),
          const PopupMenuItem(
              child: ListTile(
                  leading: Icon(Icons.chevron_right, color: Colors.black),
                  title: Text("Go forward")),
              value: _MenuSelection.forward),
          const PopupMenuDivider(),
          PopupMenuItem(
            child: ListTile(
                leading: Icon(
                    bookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
                    color: Colors.black),
                title: Text(bookmarked ? "Remove bookmark" : "Add bookmark")),
            value: _MenuSelection.bookmark,
          ),
          PopupMenuItem(
            child: ListTile(
                leading: Icon(
                    bookmarked ? Icons.rss_feed : Icons.rss_feed_outlined,
                    color: Colors.black),
                title: Text(feedActive ? "Remove as feed" : "Add as feed")),
            value: _MenuSelection.feed,
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
              child: ListTile(
                  leading: Icon(Icons.code, color: Colors.black),
                  title: Text("Logs")),
              value: _MenuSelection.logs),
          CheckedPopupMenuItem(
            checked: tab.viewingSource,
            value: _MenuSelection.source,
            child: const Text("Source"),
          ),
        ];
      },
      onSelected: (result) {
        switch (result) {
          case _MenuSelection.logs:
            tab.showLogs();
            break;
          case _MenuSelection.source:
            tab.toggleSourceView();
            break;
          case _MenuSelection.bookmark:
            if (tab.uri != null) {
              onBookmark(tab.uri!.toString());
            }
            break;
          case _MenuSelection.feed:
            if (tab.uri != null) {
              onFeed(tab.uri!.toString());
            }
            break;
          case _MenuSelection.root:
            if (tab.uri != null) {
              var uri = tab.uri!;
              List<String> segments = List.from(uri.pathSegments);
              var newUri = uri.replace(path: "/");

              if (segments.isNotEmpty) {
                onLocation(newUri);
              }
            }
            break;
          case _MenuSelection.parent:
            if (tab.uri != null) {
              var uri = tab.uri!;
              List<String> segments = List.from(uri.pathSegments);
              if (segments.isNotEmpty) {
                var last = segments.removeLast();
                if (last == "") {
                  segments.removeLast();
                }
                var newUri = uri.replace(pathSegments: segments);
                newUri = newUri.replace(path: newUri.path + "/");
                onLocation(newUri);
              }
            }
            break;
          case _MenuSelection.forward:
            onForward();
            break;
          default:
            throw Exception("Unknown menu selection");
        }
      },
    );
  }
}
