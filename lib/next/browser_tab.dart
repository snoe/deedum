// ignore: unused_import
import 'dart:developer';

import 'package:deedum/models/app_state.dart';
import 'package:deedum/content.dart';
import 'package:deedum/models/content_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BrowserTab extends ConsumerWidget {
  const BrowserTab(
      {Key? key,
      required this.ident,
      required this.scrollController,
      required this.focusNode})
      : super(key: key);

  final int ident;
  final ScrollController scrollController;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var appState = ref.watch(appStateProvider);
    var tab = appState.tabByIdent(ident);
    var content = Content(
      contentData: tab.contentData,
      viewSource: tab.viewingSource &&
          tab.contentData != null &&
          tab.contentData!.bytesBuilder != null &&
          tab.contentData!.mode == Modes.gem,
      onLocation: appState.onLocation,
      onNewTab: appState.onNewTab,
    );

    return GestureDetector(
        onTapDown: (_) {
          focusNode.unfocus();
        },
        child: SingleChildScrollView(
            key: ObjectKey(tab.contentData),
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 17, 20),
              child: DefaultTextStyle(
                  child: content,
                  style: TextStyle(
                      inherit: true,
                      fontSize: baseFontSize,
                      color: Theme.of(context).textTheme.bodyText1!.color)),
            )));
  }
}
