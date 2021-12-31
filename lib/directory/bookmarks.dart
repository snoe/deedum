import 'package:deedum/app_state.dart';
import 'package:deedum/directory/directory_element.dart';
import 'package:deedum/directory/gem_item.dart';
import 'package:deedum/next/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Bookmarks extends DirectoryElement {
  const Bookmarks({
    Key? key,
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
  Widget build(BuildContext context, WidgetRef ref) {
    var appState = ref.watch(appStateProvider);
    return SingleChildScrollView(
      child: Column(
        children: [
          if (appState.bookmarks.isNotEmpty)
            for (final bookmark in appState.bookmarks)
              GemItem(
                url: Uri.decodeFull(Uri.parse(bookmark).host),
                title: Text(Uri.parse(bookmark).path == ""
                    ? "/"
                    : Uri.decodeFull(Uri.parse(bookmark).path)),
                showBookmarked: false,
                showDelete: true,
                onSelect: () {
                  appState.onNewTab(bookmark);
                  Navigator.pop(navigatorKey.currentContext!);
                },
                onDelete: () => appState.onBookmark(bookmark),
              )
          else
            Card(
              color: Colors.black12,
              child: ListTile(
                onTap: () {
                  Navigator.pop(navigatorKey.currentContext!);
                },
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
