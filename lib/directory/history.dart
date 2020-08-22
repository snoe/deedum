import 'package:deedum/directory/gem_item.dart';
import 'package:deedum/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class History extends StatelessWidget {
  final onNewTab;
  final onBookmark;
  final List<String> recents;

  final bookmarkKey = GlobalObjectKey(DateTime.now().millisecondsSinceEpoch);

  History(this.recents, this.onNewTab, this.onBookmark);

  String get title => [
        "██╗  ██╗██╗███████╗████████╗ ██████╗ ██████╗ ██╗   ██╗",
        "██║  ██║██║██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗╚██╗ ██╔╝",
        "███████║██║███████╗   ██║   ██║   ██║██████╔╝ ╚████╔╝ ",
        "██╔══██║██║╚════██║   ██║   ██║   ██║██╔══██╗  ╚██╔╝  ",
        "██║  ██║██║███████║   ██║   ╚██████╔╝██║  ██║   ██║   ",
        "╚═╝  ╚═╝╚═╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝   "
      ].join("\n");

  @override
  Widget build(BuildContext context) {
    var children;

    if (recents.isNotEmpty) {
      children = recents.reversed.map((recentLocation) {
        var recentUri = Uri.parse(recentLocation);

        var bookmarked = appKey.currentState.bookmarks.contains(recentLocation);
        return GemItem(
          recentUri.host,
          title: Text(recentUri.path == "" ? "/" : recentUri.path),
          bookmarked: bookmarked,
          showBookmarked: true,
          showDelete: false,
          onSelect: () => onNewTab(initialLocation: recentLocation),
          onBookmark: () => onBookmark(recentLocation),
        );
      }).toList();
    } else {
      children = [
        Card(
          color: Colors.black12,
          child: ListTile(
            onTap: onNewTab,
            leading: Icon(Icons.explore, color: Colors.white),
            title: Text("No History", style: TextStyle(color: Colors.white)),
            subtitle: Text("Go forth, explore",
                style: TextStyle(color: Colors.white)),
          ),
        )
      ];
    }
    return SingleChildScrollView(child: Column(children: children));
  }
}
