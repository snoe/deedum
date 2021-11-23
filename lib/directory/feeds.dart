import 'package:deedum/directory/directory_element.dart';
import 'package:flutter/material.dart';

import 'package:deedum/shared.dart';
import 'package:flutter/widgets.dart';

class Feeds extends DirectoryElement {
  final List<Feed?> feeds;
  final void Function(String?, bool?) onNewTab;
  final ValueChanged<Feed> removeFeed;
  final ValueChanged<Uri> updateFeed;

  const Feeds({
    Key? key,
    required this.feeds,
    required this.onNewTab,
    required this.removeFeed,
    required this.updateFeed,
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
  Widget build(BuildContext context) {
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
                      for (var feed in feeds) {
                        if (feed == null) {
                          continue;
                        }
                        updateFeed(feed.uri!);
                      }
                    }),
                onTap: () => onNewTab("about:feeds", null),
                title: const Text("Open feed reader in new tab")),
          ),
          for (final feed in feeds)
            if (feed != null)
              Dismissible(
                background: Container(color: Colors.red),
                key: UniqueKey(),
                onDismissed: (direction) {
                  removeFeed(feed);
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
                              updateFeed(feed.uri!);
                            }),
                        Expanded(
                            flex: 1,
                            child: ListTile(
                              contentPadding: const EdgeInsets.only(left: 20),
                              onTap: () {
                                onNewTab(feed.uri.toString(), null);
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
                              removeFeed(feed);
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
