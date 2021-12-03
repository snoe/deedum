import 'dart:convert';
// ignore: unused_import
import 'dart:developer';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';

import 'shared.dart';

void parse(ContentData parsedData, Uint8List newBytes) {
  parsedData.bytesBuilder!.add(newBytes);

  if (parsedData.mode == Modes.loading) {
    int status;
    String? meta;
    int? prevChar;
    var endofline = 0;

    var bytes = parsedData.bytesBuilder!.toBytes();
    for (var byteIndex = 0; byteIndex < bytes.length; byteIndex++) {
      if (prevChar == 13 && bytes[byteIndex] == 10) {
        endofline = byteIndex;
        break;
      } else {
        prevChar = bytes[byteIndex];
      }
    }
    if (endofline == 0) {
      return;
    }

    var statusBytes = Uint8List.sublistView(bytes, 0, endofline - 1);
    if (statusBytes.isEmpty) {
      return;
    }

    var statusMeta = allowMalformedUtf8Decoder.convert(statusBytes);
    if (statusMeta.isEmpty) {
      return;
    }

    var m = RegExp(r'^(\d\d)\s(.+)$').firstMatch(statusMeta);
    if (m == null) {
      parsedData.mode = Modes.error;
      parsedData.static = "INVALID RESPONSE";
      return;
    }

    status = int.parse(m.group(1)!);
    meta = m.group(2);

    if (meta!.length > 1024) {
      parsedData.mode = Modes.error;
      parsedData.static = "META TOO LONG";
      return;
    }

    if (status < 10 || status >= 40) {
      parsedData.mode = Modes.error;
      parsedData.static = "UNHANDLED STATUS";
      return;
    }

    parsedData.status = status;
    parsedData.meta = meta;
    parsedData.bodyIndex = endofline + 1;
    if (status >= 10 && status < 20) {
      parsedData.mode = Modes.search;
    } else if (status >= 20 && status < 30) {
      parsedData.contentType = ContentType.parse(meta);

      if (parsedData.contentType!.mimeType == "text/gemini") {
        parsedData.mode = Modes.gem;
      } else if (parsedData.contentType!.mimeType.startsWith("text/")) {
        parsedData.mode = Modes.plain;
      } else if (parsedData.contentType!.mimeType.startsWith("image/")) {
        parsedData.mode = Modes.image;
      } else {
        parsedData.mode = Modes.binary;
      }
    } else if (status >= 30 && status < 40) {
      parsedData.mode = Modes.redirect;
    }
  }
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
