import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:deedum/address_bar.dart';
import 'package:deedum/browser_tab/search.dart';
import 'package:deedum/content.dart';
import 'package:deedum/main.dart';
import 'package:deedum/browser_tab/menu.dart';
import 'package:deedum/net.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'parser.dart';

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

class BrowserTab extends StatefulWidget {
  final Uri initialLocation;
  final void Function(String?, bool?) onNewTab;
  final ValueChanged<String> addRecent;

  final ValueChanged<String> onBookmark;
  final ValueChanged<String> onFeed;

  const BrowserTab({
    Key? key,
    required this.initialLocation,
    required this.onNewTab,
    required this.addRecent,
    required this.onBookmark,
    required this.onFeed,
  }) : super(key: key);

  @override
  BrowserTabState createState() => BrowserTabState();
}

class BrowserTabState extends State<BrowserTab> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  ContentData? contentData;
  ContentData? parsedData;
  List<HistoryEntry> _history = [];
  int _historyIndex = -1;
  bool _loading = false;
  Uri? uri;
  ScrollController _scrollController = ScrollController();
  int _requestID = 1;

  List _redirects = [];
  List _logs = [];
  bool _showActions = true;
  bool viewingSource = false;

  @override
  void initState() {
    super.initState();
    var initLoc = toSchemelessString(widget.initialLocation);
    _controller = TextEditingController(text: initLoc);
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      setState(() {
        _showActions = !_focusNode.hasFocus;
      });
      if (_focusNode.hasFocus) {
        _controller.selection = TextSelection(
            affinity: TextAffinity.upstream,
            baseOffset: _controller.value.text.length,
            extentOffset: 0);
      }
    });
    init();
  }

  init() async {
    onLocation(widget.initialLocation);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleDone(
      Uri location, bool timeout, bool badScheme, int requestID) async {
    if (requestID != _requestID) {
      return;
    }
    setState(() {
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
        onURI(newLocation, _handleBytes, _handleDone, _handleLog, _requestID);
      } else if (parsedData!.mode == Modes.search) {
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return SearchAlert(
                  prompt: parsedData!.meta!,
                  uri: location,
                  onLocation: onLocation);
            });
      } else {
        // Content changing
        _scrollController = ScrollController(initialScrollOffset: 0);
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
          _history[_historyIndex].contentData = parsedData!;
          contentData = parsedData;
        }
      }
      _loading = false;
    });
  }

  void resetResponse(Uri location, {bool redirect = false}) {
    parsedData = ContentData(BytesBuilder(copy: false));

    var addressLoc = toSchemelessString(location);
    _controller.text = addressLoc;
    _focusNode.unfocus();
    uri = location;
    if (!redirect) {
      _redirects = [];
      widget.addRecent(location.toString());
    }
  }

  void _handleLog(String level, String message, int requestID) async {
    log(message);
    setState(() {
      _logs = _logs.sublist(math.max(_logs.length - 100, 0), _logs.length);
      _logs.add([level, DateTime.now(), requestID, message]);
    });
  }

  void _clearLogs() async {
    setState(() {
      _logs.clear();
    });
  }

  Future<void> showLogs() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        var orderedLogs = _logs.reversed.toList();
        DateFormat formatter = DateFormat('HH:mm:ss.SSSS');

        return AlertDialog(
            title: const Text('Logs'),
            contentPadding: EdgeInsets.zero,
            actions: [
              TextButton(
                  child: const Text('Clear'),
                  onPressed: () {
                    _clearLogs();
                    Navigator.of(context).pop();
                  }),
              TextButton(
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
            content: SizedBox(
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
                  Color levelColor;
                  if (level == "error") {
                    levelColor = Colors.redAccent;
                  } else if (level == "warn") {
                    levelColor = Colors.yellowAccent;
                  } else {
                    levelColor = Theme.of(context).dialogBackgroundColor;
                  }
                  return ListTile(
                      title: Text("[$formatted] #$requestID"),
                      subtitle: Text(message),
                      tileColor: levelColor);
                },
              ),
            ));
      },
    );
  }

  void toggleSourceView() => setState(() {
        viewingSource = !viewingSource;
      });

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
        setState(() {
          _scrollController = ScrollController(initialScrollOffset: 0);
          contentData = parsedData;
        });
      }
    }
  }

  Future<bool> handleBack() async {
    if (_historyIndex > 0) {
      _handleHistory(-1);
      return false;
    } else {
      return true;
    }
  }

  Future<bool> handleForward() async {
    if (_historyIndex < (_history.length - 1)) {
      _handleHistory(1);
      return false;
    } else {
      return true;
    }
  }

  void _handleHistory(int dir) async {
    _requestID += 1;

    setState(() {
      var oldPosition = _scrollController.position.pixels;
      _history[_historyIndex].scrollPosition = oldPosition;
      _historyIndex += dir;
      var entry = _history[_historyIndex];

      resetResponse(entry.location);
      if (entry.contentData != null) {
        _scrollController =
            ScrollController(initialScrollOffset: entry.scrollPosition);
        contentData = entry.contentData;
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
    Widget? bottomBar;
    if (isIos) {
      bottomBar = BottomAppBar(
          color: Theme.of(context).cardColor,
          child: ButtonBar(
            children: [
              TextButton(
                  onPressed: _historyIndex == 0
                      ? null
                      : () {
                          handleBack();
                        },
                  child: const Icon(Icons.keyboard_arrow_left, size: 30)),
              TextButton(
                  onPressed: _historyIndex == (_history.length - 1)
                      ? null
                      : () {
                          handleForward();
                        },
                  child: const Icon(Icons.keyboard_arrow_right, size: 30))
            ],
            alignment: MainAxisAlignment.spaceBetween,
          ));
    }

    var content = Content(
      currentUri: uri,
      contentData: contentData,
      viewSource: viewingSource &&
          contentData != null &&
          contentData!.bytesBuilder != null &&
          contentData!.mode == Modes.gem,
      onLocation: onLocation,
      onNewTab: widget.onNewTab,
    );
    var contentWidget = GestureDetector(
        onTapDown: (_) {
          _focusNode.unfocus();
        },
        child: SingleChildScrollView(
            key: ObjectKey(contentData),
            controller: _scrollController,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 17, 20),
              child: DefaultTextStyle(
                  child: content,
                  style: TextStyle(
                      inherit: true,
                      fontSize: baseFontSize,
                      color: Theme.of(context).textTheme.bodyText1!.color)),
            )));

    List<Widget> actions = [];
    if (_showActions) {
      actions = [
        IconButton(
          icon: SizedBox(
              width: 23,
              height: 23,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(width: 2, color: Colors.black),
                      borderRadius: const BorderRadius.all(Radius.circular(3))),
                  child: Align(
                      alignment: Alignment.center,
                      child: Text("${appKey.currentState!.tabs.length}",
                          textScaleFactor: 1.15,
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontFamily: "DejaVu Sans Mono",
                              fontSize: 13))))),
          onPressed: () => widget.onNewTab(null, true),
        ),
        TabMenuWidget(
            tab: this,
            onBookmark: widget.onBookmark,
            onFeed: widget.onFeed,
            onLocation: onLocation,
            onForward: handleForward),
      ];
    }

    return Scaffold(
        backgroundColor:
            (contentData != null && contentData!.mode == Modes.error)
                ? Colors.deepOrange
                : Theme.of(context).canvasColor,
        bottomNavigationBar: bottomBar,
        appBar: AppBar(
            backgroundColor: Colors.orange,
            title: AddressBar(
              focusNode: _focusNode,
              controller: _controller,
              onLocation: onLocation,
              loading: _loading,
            ),
            actions: actions),
        body: IgnorePointer(
          child: contentWidget,
          ignoring: _loading,
        ));
  }
}
