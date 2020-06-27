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
        return Padding(
            padding: EdgeInsets.only(top: 8),
            child: Card(
                child: Row(children: [
              Expanded(
                  flex: 1,
                  child: ListTile(
                    onTap: () => onNewTab(initialLocation: recentLocation),
                    leading: Icon(Icons.description),
                    title: Text("${recentUri.host}", style: TextStyle(fontSize: 14)),
                    subtitle: recentUri.path != "/" ? Text("${recentUri.path}", style: TextStyle(fontSize: 12)) : null,
                  )),
              IconButton(
                icon:
                    Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border, color: bookmarked ? Colors.orange : null),
                onPressed: () {
                  onBookmark(recentLocation);
                },
              ),
            ])));
      }).toList();
    } else {
      children = [
        Card(
          color: Colors.black12,
          child: ListTile(
            onTap: onNewTab,
            leading: Icon(Icons.explore, color: Colors.white),
            title: Text("No History", style: TextStyle(color: Colors.white)),
            subtitle: Text("Go forth, explore", style: TextStyle(color: Colors.white)),
          ),
        )
      ];
    }
    return SingleChildScrollView(child: Column(children: children));
  }
}
