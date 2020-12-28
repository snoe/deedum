import 'dart:typed_data';

import 'package:deedum/address_bar.dart';
import 'package:deedum/content.dart';
import 'package:deedum/main.dart';
import 'package:deedum/net.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'dart:developer';

import 'parser.dart';
import 'dart:math' as math;

class HistoryEntry {
  final Uri location;
  List<Uint8List> bytes;
  double scrollPosition;

  HistoryEntry(this.location, this.bytes, this.scrollPosition);

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
  List<Uint8List> bytes;
  ContentData contentData;
  ContentData parsedData;
  List<HistoryEntry> _history = [];
  int _historyIndex = -1;
  bool _loading = false;
  Uri uri;
  ScrollController _scrollController = ScrollController();
  int _requestID = 1;

  List _redirects = [];
  List _logs = [];
  bool showLogs = false;

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

  void _handleDone(Uri location, bool timeout, bool badScheme, int requestID) async {
    if (requestID != _requestID) {
      return;
    }
    setState(() {
      if (parsedData == null) {
        var allLogs = List.from(_logs);
        allLogs.removeWhere((element) => (element[0] != "error" || element[2] != requestID));
        var logStrings = allLogs.map((log) => log[3]);
        if (badScheme) {
          contentData = ContentData(mode: "opening", content: "Launching app for $location");
        } else if (logStrings.isNotEmpty) {
          contentData = ContentData(mode: "error", content: logStrings.join("\n"));
        } else if (timeout) {
          contentData = ContentData(mode: "error", content: "No response. timeout");
        } else {
          contentData = ContentData(mode: "error", content: "No response. connection closed");
        }
      } else if (parsedData.mode == "error") {
        contentData = parsedData;        
      } else if (parsedData.mode == 'redirect') {
        if (_redirects.contains(parsedData.content) || _redirects.length >= 5) {
          contentData = ContentData(mode: "error", content: "REDIRECT LOOP\n--------------\n" + _redirects.join("\n"));
        } else {
          var newLocation = Uri.parse(parsedData.content);
          if (!newLocation.hasScheme) {
            newLocation = location.resolve(parsedData.content);
          }
          _redirects.add(parsedData.content);
          _requestID += 1;
          resetResponse(newLocation, redirect: true);
          onURI(newLocation, _handleBytes, _handleDone, _handleLog, _requestID);
        }
      } else {
        _history[_historyIndex].bytes = bytes;
        contentData = parsedData;
      }
      _loading = false;
    });
  }

  void resetResponse(Uri location, {bool redirect = false}) {
    contentData = null;
    parsedData = null;
    bytes = List<Uint8List>();

    _controller.text = location.toString();
    uri = location;
    if (!redirect) {
      _redirects = [];
      addRecent(location.toString());
    }
  }

  void _handleLog(String level, String message, int requestID) async {
    log(message);
    setState(() {
      _logs = _logs.sublist(math.max(_logs.length - 100, 0), _logs.length);
      _logs.add([level, new DateTime.now(), requestID, message]);
    });
  }

  void _clearLogs() async {
    setState(() {
      _logs.clear();
    });
  }

  Future<void> _showLogs() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {

        var orderedLogs = _logs.reversed.toList();
        DateFormat formatter = DateFormat('HH:mm:ss.SSSS');

        return AlertDialog(
            title: Text('Logs'),
            contentPadding: EdgeInsets.zero,
            actions:[IconButton(icon: Icon(Icons.delete), onPressed: () { _clearLogs(); Navigator.of(context).pop();})],
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: orderedLogs.length,
                itemBuilder: (context, i) {
                  var log = orderedLogs[i];
                  var level = log[0];
                  var timestamp = log[1];
                  var requestID = log[2];
                  var message = log[3];
                  String formatted = formatter.format(timestamp);
                  var levelColor;
                  if (level == "error") {
                    levelColor = Colors.redAccent;
                  } else if (level == "warn") {
                    levelColor = Colors.yellowAccent;
                  } else {
                    levelColor = Colors.white;
                  }
                  return ListTile(title: Text("[$formatted] #$requestID"), subtitle: Text(message), tileColor: levelColor);
                },
              ),
            ));
      },
    );
  }

  void _handleBytes(Uri location, Uint8List newBytes, int requestID) async {
    if (newBytes == null) {
      return;
    }
    _handleLog("debug", "Received ${newBytes.length} bytes $location", requestID);
    if (requestID != _requestID) {
      return;
    }
    setState(() {
      bytes.add(newBytes);
      parsedData = parse(bytes);
      if (parsedData != null && parsedData.mode == "content") {
        contentData = parsedData;
      }
    });
  }

  Future<bool> _handleBack() async {
    if (_historyIndex > 0) {
      _handleHistory(-1);
      return false;
    } else {
      return true;
    }
  }

  Future<bool> _handleForward() async {
    if (_historyIndex < (_history.length - 1)) {
      _handleHistory(1);
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

  void _handleHistory(int dir) async {
    _requestID += 1;

    setState(() {
      var oldPosition = _scrollController.position.pixels;
      _history[_historyIndex].scrollPosition = oldPosition;
      _historyIndex += dir;
      var entry = _history[_historyIndex];

      resetResponse(entry.location);
      if (entry.bytes != null) {
        _scrollController = ScrollController(initialScrollOffset: entry.scrollPosition);
        contentData = parse(entry.bytes);
      } else {
        onLocation(entry.location);
      }

      _loading = false;
    });
  }

  onLocation(Uri location) {
    if (_historyIndex != -1) {
      var oldPosition = _scrollController.position.pixels;
      _history[_historyIndex].scrollPosition = oldPosition;
    }

    _requestID += 1;

    setState(() {
      _scrollController = ScrollController(initialScrollOffset: 0);
      _loading = true;

      resetResponse(location);

      if (_history.isNotEmpty && _history[_historyIndex].location == location) {
        _historyIndex -= 1;
      }
      _history = _history.sublist(0, _historyIndex + 1);
      _history.add(HistoryEntry(location, null, 0));

      _historyIndex = _history.length - 1;
    });

    onURI(location, _handleBytes, _handleDone, _handleLog, _requestID);
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

    var contentWidget = SingleChildScrollView(
        key: ObjectKey(contentData),
        controller: _scrollController,
        child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 17, 20),
            child: Content(
              contentData: contentData,
              onLink: onLink,
              onSearch: onSearch,
            )));

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
                    icon: Icon(Icons.code),
                    onPressed: () => _showLogs(),
                    color: Colors.black,
                  ),
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
            body: contentWidget));
  }
}
