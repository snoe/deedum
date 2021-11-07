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
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<AppState> appKey = GlobalKey();
final GlobalKey<AppState> materialKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  database = await openDatabase(
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

  runApp(MaterialApp(home: App(key: appKey)));
}

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

  @override
  AppState createState() => AppState();
}

class FeedEntry {
  String? entryDate;
  String? entryTitle;
  Uri entryUri;
  String line;
  String feedTitle;

  FeedEntry(this.feedTitle, this.entryUri, this.entryDate, this.entryTitle,
      this.line);
}

class AppState extends State<App> with AutomaticKeepAliveClientMixin {
  List tabs = [];
  int tabIndex = 0;

  Set<String> bookmarks = {};
  List<String> recents = [];
  List<Feed?> feeds = [];
  List<String> feed = [];

  Map settings = {};
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();

    tabIndex = 0;
    init();
  }

  parseFeed(Uri? uri, String content) {
    var lines = LineSplitter.split(content);
    var title = lines
        .firstWhere((line) => line.startsWith("# "))
        .replaceFirst("# ", "");
    var links = lines.fold([], (dynamic accum, line) {
      var match =
          RegExp(r'^=>\s*(\S+)\s+(\d{4}-\d{2}-\d{2})(.*)$').matchAsPrefix(line);
      if (match != null) {
        var entryUri = Uri.tryParse(match.group(1)!);
        if (entryUri == null || !entryUri.hasScheme) {
          entryUri = uri!.resolve(match.group(1)!);
        }
        accum.add(
            FeedEntry(title, entryUri, match.group(2), match.group(3), line));
      }
      return accum;
    }).toList();
    return {"title": title, "links": links};
  }

  Future<Feed?> updateFeed(Uri? uri) async {
    ContentData? contentData;
    List<Uri?> redirects = [];

    while (contentData == null) {
      var bytes = <Uint8List?>[];
      await onURI(uri!, (_a, newBytes, _c) {
        bytes.add(newBytes);
      }, (_a, _b, _c, _d) {}, (_a, _b, _c) {}, 1);
      if (bytes.isEmpty) {
        return null;
      }

      ContentData? parsedData = parse(bytes);
      if (parsedData == null) {
        return null;
      }
      if (parsedData.mode == "redirect") {
        var newUri = Uri.tryParse(parsedData.content!);
        if (redirects.contains(newUri) || redirects.length >= 5) {
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

    var result = parseFeed(uri, contentData.content!);
    var feed = Feed(uri, result['title'], result['links'], contentData.content,
        DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc()));

    final Database db = database;
    await db.rawUpdate(
        "update feeds set content = ?, last_fetched_at = ? where uri = ?",
        [feed.content, feed.lastFetchedAt, feed.uri.toString()]);
    return feed;
  }

  updateFeeds() async {
    final Database db = database;
    var rows = await db.rawQuery("select * from feeds");
    List<Feed?> tempfeeds = [];
    for (var row in rows) {
      var feed = await updateFeed(Uri.tryParse(row["uri"] as String));
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
    feeds = (prefs.getStringList('feeds') as List<Feed?>? ?? []);
    settings = {
      "homepage":
          (prefs.getString("homepage") ?? "gemini://gemini.circumlunar.space/"),
      "search": (prefs.getString("search") ?? "gemini://gus.guru/search")
    };

    _sub = linkStream.listen((String? link) {
      onNewTab(link);
    }, onError: (err) {
      log("oop");
    });

    try {
      var link = await getInitialLink();
      if (link != null) {
        onNewTab(link);
        return;
      }
    } on PlatformException {
      log("oop");
    }

    updateFeeds();
    onNewTab();
  }

  void addRecent(String uriString) async {
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

  void removeFeed(Feed feed) async {
    final Database db = database;
    await db
        .rawDelete("delete from feeds where uri = ?", [feed.uri.toString()]);
    setState(() {
      feeds.remove(feed);
    });
  }

  Future<void> toggleFeed(String uriString) async {
    var uri = toSchemeUri(uriString);
    if (uri != null) {
      final Database db = database;
      var rows = await db
          .rawQuery("select * from feeds where uri = ?", [uri.toString()]);
      if (rows.isEmpty) {
        await db
            .rawInsert("insert into feeds (uri) values (?)", [uri.toString()]);
        var feed = await updateFeed(uri);
        setState(() {
          feeds.add(feed);
        });
      } else {
        await db.rawDelete("delete from feeds where uri = ?", [uri.toString()]);
        setState(() {
          feeds.removeWhere((element) => element!.uri == uri);
        });
      }
    }
  }

  void onBookmark(String uriString) async {
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

  void onSaveSettings(String key, String value) async {
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

  void onNewTab([String? initialLocation, bool? menuPage]) {
    initialLocation ??= settings['homepage'];
    if (menuPage ?? false) {
      //defaults to false if null
      setState(() {
        Navigator.pushNamed(navigatorKey.currentContext!, "/directory");
      });
    } else {
      //else when menuPage not set and want to open normal tab
      setState(() {
        var key = GlobalObjectKey(DateTime.now().millisecondsSinceEpoch);
        tabs.add({
          "key": key,
          "widget": BrowserTab(
            key: key,
            initialLocation: Uri.tryParse(initialLocation!)!,
            onNewTab: onNewTab,
            addRecent: addRecent,
          )
        });
        tabIndex = tabs.length - 1;
      });
    }
  }

  void onSelectTab(int newIndex) {
    setState(() {
      tabIndex = newIndex;
    });
  }

  void onDeleteTab(int dropIndex) {
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
            child: child!,
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.15),
          );
        },
        localizationsDelegates: const [
          DefaultWidgetsLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
        ],
        initialRoute: '/',
        routes: {
          '/': (context) => WillPopScope(
              onWillPop: () async {
                GlobalObjectKey w = tabs[tabIndex]["key"];
                BrowserTabState s = w.currentState as BrowserTabState;
                return s.handleBack();
              },
              child: IndexedStack(
                  index: tabIndex,
                  children: [for (final t in tabs) t["widget"]])),
          "/directory": (context) => Directory(
                children: [
                  Tabs(
                    tabs: tabs,
                    onNewTab: onNewTab,
                    onSelectTab: onSelectTab,
                    onDeleteTab: onDeleteTab,
                    onBookmark: onBookmark,
                    onFeed: toggleFeed,
                  ),
                  Feeds(
                    feeds: feeds,
                    onNewTab: onNewTab,
                    removeFeed: removeFeed,
                    updateFeed: updateFeed,
                  ),
                  Bookmarks(
                    bookmarks: bookmarks,
                    onNewTab: onNewTab,
                    onBookmark: onBookmark,
                  ),
                  History(
                    recents: recents,
                    onNewTab: onNewTab,
                    onBookmark: onBookmark,
                  ),
                  Settings(
                    settings: settings,
                    onSaveSettings: onSaveSettings,
                  )
                ],
                icons: const [
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
