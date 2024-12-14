// ignore: unused_import
import 'dart:developer';
import 'dart:typed_data';

import 'package:qr/qr.dart';

import 'package:sqflite/sqlite_api.dart';

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
const baseFontSize = 16.0;

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

  T? firstOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}

String? trimToNull(String? s) {
  if (s == null) {
    return null;
  } else if (s.trim().isEmpty) {
    return null;
  }
  return s;
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
  final qrImage = QrImage(qrCode);

  var result = "";
  for (int x = 0; x < qrImage.moduleCount; x++) {
    for (int y = 0; y < qrImage.moduleCount; y++) {
      if (qrImage.isDark(y, x)) {
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

Uri? parentPath(Uri uri) {
  List<String> segments = List.from(uri.pathSegments);
  if (segments.isNotEmpty) {
    var last = segments.removeLast();
    if (last == "") {
      segments.removeLast();
    }
    var newUri = uri.replace(pathSegments: segments);
    newUri = newUri.replace(path: newUri.path + "/");
    return newUri;
  }
}
