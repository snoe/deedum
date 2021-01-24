import 'package:deedum/directory/gem_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Bookmarks extends StatelessWidget {
  final onNewTab;
  final onBookmark;
  final Set<String> bookmarks;

  final bookmarkKey = GlobalObjectKey(DateTime.now().millisecondsSinceEpoch);

  Bookmarks(this.bookmarks, this.onNewTab, this.onBookmark);

  String get title => [
        "██████╗  ██████╗  ██████╗ ██╗  ██╗███╗   ███╗ █████╗ ██████╗ ██╗  ██╗███████╗",
        "██╔══██╗██╔═══██╗██╔═══██╗██║ ██╔╝████╗ ████║██╔══██╗██╔══██╗██║ ██╔╝██╔════╝",
        "██████╔╝██║   ██║██║   ██║█████╔╝ ██╔████╔██║███████║██████╔╝█████╔╝ ███████╗",
        "██╔══██╗██║   ██║██║   ██║██╔═██╗ ██║╚██╔╝██║██╔══██║██╔══██╗██╔═██╗ ╚════██║",
        "██████╔╝╚██████╔╝╚██████╔╝██║  ██╗██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██╗███████║",
        "╚═════╝  ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝"
      ].join("\n");

  @override
  Widget build(BuildContext context) {
    var children;

    if (bookmarks.isNotEmpty) {
      children = bookmarks.map((bookmarkLocation) {
        var bookmarkUri = Uri.tryParse(bookmarkLocation);
        return GemItem(
          Uri.decodeFull(bookmarkUri.host),
          title: Text(bookmarkUri.path == "" ? "/" : Uri.decodeFull(bookmarkUri.path)),
          showBookmarked: false,
          showDelete: true,
          onSelect: () => onNewTab(initialLocation: bookmarkLocation),
          onDelete: () => onBookmark(bookmarkLocation),
        );
      }).toList();
    } else {
      children = [
        Card(
          color: Colors.black12,
          child: ListTile(
            onTap: onNewTab,
            leading: Icon(Icons.explore, color: Colors.white),
            title: Text("No Bookmarks", style: TextStyle(color: Colors.white)),
            subtitle: Text("Go forth, explore",
                style: TextStyle(color: Colors.white)),
          ),
        )
      ];
    }
    return SingleChildScrollView(child: Column(children: children));
  }
}
