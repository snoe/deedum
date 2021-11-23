import 'package:deedum/directory/directory_element.dart';
import 'package:deedum/directory/gem_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Bookmarks extends DirectoryElement {
  final void Function(String?, bool?) onNewTab;
  final ValueChanged<String> onBookmark;
  final Set<String> bookmarks;

  final bookmarkKey = GlobalObjectKey(DateTime.now().millisecondsSinceEpoch);

  Bookmarks({
    Key? key,
    required this.bookmarks,
    required this.onNewTab,
    required this.onBookmark,
  }) : super(key: key);

  @override
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
    return SingleChildScrollView(
      child: Column(
        children: [
          if (bookmarks.isNotEmpty)
            for (final bookmark in bookmarks)
              GemItem(
                url: Uri.decodeFull(Uri.parse(bookmark).host),
                title: Text(Uri.parse(bookmark).path == ""
                    ? "/"
                    : Uri.decodeFull(Uri.parse(bookmark).path)),
                showBookmarked: false,
                showDelete: true,
                onSelect: () => onNewTab(bookmark, null),
                onDelete: () => onBookmark(bookmark),
              )
          else
            Card(
              color: Colors.black12,
              child: ListTile(
                onTap: () => onNewTab(null, null),
                leading: const Icon(Icons.explore, color: Colors.white),
                title: const Text("No Bookmarks",
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text("Go forth, explore",
                    style: TextStyle(color: Colors.white)),
              ),
            )
        ],
      ),
    );
  }
}
