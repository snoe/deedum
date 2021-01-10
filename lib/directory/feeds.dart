import 'dart:developer';

import 'package:flutter/material.dart';

import 'package:deedum/shared.dart';
import 'package:flutter/widgets.dart';

class Feeds extends StatelessWidget {
  final List<Feed> feeds;
  final onNewTab;
  final removeFeed;
  final updateFeed;

  Feeds(this.feeds, this.onNewTab, this.removeFeed, this.updateFeed);

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
                    color: Theme.of(context).buttonColor,
                    child: ListTile(leading: 
                        IconButton(
                            icon: Icon(Icons.refresh),
                            color: Colors.black,
                            onPressed: () {
                              for (var feed in feeds) {
                                updateFeed(feed.uri);
                              }
                            }),
                        onTap: () => onNewTab(initialLocation: "about:feeds"),
                        title: Text("Open feed reader in new tab")),
                  ),
                ] +
                feeds.mapIndexed((index, Feed feed) {
                  var tab = Container(
                      child: Card(
                          child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                            icon: Icon(Icons.refresh),
                            onPressed: () {
                              updateFeed(feed.uri);
                            }),
                        Expanded(
                            flex: 1,
                            child: ListTile(
                              contentPadding: EdgeInsets.only(left: 20),
                              onTap: () {
                                this.onNewTab(feed.uri);
                              },
                              dense: true,
                              subtitle: Text(toSchemelessString(feed.uri) +
                                  "\nLast Updated: " +
                                  feed.lastFetchedAt + "\n" + feed.links.length.toString() + " entries"),
                              title: Text(feed.title,
                                  style: TextStyle(fontSize: 14)),
                            )),
                        IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              removeFeed(feed);
                            }),
                      ],
                    ),
                  )));
                  return Dismissible(
                    background: Container(color: Colors.red),
                    key: UniqueKey(),
                    onDismissed: (direction) {
                      removeFeed(feed);
                    },
                    child: tab,
                  );
                }).toList()));
  }
}
