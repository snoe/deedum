import 'dart:convert';
// ignore: unused_import
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:qr/qr.dart';

import 'package:sqflite/sqlite_api.dart';

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

enum Modes { loading, error, gem, plain, image, binary, redirect, search }

class ContentData {
  late final int? status;
  late final String? meta;
  late final int? bodyIndex;
  late final ContentType? contentType;
  Modes mode = Modes.loading;
  String? static;
  BytesBuilder? bytesBuilder;

  ContentData(this.bytesBuilder) {
    static = null;
  }
  ContentData.error(this.static) {
    mode = Modes.error;
    bytesBuilder = null;
  }
  ContentData.gem(this.static) {
    mode = Modes.gem;
    bytesBuilder = null;
  }
  ContentData.plain(this.static) {
    mode = Modes.plain;
    bytesBuilder = null;
  }

  @override
  String toString() {
    return "ContentData<$status $meta>";
  }

  String? stringContent() {
    if (mode == Modes.gem || mode == Modes.plain) {
      if (static != null) {
        return static;
      } else {
        var body = this.body();
        return bytesToString(contentType!, body!);
      }
    }
  }

  String? source() {
    if (bytesBuilder != null) {
      return allowMalformedUtf8Decoder.convert(bytesBuilder!.toBytes());
    }
  }

  bool streamable() {
    return mode == Modes.gem || mode == Modes.plain;
  }

  Uint8List? body() {
    if (bytesBuilder != null && bodyIndex != null) {
      return Uint8List.sublistView(bytesBuilder!.toBytes(), bodyIndex!);
    }
  }
}

class Feed {
  final String? title;
  final Uri? uri;
  final List<dynamic>? links;
  final String? content;
  final String lastFetchedAt;

  Feed(this.uri, this.title, this.links, this.content, this.lastFetchedAt);

  @override
  String toString() {
    return "Feed<$uri, $title, $links>";
  }
}

String toSchemelessString(Uri? uri) {
  late String uriString;
  if (uri != null) {
    if (!uri.hasScheme) {
      uriString = uri.toString();
    } else if (uri.scheme == "gemini") {
      uriString = uri.toString().replaceFirst(RegExp(r"^gemini://"), "");
    } else {
      uriString = uri.toString();
    }
  }
  uriString = Uri.decodeFull(uriString);
  return uriString;
}

Uri? toSchemeUri(String uriString) {
  var u = Uri.tryParse(uriString)!;
  if (!u.hasScheme) {
    return Uri.tryParse("gemini://" + uriString)!;
  } else if (u.scheme != "gemini" && u.scheme != "about") {
    return null;
  }
  return u;
}

Uri resolveLink(Uri currentUri, String link) {
  var location = Uri.tryParse(link)!;
  if (!location.hasScheme) {
    location = currentUri.resolve(link);
  }
  return location;
}

double get padding => 25.0;

extension CollectionUtil<T> on Iterable<T> {
  Iterable<E> mapIndexed<E>(E Function(int index, T item) transform) sync* {
    var index = 0;

    for (final item in this) {
      yield transform(index, item);
      index++;
    }
  }

  Map<S, List<T>> groupBy<S>(S Function(T) key) {
    var map = <S, List<T>>{};
    for (var element in this) {
      (map[key(element)] ??= []).add(element);
    }
    return map;
  }
}

late Database database;
var emojiList = [
  "😀",
  "😃",
  "😄",
  "😁",
  "😆",
  "😅",
  "😂",
  "🤣",
  "😊",
  "😇",
  "🙂",
  "🙃",
  "😉",
  "😌",
  "😍",
  "😘",
  "😗",
  "😚",
  "😋",
  "😜",
  "😝",
  "😛",
  "🤑",
  "🤗",
  "🤓",
  "😎",
  "🤡",
  "🤠",
  "😏",
  "😒",
  "😞",
  "😔",
  "😟",
  "😕",
  "🙁",
  "☹️",
  "😣",
  "😖",
  "😫",
  "😩",
  "😤",
  "😠",
  "😡",
  "😶",
  "😐",
  "😑",
  "😯",
  "😦",
  "😧",
  "😮",
  "😲",
  "😵",
  "😳",
  "😱",
  "😨",
  "😰",
  "😢",
  "😥",
  "🤤",
  "😭",
  "😓",
  "😪",
  "😴",
  "🙄",
  "🤔",
  "🤥",
  "😬",
  "🤐",
  "🤢",
  "🤧",
  "😷",
  "🤒",
  "🤕",
  "😈",
  "👿",
  "👹",
  "👺",
  "💩",
  "👻",
  "💀",
  "☠️",
  "👽",
  "👾",
  "🤖",
  "🎃",
  "😺",
  "😸",
  "😹",
  "😻",
  "😼",
  "😽",
  "🙀",
  "😿",
  "😾",
  "👐",
  "🙌",
  "👏",
  "🙏",
  "🤝",
  "👍",
  "👎",
  "👊",
  "✊",
  "🤛",
  "🤜",
  "🤞",
  "✌️",
  "🤘",
  "👌",
  "👈",
  "👉",
  "👆",
  "👇",
  "☝️",
  "✋",
  "🤚",
  "🖐",
  "🖖",
  "👋",
  "🤙",
  "💪",
  "🖕",
  "✍️",
  "🤳",
  "💅",
  "🖖",
  "💄",
  "💋",
  "👄",
  "👅",
  "👂",
  "👃",
  "👣",
  "👁",
  "👀",
  "🗣",
  "👤",
  "👥",
  "👶",
  "👦",
  "👧",
  "👨",
  "👩",
  "👱"
];

String emojiEncode(String base64String) {
  return base64String.codeUnits.map((e) => emojiList[e]).join("");
}

String qrEncode(Uint8List der) {
  final qrCode =
      QrCode.fromUint8List(data: der, errorCorrectLevel: QrErrorCorrectLevel.L);
  qrCode.make();

  var result = "";
  for (int x = 0; x < qrCode.moduleCount; x++) {
    for (int y = 0; y < qrCode.moduleCount; y++) {
      if (qrCode.isDark(y, x)) {
        result += "█";
        // render a dark square on the canvas
      } else {
        result += " ";
      }
    }
    result += "\n";
  }
  return result;
}
