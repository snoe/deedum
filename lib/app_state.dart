import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:deedum/net.dart';
import 'package:deedum/parser.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

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
      "homepage":
          (prefs.getString("homepage") ?? "gemini://gemini.circumlunar.space/"),
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
    return tabState.current()!._logs;
  }

  void onLocation(location) {
    tabState.current()!.onLocation(location, identities, feeds);
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

  parseFeed(Uri? uri, String content) {
    var lines = LineSplitter.split(content);
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
    String? content;
    List<Uri?> redirects = [];

    while (content == null) {
      ContentData parsedData = ContentData(BytesBuilder(copy: false));
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
        content = parsedData.stringContent();
      } else {
        return null;
      }
    }

    var result = parseFeed(uri, content);
    var feed = Feed(uri, result['title'], result['links'], content,
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
    tabState.current()?._logs.clear();
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

class TabState {
  int tabIndex = -1;
  Map<int, Tab> tabs = {};
  List<int> tabOrder = [];

  void add(int ident, Tab tab) {
    tabs[ident] = tab;
    tabOrder.add(ident);
  }

  void removeIndex(int dropIndex) {
    var ident = tabOrder[dropIndex];
    tabOrder.removeAt(dropIndex);
    tabs.remove(ident);
    if (tabIndex == dropIndex) {
      tabIndex = 0;
    } else if (tabIndex > dropIndex) {
      tabIndex -= 1;
    }
  }

  Tab fromIndex(int index) {
    return tabs[tabOrder[index]]!;
  }

  Tab? current() {
    if (tabIndex >= 0) {
      return fromIndex(tabIndex);
    }
  }
}

class Tab {
  int ident;
  bool loading = false;
  late Uri uri;
  ContentData? parsedData;
  ContentData? contentData;

  List<HistoryEntry> history = [];

  int historyIndex = -1;
  int _requestID = 1;

  List _redirects = [];
  List _logs = [];
  bool viewingSource = false;

  void Function(String uriString) addRecent;

  void Function() notifyListeners;
  ScrollController scrollController = ScrollController(initialScrollOffset: 0);

  Tab(this.ident, initialLocation, this.addRecent, this.notifyListeners,
      identities, feeds) {
    uri = Uri.tryParse(initialLocation!)!;
    onLocation(uri, identities, feeds);
  }

  bool shouldCertDialog() {
    return loading == false && parsedData!.mode == Modes.clientCert;
  }

  bool shouldSearchDialog() {
    return loading == false && parsedData!.mode == Modes.search;
  }

  void _handleBytes(Uri location, Uint8List? newBytes, int requestID) async {
    if (newBytes == null) {
      return;
    }
    _handleLog(
        "debug", "Received ${newBytes.length} bytes $location", requestID);
    if (requestID != _requestID) {
      return;
    }
    if (parsedData != null) {
      parse(parsedData!, newBytes);
      if (parsedData!.streamable()) {
        contentData = parsedData;
      }
    }
    notifyListeners();
  }

  void _handleLog(String level, String message, int requestID) async {
    log(message);
    _logs = _logs.sublist(math.max(_logs.length - 100, 0), _logs.length);
    _logs.add([level, DateTime.now(), requestID, message]);

    notifyListeners();
  }

  void _handleDone(Uri location, bool timeout, bool badScheme,
      List<Identity> identities, List<Feed?> feeds, int requestID) async {
    if (requestID != _requestID) {
      return;
    }
    loading = false;
    var requiresInput = parsedData!.mode == Modes.clientCert ||
        parsedData!.mode == Modes.search;

    if (!requiresInput) {
      var redirectLoop = parsedData!.mode == Modes.redirect &&
          (_redirects.contains(parsedData!.meta ?? false) ||
              _redirects.length >= 5);
      if (parsedData!.mode == Modes.redirect && !redirectLoop) {
        var newLocation = Uri.tryParse(parsedData!.meta!)!;
        if (!newLocation.hasScheme) {
          newLocation = location.resolve(parsedData!.meta!);
        }
        _redirects.add(parsedData!.meta!);
        _requestID += 1;
        resetResponse(newLocation, redirect: true);
        onURI(newLocation, _handleBytes, _handleDone, _handleLog, identities,
            feeds, _requestID);
      } else {
        if (parsedData?.mode == Modes.loading) {
          var allLogs = List.from(_logs);
          allLogs.removeWhere(
              (element) => (element[0] != "error" || element[2] != requestID));
          var logStrings = allLogs.map((log) => log[3]);
          if (badScheme) {
            contentData = ContentData.gem("Launching app for $location");
          } else if (logStrings.isNotEmpty) {
            contentData = ContentData.error(logStrings.join("\n"));
          } else if (timeout) {
            contentData = ContentData.error("No response. timeout");
          } else {
            contentData = ContentData.error(
                "No response or response line. Connection closed");
          }
        } else if (parsedData!.mode == Modes.error) {
          contentData = parsedData;
        } else if (parsedData!.mode == Modes.redirect) {
          contentData = ContentData.error(
              "REDIRECT LOOP\n--------------\n" + _redirects.join("\n"));
        } else {
          history[historyIndex].contentData = parsedData!;
          contentData = parsedData;
        }
      }
    }
    notifyListeners();
  }

  void resetResponse(Uri location, {bool redirect = false}) {
    parsedData = ContentData(BytesBuilder(copy: false));
    uri = location;
    if (!redirect) {
      _redirects = [];
      addRecent(location.toString());
    }

    notifyListeners();
  }

  void onLocation(Uri location, List<Identity> identities, List<Feed?> feeds,
      {double scrollPosition = 0}) {
    if (historyIndex != -1) {
      var oldPosition = scrollPosition;
      history[historyIndex].scrollPosition = oldPosition;
    }

    _requestID += 1;

    loading = true;

    resetResponse(location);

    if (history.isNotEmpty && history[historyIndex].location == location) {
      historyIndex -= 1;
    }
    history = history.sublist(0, historyIndex + 1);
    history.add(HistoryEntry(location, null, 0));

    historyIndex = history.length - 1;

    onURI(location, _handleBytes, _handleDone, _handleLog, identities, feeds,
        _requestID);
  }

  void _handleHistory(int dir, List<Identity> identities, List<Feed?> feeds) {
    _requestID += 1;

    var oldPosition = scrollController.position.pixels;
    history[historyIndex].scrollPosition = oldPosition;
    historyIndex += dir;
    var entry = history[historyIndex];

    resetResponse(entry.location);
    if (entry.contentData != null) {
      scrollController =
          ScrollController(initialScrollOffset: entry.scrollPosition);
      contentData = entry.contentData;
    } else {
      onLocation(entry.location, identities, feeds);
    }

    loading = false;

    notifyListeners();
  }

  bool handleBack(List<Identity> identities, List<Feed?> feeds) {
    if (canGoBack()) {
      _handleHistory(-1, identities, feeds);
      return false;
    } else {
      return true;
    }
  }

  bool handleForward(List<Identity> identities, List<Feed?> feeds) {
    if (canGoForward()) {
      _handleHistory(1, identities, feeds);
      return false;
    } else {
      return true;
    }
  }

  bool canGoBack() {
    return historyIndex > 0;
  }

  bool canGoForward() {
    return historyIndex < (history.length - 1);
  }
}

class HistoryEntry {
  final Uri location;
  ContentData? contentData;
  double scrollPosition;

  HistoryEntry(this.location, this.contentData, this.scrollPosition);

  @override
  String toString() {
    return "$location $scrollPosition";
  }
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
