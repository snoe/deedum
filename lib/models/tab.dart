import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:deedum/models/app_state.dart';
import 'package:deedum/models/content_data.dart';
import 'package:deedum/models/feed.dart';
import 'package:deedum/models/identity.dart';
import 'package:deedum/net.dart';
import 'package:deedum/parser.dart';
import 'package:flutter/material.dart';

class Tab {
  int ident;
  bool loading = false;
  Uri? uri;
  ContentData? parsedData;
  ContentData? contentData;

  List<HistoryEntry> history = [];

  int historyIndex = -1;
  int _requestID = 1;

  List _redirects = [];
  List logs = [];
  bool viewingSource = false;

  void Function(String uriString) addRecent;

  void Function() notifyListeners;
  ScrollController scrollController = ScrollController(initialScrollOffset: 0);

  Tab(this.ident, initialLocation, this.addRecent, this.notifyListeners,
      identities, feeds) {
    if (initialLocation != null) {
      uri = Uri.tryParse(initialLocation!)!;
      onLocation(uri!, identities, feeds);
    } else {
      uri = null;
    }
  }

  bool shouldCertDialog() {
    return loading == false && parsedData?.mode == Modes.clientCert;
  }

  bool shouldSearchDialog() {
    return loading == false && parsedData?.mode == Modes.search;
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
      if (parsedData!.lineBased()) {
        contentData = parsedData;
        contentData?.loadedUri = location;
      }
    }
    notifyListeners();
  }

  void _handleLog(String level, String message, int requestID) async {
    log(message);
    logs = logs.sublist(math.max(logs.length - 100, 0), logs.length);
    logs.add([level, DateTime.now(), requestID, message]);

    notifyListeners();
  }

  void _handleDone(Uri location, bool timeout, bool badScheme,
      List<Identity> identities, List<Feed?> feeds, int requestID) async {
    if (requestID != _requestID) {
      return;
    }
    loading = false;
    await parsedData?.streamController?.close();
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
        history[historyIndex].location = newLocation;
        onURI(newLocation, _handleBytes, _handleDone, _handleLog, identities,
            feeds, _requestID);
      } else {
        if (parsedData?.mode == Modes.loading) {
          var allLogs = List.from(logs);
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
    contentData?.loadedUri = location;
    notifyListeners();
  }

  void resetResponse(Uri location, {bool redirect = false}) {
    parsedData = ContentData();
    uri = location;
    if (!redirect) {
      _redirects = [];
      addRecent(location.toString());
    }

    notifyListeners();
  }

  void onLocation(Uri location, List<Identity> identities, List<Feed?> feeds) {
    if (historyIndex != -1) {
      var oldPosition = scrollController.position.pixels;
      history[historyIndex].scrollPosition = oldPosition;
      scrollController = ScrollController(initialScrollOffset: 0);
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
