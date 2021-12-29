// ignore: unused_import
import 'dart:developer';

import 'package:deedum/app_state.dart';
import 'package:deedum/browser_tab/client_cert.dart';
import 'package:deedum/browser_tab/search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:string_validator/string_validator.dart' as validator;

class AddressBar2 extends ConsumerWidget {
  const AddressBar2({
    Key? key,
    required this.controller,
    required this.focusNode,
  }) : super(key: key);

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    SchedulerBinding.instance?.addPostFrameCallback((_) {
      if (appState.currentShouldCertDialog()) {
        showCertDialog(context, appState);
      } else if (appState.currentShouldSearchDialog()) {
        showSearchDialog(context, appState);
      }
    });
    ref.listen(appStateProvider, (AppState? previous, AppState next) {
      if (previous?.currentUri() == next.currentUri()) {
        controller.text = next.currentUri().toString();
      }
    });
    var background = Colors.orange[300];
    var identity = appState.currentIdentity();
    if (appState.currentLoading()) {
      background = Colors.green[300];
    } else if (identity != null) {
      background = Colors.blue[300];
    }

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
                color: background,
                borderRadius: const BorderRadius.all(Radius.circular(5))),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              margin: const EdgeInsets.fromLTRB(0, 5, 0, 5),
              child: TextField(
                keyboardType: TextInputType.url,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                ),
                focusNode: focusNode,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
                controller: controller,
                onSubmitted: (value) async {
                  Uri newURL = Uri.tryParse(value)!;
                  final validated = (newURL.scheme == "gemini" ||
                      newURL.scheme == "about" ||
                      validator.isURL(value, {
                        "protocols": ['gemini'],
                        "require_tld": true,
                        "require_protocol": false,
                        "allow_underscores": true
                      }));
                  if (validated) {
                    if (!newURL.hasScheme) {
                      newURL = Uri.parse("gemini://" + value);
                    }
                  } else {
                    String searchEngine = appState.settings["search"];

                    newURL = Uri.parse(searchEngine);
                    newURL = newURL.replace(query: value);
                  }
                  appState.onLocation(newURL);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> showSearchDialog(BuildContext context, AppState appState) async {
    var location = appState.currentUri()!;
    var newLocation = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return SearchAlert(prompt: appState.currentMeta()!, uri: location);
        });
    if (newLocation != null) {
      appState.onLocation(newLocation);
    }
    return;
  }

  Future<void> showCertDialog(BuildContext context, AppState appState) async {
    var location = appState.currentUri()!;
    var selectedIdentity = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return ClientCertAlert(
              prompt: appState.currentMeta()!, uri: location);
        });
    if (selectedIdentity != null) {
      appState.onIdentity(selectedIdentity, location);
      appState.onLocation(location);
    }
    return;
  }
}
