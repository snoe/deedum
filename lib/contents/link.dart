import 'package:deedum/main.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Link extends StatelessWidget {
  const Link({
    Key? key,
    required this.title,
    required this.currentUri,
    required this.link,
    required this.onLocation,
    required this.onNewTab,
  }) : super(key: key);

  final Uri currentUri;
  final String link;
  final String title;
  final ValueChanged<Uri> onLocation;
  final VoidCallback onNewTab;

  @override
  Widget build(BuildContext context) {
    Uri uri = resolveLink(currentUri, link);
    bool httpWarn = uri.scheme != "gemini";
    bool visited = appKey.currentState!.recents.contains(uri.toString());
    return GestureDetector(
        child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 7, 0, 7),
            child: Text((httpWarn ? "[${uri.scheme}] " : "") + title,
                style: TextStyle(
                    color: httpWarn
                        ? (visited ? Colors.purple[100] : Colors.purple[300])
                        : (visited ? Colors.blueGrey : Colors.blue)))),
        onLongPress: () => linkLongPressMenu(title, uri, onNewTab, context),
        onTap: () {
          onLocation(uri);
        });
  }
}

void linkLongPressMenu(title, uri, onNewTab, oldContext) =>
    showModalBottomSheet<void>(
        context: oldContext,
        builder: (BuildContext context) {
          return Container(
            constraints: BoxConstraints(
              minHeight: 50,
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            // color: Colors.amber,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(title: Center(child: Text(uri.toString()))),
                ListTile(
                  title: const Center(child: Text("Copy link")),
                  onTap: () async {
                    await Clipboard.setData(
                        ClipboardData(text: uri.toString()));
                    const snackBar =
                        SnackBar(content: Text('Copied to Clipboard'));
                    ScaffoldMessenger.of(oldContext).showSnackBar(snackBar);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Center(child: Text("Copy link text")),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: title));

                    const snackBar =
                        SnackBar(content: Text('Copied to Clipboard'));
                    ScaffoldMessenger.of(oldContext).showSnackBar(snackBar);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Center(child: Text("Open link in new tab")),
                  onTap: () {
                    Navigator.pop(context);
                    onNewTab(uri.toString());
                  },
                ),
              ],
            ),
          );
        });
