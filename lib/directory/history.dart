import 'package:deedum/app_state.dart';
import 'package:deedum/directory/directory_element.dart';
import 'package:deedum/directory/gem_item.dart';
import 'package:deedum/next/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class History extends DirectoryElement {
  const History({
    Key? key,
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
  Widget build(BuildContext context, WidgetRef ref) {
    var appState = ref.watch(appStateProvider);
    return SingleChildScrollView(
        child: Column(children: [
      if (appState.recents.isNotEmpty)
        for (final recentLocation in appState.recents.reversed)
          GemItem(
            url: Uri.decodeFull(Uri.parse(recentLocation).host),
            title: Text(Uri.parse(recentLocation).path == ""
                ? "/"
                : Uri.decodeFull(Uri.parse(recentLocation).path)),
            bookmarked: appState.bookmarks.contains(recentLocation),
            showBookmarked: true,
            showDelete: false,
            onSelect: () {
              appState.onNewTab(recentLocation);
              Navigator.pop(navigatorKey.currentContext!);
            },
            onBookmark: () => appState.onBookmark(recentLocation),
          )
      else
        Card(
          color: Colors.black12,
          child: ListTile(
            onTap: () {
              Navigator.pop(navigatorKey.currentContext!);
            },
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
