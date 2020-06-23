import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:deedum/content.dart';
import 'package:deedum/net.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter/foundation.dart' as foundation;

bool get isIos => foundation.defaultTargetPlatform == foundation.TargetPlatform.iOS;
final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();

final GlobalKey<_AppState> appKey = new GlobalKey();
void main() {
  runApp(App());
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BrowserApp(key: appKey);
  }
}

class BrowserApp extends StatefulWidget {
  BrowserApp({Key key}) : super(key: key);

  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<BrowserApp> with AutomaticKeepAliveClientMixin {
  List tabs = [];
  int tabIndex = 0;
  int previousTabIndex = 0;

  Set<String> bookmarks = Set();

  void initState() {
    super.initState();

    tabIndex = 0;
    init();
  }

  init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bookmarks = (prefs.getStringList('bookmarks') ?? []).toSet();
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

  onNewTab() {
    if (tabIndex == 0) {
      setState(() {
        var key = GlobalObjectKey(DateTime.now().millisecondsSinceEpoch);
        tabs.add({"key": key, "widget": Browser(onNewTab, key: key)});
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
  bool get wantKeepAlive => true;
}

class Tabs extends StatelessWidget {
  final onNewTab;
  final onSelectTab;
  final onDeleteTab;
  final onBookmark;
  final List tabs;

  final tabKey = GlobalObjectKey(DateTime.now().millisecondsSinceEpoch);

  Tabs(this.tabs, this.onNewTab, this.onSelectTab, this.onDeleteTab, this.onBookmark);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.orange,
          centerTitle: true,
          title: Text([
            "████████╗ █████╗ ██████╗ ███████╗", 
            "╚══██╔══╝██╔══██╗██╔══██╗██╔════╝", 
            "   ██║   ███████║██████╔╝███████╗",
            "   ██║   ██╔══██║██╔══██╗╚════██║",
            "   ██║   ██║  ██║██████╔╝███████║",
            "   ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚══════╝"].join("\n"),
              style: TextStyle(fontSize: 5.5, fontFamily: "DejaVu Sans Mono")),
        ),
        body: SingleChildScrollView(
            child: Column(
                children: <Widget>[
                      Card(
                        color: Colors.black12,
                        child: ListTile(
                          onTap: () => onNewTab(),
                          leading: Icon(
                            Icons.add,
                            color: Colors.white,
                          ),
                          title: Text("New Tab", style: TextStyle(color: Colors.white)),
                        ),
                      )
                    ] +
                    tabs
                        //.map((tab) => Text("${tab["key"]} ${tab["key"].currentState}")).toList()

                        .mapIndexed((index, tab) {
                      var tabState = ((tab["key"] as GlobalObjectKey).currentState as _BrowserState);
                      var uriString = tabState?._controller?.text;
                      var selected = appKey.currentState.previousTabIndex == index + 1;
                      if (uriString != null) {
                        return Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Card(
                                shape: selected
                                    ? RoundedRectangleBorder(
                                        side: BorderSide(color: Colors.black, width: 2),
                                        borderRadius: BorderRadius.circular(5))
                                    : null,
                                child: Row(children: [
                                  Expanded(
                                      flex: 1,
                                      child: ListTile(
                                        onTap: () => onSelectTab(index + 1),
                                        leading: Icon(Icons.folder),
                                        subtitle: ExtendedText(tabState._content.content.substring(0,math.min(tabState._content.content.length, 500)), overflow: TextOverflow.ellipsis, maxLines: 2,),
                                        title: Text("${tabState._uri.host}", style: TextStyle(fontSize: 14)),
                                      )),
                                  IconButton(
                                    icon: Icon(Icons.star,
                                        color:
                                            appKey.currentState.bookmarks.contains(uriString) ? Colors.yellow : null),
                                    onPressed: () {
                                      onBookmark(uriString);
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete),
                                    onPressed: () {
                                      onDeleteTab(index);
                                    },
                                  ),
                                ])));
                      } else {
                        return Text("No tab?");
                      }
                    }).toList())));
  }
}

class Browser extends StatefulWidget {
  final onNewTab;

  Browser(this.onNewTab, {Key key}) : super(key: key);

  @override
  _BrowserState createState() => _BrowserState(onNewTab);
}

class _BrowserState extends State<Browser> {
  TextEditingController _controller;
  ContentData _content;
  List<Uri> _history = [];
  int _historyIndex = -1;
  bool _loading = false;
  StreamSubscription _sub;
  Uri _uri;
  final onNewTab;

  _BrowserState(this.onNewTab);

  void initState() {
    super.initState();
    _controller = TextEditingController();
    init();
  }

  init() async {
    _sub = getLinksStream().listen((String link) {
      onLocation(Uri.parse(link));
    }, onError: (err) {
      log("oop");
    });

    try {
      var link = await getInitialLink();
      if (link != null) {
        onLocation(Uri.parse(link));
        return;
      }
    } on PlatformException {
      log("oop");
    }
    _uri = Uri.parse("about://homepage/");
    onLocation(_uri);
  }

  void dispose() {
    _controller.dispose();
    _sub.cancel();
    super.dispose();
  }

  void _handleLoad() async {
    setState(() {
      _loading = true;
    });
  }

  void _handleDone() async {
    setState(() {
      _loading = false;
    });
  }

  void _handleContent(Uri uri, ContentData contentData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> recent = (prefs.getStringList('recent') ?? []);
    recent.remove(uri.toString());
    recent.add(uri.toString());
    if (recent.length > 10) {
      recent = recent.skip(recent.length - 10).toList();
    }

    prefs.setStringList('recent', recent);

    setState(() {
      _controller.text = uri.toString();

      if (_history.isEmpty || _history[_historyIndex] != uri) {
        _history = _history.sublist(0, _historyIndex + 1);
        _history.add(uri);
        _historyIndex = _history.length - 1;
      }
      _content = contentData;
    });
  }

  Future<bool> _handleBack() async {
    if (_historyIndex > 0) {
      _historyIndex -= 1;
      onLocation(_history[_historyIndex]);
      return false;
    } else {
      return true;
    }
  }

  Future<bool> _handleForward() async {
    if (_historyIndex < (_history.length - 1)) {
      _historyIndex += 1;
      onLocation(_history[_historyIndex]);
      return false;
    } else {
      return true;
    }
  }

  onSearch(String encodedSearch) {
    if (encodedSearch.isNotEmpty) {
      var u = Uri(scheme: _uri.scheme, host: _uri.host, port: _uri.port, path: _uri.path, query: encodedSearch);
      onLocation(u);
    }
  }

  onLink(String link) {
    var location = Uri.parse(link);
    if (!location.hasScheme) {
      location = _uri.resolve(link);
    }
    onLocation(location);
  }

  onLocation(Uri location) {
    onURI(location, _handleContent, _handleLoad, _handleDone, []);
    setState(() {
      _uri = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    var bottomBar;
    if (isIos) {
      bottomBar = BottomAppBar(
          child: ButtonBar(
        children: [
          FlatButton(
              onPressed: _historyIndex == 0
                  ? null
                  : () {
                      _handleBack();
                    },
              child: Icon(Icons.keyboard_arrow_left, size: 30)),
          FlatButton(
              onPressed: _historyIndex == (_history.length - 1)
                  ? null
                  : () {
                      _handleForward();
                    },
              child: Icon(Icons.keyboard_arrow_right, size: 30))
        ],
        alignment: MainAxisAlignment.spaceBetween,
      ));
    }

    return WillPopScope(
        onWillPop: _handleBack,
        child: Scaffold(
            backgroundColor: (_content != null && _content.mode == "error") ? Colors.deepOrange : Colors.white,
            bottomNavigationBar: bottomBar,
            appBar: AppBar(
                backgroundColor: Colors.orange,
                title: TopBar(
                  controller: _controller,
                  onLocation: onLocation,
                  loading: _loading,
                ),
                actions: [
                  IconButton(
                    icon: SizedBox(
                        width: 20,
                        height: 20,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(width: 2, color: Colors.black),
                                borderRadius: BorderRadius.all(Radius.circular(3))),
                            child: Align(
                                alignment: Alignment.center,
                                child: Text("${appKey.currentState.tabs.length}",
                                    style: TextStyle(
                                        color: Colors.black, fontFamily: "DejaVu Sans Mono", fontSize: 12))))),
                    onPressed: onNewTab,
                  ),
                  IconButton(
                      disabledColor: Colors.black12,
                      icon: Icon(Icons.chevron_right),
                      onPressed: (_historyIndex != (_history.length - 1)) ? _handleForward : null)
                  /*PopupMenuButton<String>(
                      onSelected: (result) {
                        if (result == "forward") {
                          _handleForward();
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                                enabled: (_historyIndex != (_history.length - 1)),
                                value: "forward",
                                child: Text('Forward'))
                          ])*/
                ]),
            body: SingleChildScrollView(
                key: ObjectKey(_content),
                child: Padding(
                    padding: EdgeInsets.fromLTRB(padding, padding, padding, padding),
                    child: Content(
                      contentData: _content,
                      onLink: onLink,
                      onSearch: onSearch,
                    )))));
  }
}

class TopBar extends StatelessWidget {
  TopBar({this.controller, this.loading, this.onLocation});
  final TextEditingController controller;
  final loading;
  final onLocation;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          flex: 1,
          child: DecoratedBox(
              decoration: BoxDecoration(
                  color: loading ? Colors.purple : Colors.white, borderRadius: BorderRadius.all(Radius.circular(5))),
              child: Padding(
                  padding: EdgeInsets.fromLTRB(5, 0, 5, 0),
                  child: TextField(
                      controller: controller,
                      onSubmitted: (value) {
                        onLocation(Uri.parse(value));
                      })))),
    ]);
  }
}
