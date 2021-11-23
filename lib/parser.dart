import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';

import 'shared.dart';

const allowMalformedUtf8Decoder = Utf8Decoder(allowMalformed: true);
const allowInvalidLatinDecoder = Latin1Decoder(allowInvalid: true);

String bytesToString(ContentType contentType, List<int> bytes) {
  String rest;
  if (contentType.charset == null ||
      contentType.charset!.isEmpty ||
      contentType.charset == "utf-8") {
    rest = allowMalformedUtf8Decoder.convert(bytes);
  } else if (contentType.charset == "iso-8859-1") {
    rest = allowInvalidLatinDecoder.convert(bytes);
  } else if (contentType.charset == "us-ascii") {
    rest = allowInvalidLatinDecoder.convert(bytes);
  } else {
    rest = allowMalformedUtf8Decoder.convert(bytes);
  }

  return rest;
}

ContentData? parse(List<Uint8List?> chunksList) {
  List<int> chunks = <int>[];
  chunks = chunksList.fold(chunks, (chunks, element) {
    return chunks + element!;
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
  late int status;
  String? meta;

  var statusMeta = allowMalformedUtf8Decoder.convert(statusBytes);

  var m = RegExp(r'^(\d\d)\s(.+)$').firstMatch(statusMeta);
  if (m != null) {
    status = int.parse(m.group(1)!);
    meta = m.group(2);
  }

  ContentData? result;

  if (statusMeta.isEmpty) {
    result = null;
  } else if (m == null) {
    String content = allowMalformedUtf8Decoder.convert(chunks);
    result = ContentData(
        mode: "error",
        content: "INVALID RESPONSE\n--------------\n" +
            content +
            "\n--------------");
  } else if (meta!.length > 1024) {
    String content = allowMalformedUtf8Decoder.convert(chunks);
    result = ContentData(
        mode: "error",
        content:
            "META TOO LONG\n--------------\n" + content + "\n--------------");
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
    String content = allowMalformedUtf8Decoder.convert(chunks);
    result = ContentData(
        mode: "error",
        content: "UNHANDLED STATUS\n--------------\n" +
            content +
            "\n--------------");
  }
  return result;
}

void addToGroup(r, String type, String line) {
  if (r["groups"].isNotEmpty && r["groups"].last["type"] == type) {
    var group = r["groups"].removeLast();
    group["data"] += "\n" + line;
    group["maxLine"] = math.max(line.length, (group["maxLine"] as int));
    r["groups"].add(group);
  } else {
    r["groups"].add({"type": type, "data": line, "maxLine": line.length});
  }
}

List<dynamic>? analyze(content, {alwaysPre = false}) {
  var lineInfo = LineSplitter.split(content)
      .fold({"groups": [], "parse?": true}, (dynamic r, line) {
    if (!alwaysPre && line.startsWith("```")) {
      r["parse?"] = !r["parse?"];
    } else if (alwaysPre || !r["parse?"]) {
      addToGroup(r, "pre", line);
    } else if (line.startsWith(">")) {
      addToGroup(r, "quote", line.substring(1));
    } else if (line.startsWith("#")) {
      var m = RegExp(r'^(#*)\s*(.*)$').firstMatch(line)!;
      var hashCount = math.min(m.group(1)!.length, 3);
      r["groups"]
          .add({"type": "header", "data": m.group(2), "size": hashCount});
    } else if (line.startsWith("=>")) {
      var m = RegExp(r'^=>\s*(\S+)\s*(.*)$').firstMatch(line);
      if (m != null) {
        var link = m.group(1);
        var rest = m.group(2)!.trim();
        var title = rest.isEmpty ? link : rest;
        r["groups"].add({"type": "link", "link": link, "data": title});
      }
    } else if (line.startsWith("* ")) {
      r["groups"].add({"type": "list", "data": line.substring(2)});
    } else {
      addToGroup(r, "line", line);
    }
    return r;
  });
  List? groups = lineInfo["groups"];
  return groups;
}
