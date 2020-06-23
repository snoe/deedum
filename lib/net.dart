import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:deedum/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

String bytesToString(ContentType contentType, List<int> bytes) {
  var rest;
  if (contentType.charset == null || contentType.charset.isEmpty || contentType.charset == "utf-8") {
    rest = Utf8Decoder(allowMalformed: true).convert(bytes);
  } else if (contentType.charset == "iso-8859-1") {
    rest = Latin1Decoder(allowInvalid: true).convert(bytes);
  } else if (contentType.charset == "us-ascii") {
    rest = Latin1Decoder(allowInvalid: true).convert(bytes);
  } else {
    rest = Utf8Decoder(allowMalformed: true).convert(bytes);
  }

  return rest;
}

Future<ContentData> homepageContent() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> bookmarks = (prefs.getStringList('bookmarks') ?? []);
  var intro = [
    "```",
    "██████╗ ███████╗███████╗██████╗ ██╗   ██╗███╗   ███╗",
    "██╔══██╗██╔════╝██╔════╝██╔══██╗██║   ██║████╗ ████║",
    "██║  ██║█████╗  █████╗  ██║  ██║██║   ██║██╔████╔██║",
    "██║  ██║██╔══╝  ██╔══╝  ██║  ██║██║   ██║██║╚██╔╝██║",
    "██████╔╝███████╗███████╗██████╔╝╚██████╔╝██║ ╚═╝ ██║",
    "╚═════╝ ╚══════╝╚══════╝╚═════╝  ╚═════╝ ╚═╝     ╚═╝",
    "```",
    "Welcome to the Geminiverse."
  ];
  var bookmarkLines = ["# Bookmarks"] +
      bookmarks.map((s) {
        return "=> $s";
      }).toList();

  List<String> recent = (prefs.getStringList('recent') ?? []);
  var recentLines = ["# Recent"] +
      recent.map((s) {
        return "=> $s";
      }).toList();
  var lines = intro +
      [
        "# Links",
        "=> gemini://gemini.circumlunar.space/ Project Gemini",
        "=> gemini://typed-hole.org/ Typed Hole",
        "=> gemini://gus.guru/ Gemini Universal Search",
      ] +
      bookmarkLines +
      recentLines;

  return ContentData(content: lines.join("\n"), mode: "content");
}

void onURI(Uri uri, void Function(Uri, ContentData) handleContent, void Function() handleLoad,
    void Function() handleDone, List<String> redirects) async {
  handleLoad();

  if (uri.scheme == "about") {
    var homepage = await homepageContent();
    handleContent(uri, homepage);
    handleDone();
    return;
  } else if (uri.scheme != "gemini") {
    if (await canLaunch(uri.toString())) {
      launch(uri.toString());
    } else {
      log("Unhandled scheme ${uri.scheme}");
    }
    handleDone();
    return;
  }
  List<Uint8List> chunksList;
  bool timeout;
  try {
    var result = await fetch(uri, true);
    if (!result[0] && (result[1] as List).isEmpty) {
      result = await fetch(uri, false);
    }

    timeout = result[0];
    chunksList = result[1];
  } catch (e) {
    handleContent(uri, ContentData(mode: "error", content: "INTERNAL EXCEPTION\n--------------\n" + e.message));
    handleDone();
    return;
  }

  List<int> chunks = <int>[];
  chunks = chunksList.fold(chunks, (chunks, element) => chunks + element);
  var endofline = 1;
  for (; endofline < chunks.length; endofline++) {
    if (chunks[endofline - 1] == 13 && chunks[endofline] == 10) {
      break;
    }
  }
  var statusBytes = chunks.sublist(0, endofline - 1);
  var status;
  var meta;

  var statusMeta = Utf8Decoder(allowMalformed: true).convert(statusBytes);

  var m = RegExp(r'^(\d\d)\s(.+)$').firstMatch(statusMeta);
  if (m != null) {
    status = int.parse(m.group(1));
    meta = m.group(2);
  }

  if (statusMeta == null) {
    handleContent(uri, ContentData(mode: "error", content: "NO RESPONSE (timeout: $timeout)\n--------------"));
  } else if (m == null) {
    String content = Utf8Decoder(allowMalformed: true).convert(chunks);
    handleContent(
        uri,
        ContentData(
            mode: "error",
            content: "INVALID RESPONSE (timeout: $timeout)\n$statusMeta\n--------------\n" + content));
  } else if (meta.length > 1024) {
    String content = Utf8Decoder(allowMalformed: true).convert(chunks);
    handleContent(uri, ContentData(mode: "error", content: "META TOO LONG\n--------------\n" + content));
  } else if (status >= 10 && status < 20) {
    handleContent(uri, ContentData(mode: "search", content: meta));
  } else if (status >= 20 && status < 30) {
    var bytes = chunks.sublist(endofline + 1);
    var contentType = ContentType.parse(meta);

    if (contentType.mimeType == "text/gemini") {
      var content = bytesToString(contentType, bytes);
      handleContent(uri, ContentData(content: content, mode: "content"));
    } else if (contentType.mimeType.startsWith("text/")) {
      var content = bytesToString(contentType, bytes);
      handleContent(uri, ContentData(content: content, mode: "plain"));
    } else if (contentType.mimeType.startsWith("image/")) {
      handleContent(uri, ContentData(bytes: Uint8List.fromList(bytes), mode: "image"));
    } else {
      handleContent(uri, ContentData(bytes: Uint8List.fromList(bytes), mode: "binary"));
    }
  } else if (status >= 30 && status < 40) {
    if (redirects.contains(meta) || redirects.length >= 5) {
      handleContent(
          Uri.parse(meta), ContentData(mode: "error", content: "REDIRECT LOOP\n--------------\n" + redirects.join("\n")));
    } else {
      redirects.add(meta);
      onURI(Uri.parse(meta), handleContent, handleLoad, handleDone, redirects);
    }
  } else {
    handleContent(uri, ContentData(mode: "error", content: "UNHANDLED STATUS\n--------------\n" + statusMeta));
  }

  handleDone();
}

Future<List<Object>> fetch(Uri uri, bool shutdown) async {
  return await RawSecureSocket.connect(uri.host, uri.hasPort ? uri.port : 1965, timeout: Duration(seconds: 5),
      onBadCertificate: (X509Certificate cert) {
       //log("bad");
    // TODO Pin
    return true;
  }).then((RawSecureSocket s) async {
    var chunksList = List<Uint8List>();
    var timeout = false;
    var writeBuffer = Utf8Encoder().convert(uri.toString() + "\r\n");

    var writeOffset = s.write(writeBuffer);

    var x = s.timeout(Duration(milliseconds: 1000), onTimeout: (x) {
      log("timeout");
      timeout = true;
      x.close();
    });

    await x.listen((event) {
      switch (event) {
        case RawSocketEvent.read:
          chunksList.add(s.read());
          break;
        case RawSocketEvent.write:
          if (shutdown && writeOffset == writeBuffer.length) {
            s.shutdown(SocketDirection.send);
          } else {
            writeOffset += s.write(writeBuffer, writeOffset);
          }
          break;
        case RawSocketEvent.readClosed:
          break;
        case RawSocketEvent.closed:
          break;
        default:
          throw "Unexpected event $event";
      }
    }).asFuture();
    s.close();
    return [timeout, chunksList];
  });
}
