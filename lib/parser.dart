import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'shared.dart';

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

ContentData parse(List<Uint8List> chunksList) {
  List<int> chunks = <int>[];
  chunks = chunksList.fold(chunks, (chunks, element) {
    return chunks + element;
  });

  if (chunks.isEmpty) {
    return null;
  }

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

  ContentData result;

  if (statusMeta == null) {
    result = null;
  } else if (m == null) {
    String content = Utf8Decoder(allowMalformed: true).convert(chunks);
    result = ContentData(mode: "error", content: "INVALID RESPONSE\n--------------\n" + content + "\n--------------");
  } else if (meta.length > 1024) {
    String content = Utf8Decoder(allowMalformed: true).convert(chunks);
    result = ContentData(mode: "error", content: "META TOO LONG\n--------------\n" + content + "\n--------------");
  } else if (status >= 10 && status < 20) {
    result = ContentData(mode: "search", content: meta);
  } else if (status >= 20 && status < 30) {
    if (chunks.length <= endofline) {
      result = ContentData(content: "", mode: "content");
    } else {
      var bytes = chunks.sublist(endofline + 1);
      var contentType = ContentType.parse(meta);

      if (contentType.mimeType == "text/gemini") {
        var content = bytesToString(contentType, bytes);
        result = ContentData(content: content, mode: "content");
      } else if (contentType.mimeType.startsWith("text/")) {
        var content = bytesToString(contentType, bytes);
        result = ContentData(content: content, mode: "plain");
      } else if (contentType.mimeType.startsWith("image/")) {
        result = ContentData(bytes: Uint8List.fromList(bytes), mode: "image");
      } else {
        result = ContentData(bytes: Uint8List.fromList(bytes), mode: "binary");
      }
    }
  } else if (status >= 30 && status < 40) {
    result = ContentData(content: meta, mode: "redirect");
  } else {
    String content = Utf8Decoder(allowMalformed: true).convert(chunks);
    result = ContentData(mode: "error", content: "UNHANDLED STATUS\n--------------\n" + content + "\n--------------");
  }
  return result;
}