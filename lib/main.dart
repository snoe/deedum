import 'dart:async';
import 'dart:developer';

import 'package:deedum/browser_tab.dart';
import 'package:deedum/directory/tabs.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter/foundation.dart' as foundation;

bool get isIos => foundation.defaultTargetPlatform == foundation.TargetPlatform.iOS;
final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();

final GlobalKey<AppState> appKey = new GlobalKey();
void main() {
  runApp(App(key: appKey));
}

class App extends StatefulWidget {
  App({Key key}) : super(key: key);

  @override
  AppState createState() => AppState();
}

class AppState extends State<App> with AutomaticKeepAliveClientMixin {
  List tabs = [];
  int tabIndex = 0;
  int previousTabIndex = 0;

  Set<String> bookmarks = Set();
  StreamSubscription _sub;

  void initState() {
    super.initState();

    tabIndex = 0;
    init();
  }

  init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bookmarks = (prefs.getStringList('bookmarks') ?? []).toSet();

    _sub = getLinksStream().listen((String link) {
      onNewTab(initialLocation: link);
    }, onError: (err) {
      log("oop");
    });

    try {
      var link = await getInitialLink();
      if (link != null) {
        onNewTab(initialLocation: link);
        return;
      }
    } on PlatformException {
      log("oop");
    }
  }

  onBookmark(uriString) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      if (bookmarks.contains(uriString)) {
        bookmarks.remove(uriString);
      } else {
        bookmarks.add(uriString);
      }

      prefs.setStringList('bookmarks', bookmarks.toList());
    });
  }

  onNewTab({initialLocation = "about://homepage"}) {
    if (tabIndex == 0) {
      setState(() {
        var key = GlobalObjectKey(DateTime.now().millisecondsSinceEpoch);
        tabs.add({"key": key, "widget": BrowserTab(Uri.parse(initialLocation), onNewTab, key: key)});
        tabIndex = tabs.length;
      });
    } else {
      setState(() {
        previousTabIndex = tabIndex;
        tabIndex = 0;
      });
    }
  }

  onSelectTab(newIndex) {
    setState(() {
      tabIndex = newIndex;
    });
  }

  onDeleteTab(dropIndex) {
    setState(() {
      tabs.removeAt(dropIndex);
      if (previousTabIndex == dropIndex + 1) {
        previousTabIndex = 0;
      } else if (previousTabIndex > dropIndex) {
        previousTabIndex -= 1;
      }
    });
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MaterialApp(
      title: 'deedum',
      theme: ThemeData(
        fontFamily: "Merriweather",
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: IndexedStack(
          index: tabIndex,
          children: <Widget>[Tabs(tabs, onNewTab, onSelectTab, onDeleteTab, onBookmark)] +
              tabs.map<Widget>((t) => t["widget"]).toList()),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _sub.cancel();
  }

  @override
  bool get wantKeepAlive => true;
}
