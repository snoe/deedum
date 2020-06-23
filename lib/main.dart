import 'dart:async';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:deedum/content.dart';
import 'package:deedum/net.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter/foundation.dart' as foundation;

bool get isIos => foundation.defaultTargetPlatform == foundation.TargetPlatform.iOS;

void main() {
  runApp(BrowserApp());
}

class BrowserApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'deedum',
      theme: ThemeData(
        fontFamily: "Merriweather",
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Browser(),
    );
  }
}

class Browser extends StatefulWidget {
  Browser({Key key}) : super(key: key);

  @override
  _BrowserState createState() => _BrowserState();
}

class _BrowserState extends State<Browser> {
  TextEditingController _controller;
  ContentData _content;
  List<Uri> _history = [];
  int _historyIndex = -1;
  bool _loading = false;
  StreamSubscription _sub;
  bool _bookmarked = false;
  Uri _uri;

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

    Set<String> bookmarks = (prefs.getStringList('bookmarks') ?? []).toSet();

    setState(() {
      _bookmarked = bookmarks.contains(uri.toString());
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
                  icon: Icon(Icons.star, color: _bookmarked ? Colors.yellow : null),
                  onPressed: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    Set<String> bookmarks = (prefs.getStringList('bookmarks') ?? []).toSet();
                    var text = _controller.text;
                    if (bookmarks.contains(_controller.text)) {
                      bookmarks.remove(text);
                      setState(() {
                        _bookmarked = false;
                      });
                    } else {
                      bookmarks.add(text);
                      setState(() {
                        _bookmarked = true;
                      });
                    }

                    prefs.setStringList('bookmarks', bookmarks.toList());
                  },
                ), // overflow menu
                PopupMenuButton<String>(
                  onSelected: (result) {
                    if (result == "forward") {
                      _handleForward();
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                     PopupMenuItem<String>(
                      enabled: (_historyIndex != (_history.length - 1)),
                      value: "forward",
                      child: Text('Forward'),
                    )
                  ],
                )
              ],
            ),
            body: 
            SingleChildScrollView(
                key: ObjectKey(_content),
                child:  Padding(
        padding: EdgeInsets.fromLTRB(padding, padding, padding, padding),
        child: Content(
                  contentData: _content,
                  onLink: onLink,
                  onSearch: onSearch,
                ))
                )));
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
