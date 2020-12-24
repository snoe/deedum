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

double get padding => 25.0;

extension CollectionUtil<T> on Iterable<T> {
  Iterable<E> mapIndexed<E, T>(E Function(int index, T item) transform) sync* {
    var index = 0;

    for (final item in this) {
      yield transform(index, item as T);
      index++;
    }
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
  final qrCode = new QrCode.fromUint8List(data: der, errorCorrectLevel: QrErrorCorrectLevel.L);
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
