import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'dart:typed_data';

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
  StreamController<List<int>>? streamController;

  final List<String> lines = [];
  Uri? loadedUri;

  ContentData() {
    static = null;
    bytesBuilder = BytesBuilder(copy: false);
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
    var fallback = static != null ? static! : meta!;
    if (lines.isNotEmpty) {
      return lines.firstWhere((element) => element.trim().isNotEmpty,
          orElse: () => fallback);
    }
    return fallback;
  }

  String? source() {
    if (bytesBuilder != null) {
      return contentTypeDecoder().convert(bytesBuilder!.toBytes());
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

  void upsertToByteStream(Uint8List newBytes) {
    if (streamController == null) {
      streamController = StreamController<List<int>>();
      var lineStream = streamController?.stream
          .transform(contentTypeDecoder())
          .transform(const LineSplitter());
      lineStream?.listen((event) {
        lines.add(event);
      });
    }

    streamController!.sink.add(newBytes);
  }

  Converter<List<int>, String> contentTypeDecoder() {
    String? charset = contentType?.charset;
    Converter<List<int>, String> decoder;
    if (charset == "iso-8859-1") {
      decoder = const Latin1Decoder(allowInvalid: true);
    } else if (charset == "us-ascii") {
      decoder = const AsciiDecoder(allowInvalid: true);
    } else {
      decoder = const Utf8Decoder(allowMalformed: true);
    }
    return decoder;
  }
}
