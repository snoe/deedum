import 'dart:convert';
import 'dart:typed_data';

import 'package:qr/qr.dart';
import 'dart:math' as math;

class ContentData {
  final Uint8List _bytes;
  final String _content;
  final String _mode;
  ContentData({String content, String mode, Uint8List bytes})
      : _content = content,
        _mode = mode,
        _bytes = bytes;

  Uint8List get bytes => _bytes;
  String get mode => _mode;
  String get content => _content;
  @override
  String toString() {
    var preview = content == null ? "" : content;
    return "ContentData<$mode, ${preview.substring(0, math.min(10, preview.length))}>";
  }
}

class Feed {
  final String title;
  final Uri uri;
  final List<dynamic> links;
  final String content;
  final String lastFetchedAt;

  Feed(this.uri, this.title, this.links, this.content, this.lastFetchedAt);

  @override
  String toString() {
    return "Feed<$uri, $title, $links>";
  }
}

String toSchemelessString(Uri uri) {
  var uriString;
  if (uri != null) {
    if (!uri.hasScheme) {
      uriString = uri.toString();
    } else if (uri.scheme == "gemini") {
      uriString = uri.toString().replaceFirst(RegExp(r"^gemini://"), "");
    } else {
      uriString = uri.toString();
    }
  }
  return uriString;
}

Uri toSchemeUri(String uriString) {
  var u = Uri.tryParse(uriString);
  if (!u.hasScheme) {
    u = Uri.tryParse("gemini://" + uriString);
  } else if (u.scheme != "gemini") {
    u = null;
  }
  return u;
}

Uri resolveLink(Uri currentUri, String link) {
  var location = Uri.tryParse(link);
  if (!location.hasScheme) {
    location = currentUri.resolve(link);
  }
  return location;
}

double get padding => 25.0;

extension CollectionUtil<T> on Iterable<T> {
  Iterable<E> mapIndexed<E, T>(E Function(int index, T item) transform) sync* {
    var index = 0;

    for (final item in this) {
      yield transform(index, item as T);
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

var database;
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
  final qrCode = new QrCode.fromUint8List(
      data: der, errorCorrectLevel: QrErrorCorrectLevel.L);
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
