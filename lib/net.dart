import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:deedum/shared.dart';
import 'package:url_launcher/url_launcher.dart';

List<String> bytesToLines(ContentType contentType, List<int> bytes) {
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

  return LineSplitter.split(rest).toList();
}

void onURI(String currentLink, String link, void Function(Uri, ContentData) handleContent, void Function() handleLoad,
    void Function() handleDone, List<String> redirects) async {
  handleLoad();

  var uri = Uri.parse(link);
  if (!uri.hasScheme) {
    uri = Uri.parse(currentLink).resolve(link);
  }

  if (uri.scheme != "gemini") {
    if (await canLaunch(uri.toString())) {
      launch(uri.toString());
    } else {
      log("Unhandled scheme ${uri.scheme}");
    }
    handleDone();
    return;
  }

  SecureSocket.connect(uri.host, uri.hasPort ? uri.port : 1965, timeout: Duration(seconds: 5),
      onBadCertificate: (X509Certificate cert) {
    // TODO Pin
    return true;
  }).then((SecureSocket s) async {
    s.write(uri.toString() + "\r\n");
    s.flush();

    var x = s.timeout(Duration(milliseconds: 500), onTimeout: (x) {
      log("Timeout");
      x.close();
    });

    List<Uint8List> chunksList = await x.toList();
    List<int> chunks = <int>[];
    chunks = chunksList.fold(chunks, (chunks, element) => chunks + element);
    s.destroy();
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
      handleContent(uri, ContentData(mode: "error", content: ["NO RESPONSE", "--------------"]));
    } else if (m == null) {
      Iterable<String> content = LineSplitter.split(Utf8Decoder(allowMalformed: true).convert(chunks));
      handleContent(
          uri, ContentData(mode: "error", content: ["INVALID RESPONSE", "--------------", content.join("\n")]));
    } else if (meta.length > 1024) {
      Iterable<String> content = LineSplitter.split(Utf8Decoder(allowMalformed: true).convert(chunks));
      handleContent(uri, ContentData(mode: "error", content: ["META TOO LONG", "--------------", content.join("\n")]));
    } else if (status >= 10 && status < 20) {
      handleContent(uri, ContentData(mode: "search", content: [meta]));
    } else if (status >= 20 && status < 30) {
      var bytes = chunks.sublist(endofline + 1);
      var contentType = ContentType.parse(meta);

      if (contentType.mimeType == "text/gemini") {
        var lines = bytesToLines(contentType, bytes);
        handleContent(uri, ContentData(content: lines, mode: "content"));
      } else if (contentType.mimeType.startsWith("text/")) {
        var lines = bytesToLines(contentType, bytes);
        handleContent(uri, ContentData(content: lines, mode: "plain"));
      } else if (contentType.mimeType.startsWith("image/")) {
        handleContent(uri, ContentData(bytes: Uint8List.fromList(bytes), mode: "image"));
      } else {
        handleContent(uri, ContentData(bytes: Uint8List.fromList(bytes), mode: "binary"));
      }
    } else if (status >= 30 && status < 40) {
      if (redirects.contains(meta) || redirects.length >= 5) {
        handleContent(
            Uri.parse(meta), ContentData(mode: "error", content: ["REDIRECT LOOP", "--------------"] + redirects));
      } else {
        redirects.add(meta);
        onURI(currentLink, meta, handleContent, handleLoad, handleDone, redirects);
      }
    } else {
      handleContent(uri, ContentData(mode: "error", content: ["UNHANDLED STATUS", "--------------", statusMeta]));
    }
  }).catchError((e) {
    handleContent(uri, ContentData(mode: "error", content: ["INTERNAL EXCEPTION", "--------------", e.message]));
    log("TOP ERROR");
    log(e.toString());
  }).whenComplete(() {
    log("Done");
    handleDone();
  });
}
