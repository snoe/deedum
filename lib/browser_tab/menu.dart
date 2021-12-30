// ignore: unused_import
import 'dart:developer';

import 'package:deedum/app_state.dart';
import 'package:deedum/browser_tab/client_cert.dart';
import 'package:deedum/shared.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

enum _MenuSelection {
  logs,
  source,
  bookmark,
  feed,
  root,
  parent,
  forward,
  identity
}

class TabMenuWidget extends ConsumerWidget {
  const TabMenuWidget({Key? key}) : super(key: key);

  Future<void> showLogs(context, AppState appState) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        var orderedLogs = appState.currentLogs().reversed.toList();
        DateFormat formatter = DateFormat('HH:mm:ss.SSSS');

        return AlertDialog(
            title: const Text('Logs'),
            contentPadding: EdgeInsets.zero,
            actions: [
              TextButton(
                  child: const Text('Clear'),
                  onPressed: () {
                    appState.clearCurrentLogs();
                    Navigator.of(context).pop();
                  }),
              TextButton(
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: orderedLogs.length,
                itemBuilder: (context, i) {
                  var log = orderedLogs[i];
                  var level = log[0];
                  var timestamp = log[1];
                  var requestID = log[2];
                  var message = log[3];
                  String formatted = formatter.format(timestamp);
                  Color levelColor;
                  if (level == "error") {
                    levelColor = Colors.redAccent;
                  } else if (level == "warn") {
                    levelColor = Colors.yellowAccent;
                  } else {
                    levelColor = Theme.of(context).dialogBackgroundColor;
                  }
                  return ListTile(
                      title: Text("[$formatted] #$requestID"),
                      subtitle: Text(message),
                      tileColor: levelColor);
                },
              ),
            ));
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var appState = ref.watch(appStateProvider);
    var currentUri = appState.currentUri();
    var currentIdentity = appState.currentIdentity();
    return PopupMenuButton<_MenuSelection>(
      icon: Icon(Icons.adaptive.more, color: Theme.of(context).shadowColor),
      itemBuilder: (BuildContext context) {
        var uriString = currentUri.toString();
        var bookmarked = appState.bookmarks.contains(uriString);
        var feedActive = appState.feeds
            .any((element) => element.uri.toString() == uriString);
        Identity? activeIdentity = currentUri == null
            ? null
            : appState.identities
                .firstOrNull((element) => element.matches(currentUri));
        return [
          PopupMenuItem(
            child: ListTile(
                leading: const Text("", textAlign: TextAlign.center),
                title: Text("Go to root",
                    style: TextStyle(
                        color: currentUri?.pathSegments.isNotEmpty ?? false
                            ? null
                            : Theme.of(context).disabledColor))),
            enabled: currentUri?.pathSegments.isNotEmpty ?? false,
            value: _MenuSelection.root,
          ),
          PopupMenuItem(
            child: ListTile(
              leading: const Text("", textAlign: TextAlign.center),
              title: Text("Go to parent",
                  style: TextStyle(
                      color: currentUri?.pathSegments.isNotEmpty ?? false
                          ? null
                          : Theme.of(context).disabledColor)),
            ),
            enabled: currentUri?.pathSegments.isNotEmpty ?? false,
            value: _MenuSelection.parent,
          ),
          PopupMenuItem(
              child: ListTile(
                  leading: const Icon(Icons.chevron_right, color: Colors.black),
                  title: Text("Go forward",
                      style: TextStyle(
                          color: appState.canGoForward()
                              ? null
                              : Theme.of(context).disabledColor))),
              enabled: appState.canGoForward(),
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
          PopupMenuItem(
            child: ListTile(
                leading: Icon(
                    bookmarked
                        ? Icons.person_remove_outlined
                        : Icons.person_add_outlined,
                    color: Colors.black),
                title: Text(activeIdentity != null
                    ? "Remove from identity"
                    : "Add to identity")),
            value: _MenuSelection.identity,
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
              child: ListTile(
                  leading: Icon(Icons.code, color: Colors.black),
                  title: Text("Logs")),
              value: _MenuSelection.logs),
          CheckedPopupMenuItem(
            checked: appState.viewingSource(),
            value: _MenuSelection.source,
            child: const Text("Source"),
          ),
        ];
      },
      onSelected: (result) async {
        switch (result) {
          case _MenuSelection.logs:
            showLogs(context, appState);
            break;
          case _MenuSelection.source:
            appState.toggleSourceView();
            break;
          case _MenuSelection.bookmark:
            if (currentUri != null) {
              appState.onBookmark(currentUri.toString());
            }
            break;
          case _MenuSelection.feed:
            if (currentUri != null) {
              appState.onFeed(currentUri.toString());
            }
            break;
          case _MenuSelection.root:
            if (currentUri != null) {
              List<String> segments = List.from(currentUri.pathSegments);
              var newUri = currentUri.replace(path: "/");

              if (segments.isNotEmpty) {
                appState.onLocation(newUri);
              }
            }
            break;
          case _MenuSelection.parent:
            if (currentUri != null) {
              Uri? newUri = parentPath(currentUri);
              if (newUri != null) {
                appState.onLocation(newUri);
              }
            }
            break;
          case _MenuSelection.identity:
            if (currentUri != null) {
              if (currentIdentity != null) {
                appState.onIdentity(currentIdentity, currentUri);
              } else {
                var newIdentity = await showDialog(
                    context: context,
                    builder: (context) {
                      return ClientCertAlert(
                          prompt: "Add to identity?", uri: currentUri);
                    });
                if (newIdentity != null) {
                  appState.onIdentity(newIdentity, currentUri);
                }
              }
            }
            break;
          case _MenuSelection.forward:
            appState.handleForward();
            break;
          default:
            throw Exception("Unknown menu selection");
        }
      },
    );
  }
}
