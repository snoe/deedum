import 'package:deedum/directory/directory_element.dart';
import 'package:deedum/directory/gem_item.dart';
import 'package:deedum/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class History extends DirectoryElement {
  final void Function(String, bool) onNewTab;
  final ValueChanged<String> onBookmark;
  final List<String> recents;

  final bookmarkKey = GlobalObjectKey(DateTime.now().millisecondsSinceEpoch);

  History({
    Key key,
    @required this.recents,
    @required this.onNewTab,
    @required this.onBookmark,
  }) : super(key: key);

  @override
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
    return SingleChildScrollView(
        child: Column(children: [
      if (recents.isNotEmpty)
        for (final recentLocation in recents.reversed)
          GemItem(
            url: Uri.decodeFull(Uri.parse(recentLocation).host),
            title: Text(Uri.parse(recentLocation).path == ""
                ? "/"
                : Uri.decodeFull(Uri.parse(recentLocation).path)),
            bookmarked: appKey.currentState.bookmarks.contains(recentLocation),
            showBookmarked: true,
            showDelete: false,
            onSelect: () => onNewTab(recentLocation, null),
            onBookmark: () => onBookmark(recentLocation),
          )
      else
        Card(
          color: Colors.black12,
          child: ListTile(
            onTap: () => onNewTab(null, null),
            leading: const Icon(Icons.explore, color: Colors.white),
            title:
                const Text("No History", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Go forth, explore",
                style: TextStyle(color: Colors.white)),
          ),
        )
    ]));
  }
}
