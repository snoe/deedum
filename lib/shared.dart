import 'dart:async';
import 'dart:convert';
// ignore: unused_import
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
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

enum Modes {
  loading,
  error,
  gem,
  plain,
  image,
  binary,
  redirect,
  search,
  clientCert
}

class ContentData {
  late final int? status;
  late final String? meta;
  late final int? bodyIndex;
  late final ContentType? contentType;
  Modes mode = Modes.loading;
  String? static;
  BytesBuilder? bytesBuilder;
  late final StreamController<List<int>>? streamController;

  final List<String> lines = [];

  ContentData() {
    static = null;
    bytesBuilder = BytesBuilder(copy: false);
    streamController = StreamController<List<int>>();
    var lineStream = streamController?.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    lineStream?.listen((event) {
      lines.add(event);
    });
  }
  ContentData.error(this.static) {
    mode = Modes.error;
    bytesBuilder = null;
    streamController = null;
  }
  ContentData.gem(this.static) {
    mode = Modes.gem;
    bytesBuilder = null;
    streamController = null;
  }

  @override
  String toString() {
    return "ContentData<$status $meta>";
  }

  String summaryLine() {
    return lines.isNotEmpty && lines[0].trim().isNotEmpty
        ? lines[0]
        : static != null
            ? static!
            : meta!;
  }

  String? source() {
    if (bytesBuilder != null) {
      return bytesToString(contentType!, bytesBuilder!.toBytes());
    }
  }

  bool lineBased() {
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

class Identity {
  final String name;
  late final Uint8List cert;
  late final Uint8List privateKey;
  late final String certString;
  late final String privateKeyString;
  late final Map<String, String?> subject;
  final List<String> pages = [];

  Identity(this.name,
      {days = 365000,
      String? existingCertString,
      String? existingPrivateKeyString}) {
    AsymmetricKeyPair keyPair = CryptoUtils.generateRSAKeyPair();

    if (existingCertString != null) {
      certString = existingCertString;
      var x509 = X509Utils.x509CertificateFromPem(certString);

      subject = x509.subject.entries.fold({}, (accum, entry) {
        var a = ASN1ObjectIdentifier.fromIdentifierString(entry.key);
        if (entry.value != null && a.readableName != null) {
          accum[a.readableName!] = entry.value;
        }
        return accum;
      });
    } else {
      Map<String, String> newSubject = {'commonName': name};
      subject = newSubject;
      var x = X509Utils.generateRsaCsrPem(
          newSubject,
          keyPair.privateKey as RSAPrivateKey,
          keyPair.publicKey as RSAPublicKey);

      certString =
          X509Utils.generateSelfSignedCertificate(keyPair.privateKey, x, 100);
    }

    if (existingPrivateKeyString != null) {
      privateKeyString = existingPrivateKeyString;
      CryptoUtils.rsaPrivateKeyFromPem(privateKeyString);
    } else {
      privateKeyString = CryptoUtils.encodeRSAPrivateKeyToPem(
          keyPair.privateKey as RSAPrivateKey);
    }
    var utf8encoder = const Utf8Encoder();
    cert = utf8encoder.convert(certString);
    privateKey = utf8encoder.convert(privateKeyString);
  }

  static bool validateCert(certString) {
    try {
      X509Utils.x509CertificateFromPem(certString);
    } catch (e) {
      return false;
    }
    return true;
  }

  static bool validatePrivateKey(privateKeyString) {
    try {
      CryptoUtils.rsaPrivateKeyFromPem(privateKeyString);
    } catch (e) {
      return false;
    }
    return true;
  }

  addPage(String page) {
    pages.add(page);
  }

  matches(Uri uri) {
    var check = uri.toString();
    return pages.any((page) {
      return check == page ||
          check.startsWith(page.endsWith("/") ? page : page + "/");
    });
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
