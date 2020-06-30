import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:deedum/shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:deedum/main.dart';

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
  var lines = [
    "Welcome to the Geminiverse.",
    "",
    "```",
    "██████╗ ███████╗███████╗██████╗ ██╗   ██╗███╗   ███╗",
    "██╔══██╗██╔════╝██╔════╝██╔══██╗██║   ██║████╗ ████║",
    "██║  ██║█████╗  █████╗  ██║  ██║██║   ██║██╔████╔██║",
    "██║  ██║██╔══╝  ██╔══╝  ██║  ██║██║   ██║██║╚██╔╝██║",
    "██████╔╝███████╗███████╗██████╔╝╚██████╔╝██║ ╚═╝ ██║",
    "╚═════╝ ╚══════╝╚══════╝╚═════╝  ╚═════╝ ╚═╝     ╚═╝",
    "```",
    "# Links",
    "=> gemini://gemini.circumlunar.space/ Project Gemini",
    "=> gemini://gus.guru/ Gemini Universal Search",
    "=> gemini://wp.pitr.ca/en/Gemini Gemini Wikipedia Proxy"
  ];

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
  X509Certificate serverCert;
  try {
    var result = await fetch(uri, true);
    if (!result[0] && (result[1] as List).isEmpty) {
      result = await fetch(uri, false);
    }

    timeout = result[0];
    chunksList = ((result[1] as List) ?? []);
    chunksList.removeWhere((element) => element == null);
    serverCert = result[2];
  } catch (e) {
    handleContent(uri, ContentData(mode: "error", content: "INTERNAL EXCEPTION\n--------------\n" + e.message));
    handleDone();
    return;
  }

  final Database db = await database;
  var hostPort = "${uri.host}:${uri.port ?? 1965}";
  var ders = await db.rawQuery("select der from hosts where name = ?", [hostPort]);
  if (ders != null && ders.length == 1 && !listEquals(ders[0]["der"], serverCert.der)) {
    log(" ${serverCert.der.length} ${serverCert.der.runtimeType}");
    var value = await showDialog(
        barrierDismissible: false, // user must tap button!
        context: materialKey.currentContext,
        builder: (BuildContext context) {
          var size = MediaQuery.of(context).size;
          var length = math.min(size.height - 150, size.width - 200);

          return AlertDialog(
            title: Text("The server's certificate does not match."),
            content: SingleChildScrollView(
                child: Column(
              children: <Widget>[
                Text("You should confirm out-of-band that this is expected.\n"),
                SizedBox(
                    width: length,
                    height: length,
                    child: FittedBox(
                        fit: BoxFit.fill,
                        child: SelectableText(qrEncode(serverCert.der),
                            style: TextStyle(fontFamily: "DejaVu Sans Mono")))),
                Text([
                  "subject: ${serverCert.subject}",
                  "issuer: ${serverCert.issuer}",
                  "start: ${new DateFormat("y-M-d h:m").format(serverCert.startValidity)}",
                  "end: ${new DateFormat("y-M-d h:m").format(serverCert.endValidity)}"
                ].join("\n"))
              ],
            )),
            actions: <Widget>[
              FlatButton(
                child: Text('I accept the new certificate'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
              FlatButton(
                child: Text('Uh oh, this is unexpected', style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
            ],
          );
        });
    if (!value) {
      handleContent(
          uri,
          ContentData(
              mode: "error",
              content: "Trust on first use, certificate mismatch\n--------------\n" + base64Encode(serverCert.der)));
      handleDone();
      return;
    }
  }
  await db.rawInsert(
      "insert or replace into hosts (name, der, created_at) values (?,?,date('now'))", [hostPort, serverCert.der]);

  List<int> chunks = <int>[];
  chunks = chunksList.fold(chunks, (chunks, element) {
    return chunks + element;
  });
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
            mode: "error", content: "INVALID RESPONSE (timeout: $timeout)\n$statusMeta\n--------------\n" + content));
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
      handleContent(Uri.parse(meta),
          ContentData(mode: "error", content: "REDIRECT LOOP\n--------------\n" + redirects.join("\n")));
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
  var port = uri.hasPort ? uri.port : 1965;
  return await RawSecureSocket.connect(uri.host, port, timeout: Duration(seconds: 5),
      onBadCertificate: (X509Certificate cert) {
    return true;
  }).then((RawSecureSocket s) async {
    var chunksList = List<Uint8List>();
    var timeout = false;
    var writeBuffer = Utf8Encoder().convert(uri.toString() + "\r\n");

    var writeOffset = s.write(writeBuffer);
    var serverCert = s.peerCertificate;

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
    return [timeout, chunksList, serverCert];
  });
}
