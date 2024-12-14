// ignore: unused_import
import 'dart:developer';

import 'package:deedum/models/content_data.dart';
import 'package:deedum/models/feed.dart';
import 'package:deedum/models/identity.dart';
import 'package:deedum/models/tab.dart';
import 'package:deedum/models/tab_state.dart';
import 'package:deedum/net.dart';
import 'package:deedum/parser.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sqflite/sqflite.dart';

final appStateProvider = ChangeNotifierProvider((ref) {
  return AppState();
});

class AppState with ChangeNotifier {
  TabState tabState = TabState();
  Set<String> bookmarks = {};
  List<String> recents = [];
  List<Feed> feeds = [];
  List<String> feed = [];
  List<Identity> identities = [];
  Map settings = {};
  AppState() {
    init();
  }

  Future<void> init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bookmarks = (prefs.getStringList('bookmarks') ?? []).toSet();
    recents = (prefs.getStringList('recent') ?? []);

    settings = {
      "homepage": (prefs.getString("homepage")),
      "ansiColors": (prefs.getString("ansiColors") ?? "0"),
      "search":
          (prefs.getString("search") ?? "gemini://geminispace.info/search")
    };
    updateFeeds();
    final Database db = database;
    var rows = await db.rawQuery("select * from identities");
    for (var row in rows) {
      var identity = Identity(row["name"] as String,
          existingCertString: row["cert"] as String,
          existingPrivateKeyString: row["private_key"] as String);
      identities.add(identity);
    }
    onNewTab(null);
  }

  void onSaveSettings(String key, String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (value.trim().isNotEmpty) {
      settings[key] = value;
      prefs.setString(key, value);
    } else {
      settings.remove(key);
      prefs.remove(key);
    }
  }

  void addRecent(String uriString) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    recents.remove(uriString);
    recents.add(uriString);
    if (recents.length > 100) {
      recents = recents.skip(recents.length - 100).toList();
    }

    prefs.setStringList('recent', recents);
    notifyListeners();
  }

  void onNewTab(String? initialLocation) {
    initialLocation ??= settings['homepage'];
    var ident = DateTime.now().millisecondsSinceEpoch;
    tabState.add(
        ident,
        Tab(ident, initialLocation, addRecent, notifyListeners, identities,
            feeds));
    tabState.tabIndex = tabCount() - 1;
    notifyListeners();
  }

  void onSelectTab(int index) {
    tabState.tabIndex = index;
    notifyListeners();
  }

  void onDeleteTab(int dropIndex) {
    tabState.removeIndex(dropIndex);
    if (tabState.current() == null) {
      onNewTab(null);
    }
    notifyListeners();
  }

  void onBookmark(String uriString) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (bookmarks.contains(uriString)) {
      bookmarks.remove(uriString);
    } else {
      bookmarks.add(uriString);
    }

    prefs.setStringList('bookmarks', bookmarks.toList());
    notifyListeners();
  }

  void onFeed(String uriString) async {
    var uri = toSchemeUri(uriString);
    if (uri != null) {
      final Database db = database;
      var rows = await db
          .rawQuery("select uri from feeds where uri = ?", [uri.toString()]);

      if (rows.isEmpty) {
        var feed = await updateFeed(uri);
        if (feed != null) {
          feeds.add(feed);
        }
      } else {
        await db.rawDelete("delete from feeds where uri = ?", [uri.toString()]);
        feeds.removeWhere((element) => element.uri == uri);
      }
    }
    notifyListeners();
  }

  Identity? currentIdentity() {
    Uri? currentUri = tabState.current()?.uri;
    return currentUri != null
        ? identities.firstOrNull((element) => element.matches(currentUri))
        : null;
  }

  int tabCount() {
    return tabState.tabs.length;
  }

  bool currentLoading() {
    return tabState.current()?.loading ?? true;
  }

  List currentLogs() {
    return tabState.current()!.logs;
  }

  void onLocation(location) {
    tabState.current()?.onLocation(location, identities, feeds);
  }

  Uri? currentUri() {
    return tabState.current()?.uri;
  }

  String? currentMeta() {
    return tabState.current()?.parsedData?.meta;
  }

  int currentTabIndex() {
    return tabState.tabIndex;
  }

  bool currentShouldCertDialog() {
    return tabState.current()?.shouldCertDialog() ?? false;
  }

  bool currentShouldSearchDialog() {
    return tabState.current()?.shouldSearchDialog() ?? false;
  }

  parseFeed(Uri? uri, List<String> lines) {
    var title = lines
        .firstWhere((line) => line.startsWith("# "),
            orElse: () => uri!.toString())
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
    List<String>? lines;
    List<Uri?> redirects = [];

    while (lines == null) {
      ContentData parsedData = ContentData();
      await onURI(uri!, (_a, newBytes, _c) {
        if (newBytes != null) {
          parse(parsedData, newBytes);
        }
      }, (_a, _b, _c, _d, _e, _f) {}, (_a, _b, _c) {}, identities, feeds, 1);

      if (parsedData.mode == Modes.redirect) {
        var newUri = Uri.tryParse(parsedData.meta!);
        if (redirects.contains(newUri) || redirects.length >= 5) {
          return null;
        }
        redirects.add(newUri);
        uri = newUri;
      } else if (parsedData.mode == Modes.gem) {
        lines = parsedData.lines;
      } else {
        return null;
      }
    }

    var result = parseFeed(uri, lines);
    var feed = Feed(uri, result['title'], result['links'], lines.join("\n"),
        DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc()));

    final Database db = database;
    await db.rawInsert(
        "insert or replace into feeds (uri, content, last_fetched_at) values (?,?,?)",
        [feed.uri.toString(), feed.content, feed.lastFetchedAt]);
    notifyListeners();
    return feed;
  }

  void updateFeeds() async {
    final Database db = database;
    var rows = await db.rawQuery("select * from feeds");
    List<Feed> tempfeeds = [];
    for (var row in rows) {
      var feed = await updateFeed(Uri.tryParse(row["uri"] as String));
      if (feed != null) {
        tempfeeds.add(feed);
      }
    }
    feeds = tempfeeds;
    notifyListeners();
  }

  void removeFeed(Feed feed) async {
    final Database db = database;
    await db
        .rawDelete("delete from feeds where uri = ?", [feed.uri.toString()]);
    feeds.remove(feed);

    notifyListeners();
  }

  void onIdentity(Identity identity, Uri uri) {
    if (identity.matches(uri)) {
      identity.pages
          .removeWhere((element) => uri.toString().startsWith(element));
    } else {
      identity.addPage(uri.toString());
    }
    notifyListeners();
  }

  void createIdentity(String name,
      {Uri? uri,
      String? existingCertString,
      String? existingPrivateKeyString}) async {
    var id = Identity(name,
        existingCertString: existingCertString,
        existingPrivateKeyString: existingPrivateKeyString);
    Database db = database;
    db.rawInsert(
        "insert into identities (name, cert, private_key) values (?,?,?)",
        [id.name, id.certString, id.privateKeyString]);
    if (uri != null) {
      id.addPage(uri.toString());
    }
    identities.add(id);
    notifyListeners();
  }

  bool handleBack() {
    return tabState.current()!.handleBack(identities, feeds);
  }

  bool handleForward() {
    return tabState.current()!.handleForward(identities, feeds);
  }

  bool canGoBack() {
    return tabState.current()!.canGoBack();
  }

  bool canGoForward() {
    return tabState.current()!.canGoForward();
  }

  Iterable<E> indexedTabs<E>(E Function(int index, Tab item) transform) {
    return tabState.tabOrder.mapIndexed((index, ident) {
      return transform(index, tabByIdent(ident));
    });
  }

  void toggleSourceView() {
    tabState.current()!.viewingSource = !tabState.current()!.viewingSource;
    notifyListeners();
  }

  bool viewingSource() {
    return tabState.current()!.viewingSource;
  }

  Tab tabByIdent(int ident) {
    return tabState.tabs[ident]!;
  }

  bool hasError() {
    var tab = tabState.current();
    return tab?.contentData != null && tab?.contentData!.mode == Modes.error;
  }

  void clearCurrentLogs() {
    tabState.current()?.logs.clear();
    notifyListeners();
  }

  void removeIdentity(Identity identity) async {
    Database db = database;
    var x = await db
        .rawDelete("delete from identities where name = ?", [identity.name]);
    if (x > 0) {
      identities.remove(identity);
    }
    notifyListeners();
  }
}

class HistoryEntry {
  Uri location;
  ContentData? contentData;
  double scrollPosition;

  HistoryEntry(this.location, this.contentData, this.scrollPosition);

  @override
  String toString() {
    return "$location $scrollPosition";
  }
}
