import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:deedum/content.dart';
import 'package:deedum/net.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';

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

class TopBar extends StatelessWidget {
  TopBar({this.controller, this.loading, this.onContent, this.onSearch, this.onLoad, this.onDone});
  final TextEditingController controller;
  final loading;
  final onContent;
  final onSearch;
  final onDone;
  final onLoad;

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
                        onURI("", value, onContent, onLoad, onDone, []);
                      })))),
    ]);
  }
}

class _BrowserState extends State<Browser> {
  TextEditingController _controller;
  ContentData _content;
  List<Uri> _history = [];
  bool _loading = false;
  StreamSubscription _sub;
  bool _bookmarked = false;

  void initState() {
    super.initState();
    _controller = TextEditingController();
    init();
  }

  init() async {
    _sub = getLinksStream().listen((String link) {
      onURI("", link, _handleContent, _handleLoad, _handleDone, []);
    }, onError: (err) {
      log("oop");
    });

    try {
      var link = await getInitialLink();
      if (link != null) {
        onURI("", link, _handleContent, _handleLoad, _handleDone, []);
        return;
      }
    } on PlatformException {
      log("oop");
    }

    onURI("", "about://homepage/", _handleContent, _handleLoad, _handleDone, []);
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
      if (_history.isEmpty || _history.last != uri) {
        _history.add(uri);
      }
      _content = contentData;
    });
  }

  Future<bool> _handleBack() async {
    if (_history.length > 1) {
      _history.removeLast();
      onURI("", _history.last.toString(), _handleContent, _handleLoad, _handleDone, []);
      return false;
    } else {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _handleBack,
        child: Scaffold(
            backgroundColor: (_content != null && _content.mode == "error") ? Colors.deepOrange : Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.orange,
              title: TopBar(
                controller: _controller,
                onLoad: _handleLoad,
                onDone: _handleDone,
                onContent: _handleContent,
                loading: _loading,
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.star,
                  color: _bookmarked ? Colors.yellow : null
                  ),
                  onPressed: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    Set<String> bookmarks = (prefs.getStringList('bookmarks') ?? []).toSet();
                    var text = _controller.text;
                    if (bookmarks.contains(_controller.text)) {
                      bookmarks.remove(text);
                      setState(() {_bookmarked = false;});
                    } else {
                      bookmarks.add(text);
                      setState(() {_bookmarked = true;});
                    }

                    prefs.setStringList('bookmarks', bookmarks.toList());
                  },
                ),
              ],
            ),
            body: SingleChildScrollView(
                key: ObjectKey(_controller.text),
                child: Content(
                  contentData: _content,
                  onSearch: (String encodedSearch) {
                    if (encodedSearch.isNotEmpty) {
                      var uri = Uri.parse(_controller.text);
                      var u =
                          Uri(scheme: uri.scheme, host: uri.host, port: uri.port, path: uri.path, query: encodedSearch);

                      onURI("", u.toString(), _handleContent, _handleLoad, _handleDone, []);
                    }
                  },
                  onLink: (String link) {
                    onURI(_controller.text, link, _handleContent, _handleLoad, _handleDone, []);
                  },
                ))));
  }
}
