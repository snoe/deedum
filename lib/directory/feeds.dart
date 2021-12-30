import 'package:deedum/app_state.dart';
import 'package:deedum/directory/directory_element.dart';
import 'package:deedum/next/app.dart';
import 'package:flutter/material.dart';

import 'package:deedum/shared.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Feeds extends DirectoryElement {
  const Feeds({
    Key? key,
  }) : super(key: key);

  @override
  String get title => [
        "███████╗███████╗███████╗██████╗ ███████╗",
        "██╔════╝██╔════╝██╔════╝██╔══██╗██╔════╝",
        "█████╗  █████╗  █████╗  ██║  ██║███████╗",
        "██╔══╝  ██╔══╝  ██╔══╝  ██║  ██║╚════██║",
        "██║     ███████╗███████╗██████╔╝███████║",
        "╚═╝     ╚══════╝╚══════╝╚═════╝ ╚══════╝"
      ].join("\n");

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var appState = ref.watch(appStateProvider);
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Card(
            color: Theme.of(context).buttonTheme.colorScheme!.primary,
            child: ListTile(
                leading: IconButton(
                    icon: const Icon(Icons.refresh),
                    color: Colors.black,
                    onPressed: () {
                      for (var feed in appState.feeds) {
                        appState.updateFeed(feed.uri!);
                      }
                    }),
                onTap: () {
                  appState.onNewTab("about:feeds");
                  Navigator.pop(navigatorKey.currentContext!);
                },
                title: const Text("Open feed reader in new tab")),
          ),
          for (final feed in appState.feeds)
            Dismissible(
              background: Container(color: Colors.red),
              key: UniqueKey(),
              onDismissed: (direction) {
                appState.removeFeed(feed);
              },
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            appState.updateFeed(feed.uri!);
                          }),
                      Expanded(
                          flex: 1,
                          child: ListTile(
                            contentPadding: const EdgeInsets.only(left: 20),
                            onTap: () {
                              appState.onNewTab(feed.uri.toString());
                              Navigator.pop(navigatorKey.currentContext!);
                            },
                            dense: true,
                            subtitle: Text(toSchemelessString(feed.uri) +
                                "\nLast Updated: " +
                                feed.lastFetchedAt +
                                "\n" +
                                feed.links!.length.toString() +
                                " entries"),
                            title: Text(feed.title!,
                                style: const TextStyle(fontSize: 14)),
                          )),
                      IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            appState.removeFeed(feed);
                          }),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
