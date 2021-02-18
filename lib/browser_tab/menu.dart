import 'package:deedum/browser_tab.dart';

import 'package:flutter/material.dart';

enum _MenuSelection { logs, source }

Widget TabMenuWidget(BrowserTabState tab) {
  return PopupMenuButton<_MenuSelection>(
    itemBuilder: (BuildContext context) => [
      PopupMenuItem(
          child: ListTile(
              leading: Icon(Icons.code, color: Colors.black),
              title: Text("Logs")),
          value: _MenuSelection.logs),
      CheckedPopupMenuItem(
        checked: tab.viewingSource,
        value: _MenuSelection.source,
        child: Text("Source"),
      ),
    ],
    onSelected: (result) {
      switch (result) {
        case _MenuSelection.logs:
          {
            tab.showLogs();
          }
          break;
        case _MenuSelection.source:
          {
            tab.toggleSourceView();
          }
          break;
        default:
          {
            print("unexpected");
          }
      }
    },
  );
}
