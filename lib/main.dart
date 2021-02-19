import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:deedum/browser_tab.dart';
import 'package:deedum/directory/bookmarks.dart';
import 'package:deedum/directory/directory.dart';
import 'package:deedum/directory/feeds.dart';
import 'package:deedum/directory/history.dart';
import 'package:deedum/directory/settings.dart';
import 'package:deedum/directory/tabs.dart';
import 'package:deedum/net.dart';
import 'package:deedum/parser.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uni_links/uni_links.dart';

bool get isIos =>
    foundation.defaultTargetPlatform == foundation.TargetPlatform.iOS;
final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();

final GlobalKey<AppState> appKey = new GlobalKey();
final GlobalKey<AppState> materialKey = new GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  database = openDatabase(
    'deedum.db',
    onCreate: (db, version) {
      db.execute(
        "CREATE TABLE hosts(name TEXT PRIMARY KEY, hash BLOB, expires_at BLOB, created_at TEXT)",
      );
      db.execute(
          "CREATE TABLE feeds(uri TEXT PRIMARY KEY, content TEXT, last_fetched_at TEXT, attempts INTEGER default 0)");
    },
    onUpgrade: (db, old, _new) {
      if (old == 1) {
        db.execute("DROP TABLE hosts");
        db.execute(
            "CREATE TABLE hosts(name TEXT PRIMARY KEY, hash BLOB, expires_at BLOB, created_at TEXT)");
      }
      if (old == 2) {
        db.execute(
            "CREATE TABLE feeds(uri TEXT PRIMARY KEY, content TEXT, last_fetched_at TEXT, attempts INTEGER default 0)");
      }
    },
    version: 3,
  );

  runApp(App(key: appKey));
}

class App extends StatefulWidget {
  App({Key key}) : super(key: key);

  @override
  AppState createState() => AppState();
}

class FeedEntry {
  String entryDate;
  String entryTitle;
  Uri entryUri;
  String line;
  String feedTitle;

  FeedEntry(this.feedTitle, this.entryUri, this.entryDate, this.entryTitle,
      this.line);
}

class AppState extends State<App> with AutomaticKeepAliveClientMixin {
  List tabs = [];
  int tabIndex = 0;

  Set<String> bookmarks = Set();
  List<String> recents = List();
  List<Feed> feeds = List();
  List<String> feed = List();

  Map settings = {};
  StreamSubscription _sub;

  void initState() {
    super.initState();

    tabIndex = 0;
    init();
  }

  parseFeed(Uri uri, String content) {
    var lines = LineSplitter.split(content);
    var title = lines
        .firstWhere((line) => line.startsWith("# "))
        ?.replaceFirst("# ", "");
    var links = lines.fold([], (accum, line) {
      var match =
          RegExp(r'^=>\s*(\S+)\s+(\d{4}-\d{2}-\d{2})(.*)$').matchAsPrefix(line);
      if (match != null) {
        var entryUri = Uri.tryParse(match.group(1));
        if (entryUri == null || !entryUri.hasScheme) {
          entryUri = uri.resolve(match.group(1));
        }
        accum.add(
            FeedEntry(title, entryUri, match.group(2), match.group(3), line));
      }
      return accum;
    }).toList();
    return {"title": title, "links": links};
  }

  Future<Feed> updateFeed(Uri uri) async {
    var contentData;
    var redirects = [];

    while (contentData == null) {
      var bytes = List<Uint8List>();
      await onURI(uri, (_a, newBytes, _c) {
        bytes.add(newBytes);
      }, (_a, _b, _c, _d) {}, (_a, _b, _c) {}, 1);
      if (bytes.isEmpty) {
        return null;
      }

      ContentData parsedData = parse(bytes);
      if (parsedData == null) {
        return null;
      }
      if (parsedData.mode == "redirect") {
        var newUri = Uri.tryParse(parsedData.content);
        if (redirects.contains(parsedData.content) || redirects.length >= 5) {
          return null;
        }
        redirects.add(newUri);
        uri = newUri;
      } else if (parsedData.mode == 'content') {
        contentData = parsedData;
      } else {
        return null;
      }
    }

    var result = parseFeed(uri, contentData.content);
    var feed = Feed(uri, result['title'], result['links'], contentData.content,
        new DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc()));

    if (feed != null) {
      final Database db = await database;
      await db.rawUpdate(
          "update feeds set content = ?, last_fetched_at = ? where uri = ?",
          [feed.content, feed.lastFetchedAt, feed.uri.toString()]);
    }
    return feed;
  }

  updateFeeds() async {
    final Database db = await database;
    var rows = await db.rawQuery("select * from feeds");
    List<Feed> tempfeeds = [];
    for (var row in rows) {
      var feed = await updateFeed(Uri.tryParse(row["uri"]));
      tempfeeds.add(feed);
    }

    setState(() {
      feeds = tempfeeds;
    });
  }

  init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bookmarks = (prefs.getStringList('bookmarks') ?? []).toSet();
    recents = (prefs.getStringList('recent') ?? []);
    feeds = (prefs.getStringList('feeds') ?? []);
    settings = {
      "homepage":
          (prefs.getString("homepage") ?? "gemini://gemini.circumlunar.space/"),
      "search": (prefs.getString("search") ?? "gemini://gus.guru/search")
    };

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

    updateFeeds();
    onNewTab();
  }

  addRecent(uriString) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      recents.remove(uriString);
      recents.add(uriString);
      if (recents.length > 100) {
        recents = recents.skip(recents.length - 100).toList();
      }

      prefs.setStringList('recent', recents);
    });
  }

  removeFeed(feed) async {
    final Database db = await database;
    await db
        .rawDelete("delete from feeds where uri = ?", [feed.uri.toString()]);
    setState(() {
      feeds.remove(feed);
    });
  }

  toggleFeed(uriString) async {
    var uri = toSchemeUri(uriString);
    if (uri != null) {
      final Database db = await database;
      var rows = await db
          .rawQuery("select * from feeds where uri = ?", [uri.toString()]);
      if (rows.length == 0) {
        await db
            .rawInsert("insert into feeds (uri) values (?)", [uri.toString()]);
        var feed = await updateFeed(uri);
        setState(() {
          feeds.add(feed);
        });
      } else {
        await db.rawDelete("delete from feeds where uri = ?", [uri.toString()]);
        setState(() {
          feeds.removeWhere((element) => element.uri == uri);
        });
      }
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

  onSaveSettings(String key, String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      if (value.trim().isNotEmpty) {
        settings[key] = value;
        prefs.setString(key, value);
      } else {
        settings.remove(key);
        prefs.remove(key);
      }
    });
  }

  onNewTab({String initialLocation, bool menuPage}) {
    if (initialLocation == null) {
      initialLocation = settings["homepage"];
    }
    if (menuPage ?? false) {
      //defaults to false if null
      setState(() {
        Navigator.pushNamed(navigatorKey.currentContext, "/directory");
      });
    } else {
      //else when menuPage not set and want to open normal tab
      setState(() {
        var key = GlobalObjectKey(DateTime.now().millisecondsSinceEpoch);
        tabs.add({
          "key": key,
          "widget": BrowserTab(
              Uri.tryParse(initialLocation), onNewTab, addRecent,
              key: key)
        });
        tabIndex = tabs.length - 1;
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
      if (tabIndex == dropIndex) {
        tabIndex = 0;
      } else if (tabIndex > dropIndex) {
        tabIndex -= 1;
      }
    });
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MaterialApp(
        title: 'deedum',
        key: materialKey,
        navigatorKey: navigatorKey,
        theme: ThemeData(
          fontFamily: "Source Serif Pro",
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: "Source Serif Pro",
          primarySwatch: Colors.grey,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        builder: (context, child) {
          return MediaQuery(
            child: child,
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.15),
          );
        },
        initialRoute: '/',
        routes: {
          '/': (context) => WillPopScope(
              onWillPop: () async {
                GlobalObjectKey w = tabs[tabIndex]["key"];
                BrowserTabState s = w.currentState;
                return s.handleBack();
              },
              child: IndexedStack(
                  index: tabIndex,
                  children: <Widget>[] +
                      tabs.map<Widget>((t) => t["widget"]).toList())),
          "/directory": (context) => Directory(
                children: [
                  Tabs(tabs, onNewTab, onSelectTab, onDeleteTab, onBookmark,
                      toggleFeed),
                  Feeds(feeds, onNewTab, removeFeed, updateFeed),
                  Bookmarks(bookmarks, onNewTab, onBookmark),
                  History(recents, onNewTab, onBookmark),
                  Settings(settings, onSaveSettings)
                ],
                icons: [
                  Icons.tab,
                  Icons.rss_feed,
                  Icons.bookmark_border,
                  Icons.history,
                  Icons.settings
                ],
              )
        });
  }

  @override
  void dispose() {
    super.dispose();
    _sub.cancel();
  }

  @override
  bool get wantKeepAlive => true;
}
