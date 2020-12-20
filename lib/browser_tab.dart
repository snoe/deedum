import 'package:deedum/address_bar.dart';
import 'package:deedum/content.dart';
import 'package:deedum/main.dart';
import 'package:deedum/net.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:developer';

class HistoryEntry {
  final Uri location;
  final ContentData contentData;
  double scrollPosition;

  HistoryEntry(this.location, this.contentData, this.scrollPosition);

  @override
  String toString() {
    return "$location $scrollPosition";
  }
}


class BrowserTab extends StatefulWidget {
  final initialLocation;
  final onNewTab;
  final addRecent;

  BrowserTab(this.initialLocation, this.onNewTab, this.addRecent, {Key key}) : super(key: key);

  @override
  BrowserTabState createState() => BrowserTabState(initialLocation, onNewTab, addRecent);
}

class BrowserTabState extends State<BrowserTab> {
  final initialLocation;
  final onNewTab;
  final addRecent;
  TextEditingController _controller;
  ContentData contentData;
  List<HistoryEntry> _history = [];
  int _historyIndex = -1;
  bool _loading = false;
  Uri uri;
  ScrollController _scrollController = ScrollController();

  BrowserTabState(this.initialLocation, this.onNewTab, this.addRecent);

  void initState() {
    super.initState();
    _controller = TextEditingController(text: initialLocation?.toString());
    init();
  }

  init() async {
    onLocation(initialLocation);
  }

  void dispose() {
    _controller.dispose();
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

  void _handleContent(Uri location, ContentData newContentData, {double position = 0}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> recent = (prefs.getStringList('recent') ?? []);
    recent.remove(location.toString());
    recent.add(location.toString());
    if (recent.length > 10) {
      recent = recent.skip(recent.length - 10).toList();
    }

    prefs.setStringList('recent', recent);
    var oldPosition = _scrollController.position.pixels;

    setState(() {
      _controller.text = location.toString();

      if (_history.isEmpty || _history[_historyIndex].location != location) {
        if (_historyIndex != -1) {
          _history[_historyIndex].scrollPosition = oldPosition;
        }
        _history = _history.sublist(0, _historyIndex + 1);
        _history.add(HistoryEntry(location, newContentData, 0));

        _historyIndex = _history.length - 1;
      }
      contentData = newContentData;
      _scrollController = ScrollController( initialScrollOffset: position);
    });
  }

  Future<bool> _handleBack() async {
    if (_historyIndex > 0) {
      _historyIndex -= 1;
      var entry = _history[_historyIndex];
      _handleContent(entry.location, entry.contentData, position : entry.scrollPosition);
      setState(() {
        addRecent(entry.location.toString());
        uri = entry.location;
      });
      return false;
    } else {
      return true;
    }
  }

  Future<bool> _handleForward() async {
    if (_historyIndex < (_history.length - 1)) {
      _historyIndex += 1;
      var entry = _history[_historyIndex];
      _handleContent(entry.location, entry.contentData, position : entry.scrollPosition);
      setState(() {
        addRecent(entry.location.toString());
        uri = entry.location;
      });
      return false;
    } else {
      return true;
    }
  }

  onSearch(String encodedSearch) {
    if (encodedSearch.isNotEmpty) {
      var u = Uri(scheme: uri.scheme, host: uri.host, port: uri.port, path: uri.path, query: encodedSearch);
      onLocation(u);
    }
  }

  onLink(String link) {
    var location = Uri.parse(link);
    if (!location.hasScheme) {
      location = uri.resolve(link);
    }
    onLocation(location);
  }

  onLocation(Uri location) {
    onURI(location, _handleContent, _handleLoad, _handleDone, []);
    setState(() {
      addRecent(location.toString());
      uri = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    var bottomBar;
    if (isIos) {
      bottomBar = BottomAppBar(
          color: Theme.of(context).cardColor,
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
            backgroundColor: (contentData != null && contentData.mode == "error")
                ? Colors.deepOrange
                : Theme.of(context).canvasColor,
            bottomNavigationBar: bottomBar,
            appBar: AppBar(
                backgroundColor: Colors.orange,
                title: AddressBar(
                  controller: _controller,
                  onLocation: onLocation,
                  loading: _loading,
                ),
                actions: [
                  IconButton(
                    icon: SizedBox(
                        width: 23,
                        height: 23,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(width: 2, color: Colors.black),
                                borderRadius: BorderRadius.all(Radius.circular(3))),
                            child: Align(
                                alignment: Alignment.center,
                                child: Text("${appKey.currentState.tabs.length}",
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: "DejaVu Sans Mono",
                                        fontSize: 13))))),
                    onPressed: onNewTab,
                  ),
                  IconButton(
                      disabledColor: Colors.black12,
                      color: Colors.black,
                      icon: Icon(Icons.chevron_right),
                      onPressed: (_historyIndex != (_history.length - 1)) ? _handleForward : null)
                ]),
            body: SingleChildScrollView(
                key: ObjectKey(contentData),
                controller: _scrollController,
                child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 17, 20),
                    child: Content(
                      contentData: contentData,
                      onLink: onLink,
                      onSearch: onSearch,
                    )))));
  }
}
