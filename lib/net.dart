import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart';
import 'package:deedum/main.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:x509/x509.dart' as x;
import 'package:punycode/punycode.dart';


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

Future<void> handleCert(Uri uri, X509Certificate serverCert) async {
  var tofuBytes;
  try {
    ASN1Parser p = ASN1Parser(serverCert.der);
    ASN1Sequence o = (p.nextObject() as ASN1Sequence).elements[0];
    List<ASN1Object> elements = o.elements;
    if (elements.first.tag == 0xa0) {
      elements = elements.skip(1).toList();
    }
    var spkiObject = elements[5];
    x.SubjectPublicKeyInfo spki = x.SubjectPublicKeyInfo.fromAsn1(spkiObject);
    tofuBytes = spki.toAsn1().encodedBytes;
  } catch (e) {
    log("Failed to find spki $e");
    tofuBytes = serverCert.der;
  }

  var tofuHash = sha256.convert(tofuBytes).bytes;

  final Database db = await database;
  var hostPort = "${uri.host}:${uri.port ?? 1965}";
  var hashes =
      await db.rawQuery("select hash from hosts where name = ?", [hostPort]);
  if (hashes != null &&
      hashes.length == 1 &&
      !listEquals(hashes[0]["hash"], tofuHash)) {
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
                        child: SelectableText(qrEncode(tofuHash),
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
                child: Text('Uh oh, this is unexpected',
                    style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
            ],
          );
        });
    if (!value) {
      throw "Trust on first use, key mismatch";
      //handleContent( uri, ContentData( mode: "error", content: "Trust on first use, key mismatch\n--------------\n" + base64Encode(tofuHash)));
    }
  }
  await db.rawInsert(
      "insert or replace into hosts (name, hash, expires_at, created_at) values (?,?,?,date('now'))",
      [hostPort, tofuHash, serverCert.endValidity.toString()]);
}

String _punyEncodeUrl(String url) {
  // from https://github.com/Teifun2/nextcloud-cookbook-flutter
  String pattern = r"(?:\.|^)([^.]*?[^\x00-\x7F][^.]*?)(?:\.|$)";
  RegExp expression = new RegExp(pattern, caseSensitive: false);

  while (expression.hasMatch(url)) {
    String match = expression.firstMatch(url).group(1);
    url = url.replaceFirst(match, "xn--" + punycodeEncode(match));
  }

  return url;
}
Future<void> onURI(
    Uri uri,
    void Function(Uri, Uint8List, int) handleBytes,
    void Function(Uri, bool, bool, int) handleDone,
    void Function(String, String, int) handleLog,
    int requestID) async {

  bool timeout = false;
  bool opened = false;
  uri = uri.replace(host: _punyEncodeUrl(Uri.decodeFull(uri.host)));

  try {
    if (uri.toString() == "about:feeds") {
      var feeds = appKey.currentState.feeds;
      var linksByDate = feeds.fold<List>([], (accum, feed) {
        accum.addAll(feed.links);
        return accum;
      }).groupBy<String>((link) => link.entryDate);
      var dates = linksByDate.keys.toList()..sort((a,b) => b.compareTo(a));
      var entries = dates.map((date) {
        var links = linksByDate[date];
        var linksForDay = links
            .map((link) =>
                "=> ${link.entryUri} ${link.feedTitle}: ${link.entryTitle}")
            .join("\n");
        return "## $date\n$linksForDay";
      }).join("\n\n");
      var result = "20 text/gemini\r\n# Your feeds\n\n" + entries;
      handleBytes(uri, Utf8Encoder().convert(result), requestID);
    } else if (uri.scheme != "gemini") {
      if (await canLaunch(uri.toString())) {
        launch(uri.toString());
        opened = true;
      } else {
        handleLog("error", "Cannot find app to handle $uri", requestID);
      }
    } else {
      handleLog("info", "Connecting to $uri", requestID);
      var socket = await connect(uri);
      handleLog("info", "Connected to $uri", requestID);
      await handleCert(uri, socket.peerCertificate);
      handleLog("info", "Cert OK for $uri", requestID);
      timeout = await fetch(uri, socket, handleBytes, handleLog, requestID);
    }
  } catch (e) {
    handleLog("error", e.toString(), requestID);
  }
  handleDone(uri, timeout, opened, requestID);
}

Future<RawSecureSocket> connect(Uri uri) async {
  var port = uri.hasPort ? uri.port : 1965;
  return await RawSecureSocket.connect(uri.host, port,
      timeout: Duration(seconds: 10), onBadCertificate: (X509Certificate cert) {
    return true;
  });
}

Future<bool> fetch(
    Uri uri,
    RawSecureSocket socket,
    void Function(Uri, Uint8List, int) handleBytes,
    void Function(String, String, int) handleLog,
    int requestID) async {
  var timeout = false;
  var writeBuffer = Utf8Encoder().convert(uri.toString() + "\r\n");

  var writeOffset = socket.write(writeBuffer);

  var x = socket.timeout(Duration(seconds: 10), onTimeout: (x) {
    handleLog("info", "Timeout $uri", requestID);
    timeout = true;
    x.close();
  });

  await x.listen((event) {
    switch (event) {
      case RawSocketEvent.read:
        handleBytes(uri, socket.read(), requestID);
        break;
      case RawSocketEvent.write:
        if (writeOffset != writeBuffer.length) {
          writeOffset += socket.write(writeBuffer, writeOffset);
        } else {
          handleLog("info", "Request done $uri", requestID);
        }
        break;
      case RawSocketEvent.readClosed:
        socket.close();
        handleLog("info", "Read closed $uri", requestID);
        break;
      case RawSocketEvent.closed:
        socket.close();
        handleLog("info", "ReadSocket closed $uri", requestID);
        break;
      default:
        throw "Unexpected event $event";
    }
  }).asFuture();
  socket.close();

  return timeout;
}
