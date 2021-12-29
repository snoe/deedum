import 'package:deedum/app_state.dart';
import 'package:deedum/directory/directory_element.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Settings extends DirectoryElement {
  static final homepageKey = GlobalKey<FormState>();

  const Settings({
    Key? key,
  }) : super(key: key);

  @override
  String get title => [
        "███████╗███████╗████████╗████████╗██╗███╗   ██╗ ██████╗ ███████╗",
        "██╔════╝██╔════╝╚══██╔══╝╚══██╔══╝██║████╗  ██║██╔════╝ ██╔════╝",
        "███████╗█████╗     ██║      ██║   ██║██╔██╗ ██║██║  ███╗███████╗",
        "╚════██║██╔══╝     ██║      ██║   ██║██║╚██╗██║██║   ██║╚════██║",
        "███████║███████╗   ██║      ██║   ██║██║ ╚████║╚██████╔╝███████║",
        "╚══════╝╚══════╝   ╚═╝      ╚═╝   ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝"
      ].join("\n");

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var appState = ref.watch(appStateProvider);
    var children = [
      Padding(
        padding: const EdgeInsets.all(8),
        child: (Form(
            key: homepageKey,
            child: Column(children: <Widget>[
              TextFormField(
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: "Homepage"),
                initialValue: removeGeminiScheme(appState.settings["homepage"]),
                validator: validateGeminiURL,
                onFieldSubmitted: validateAndSaveForm,
                onSaved: (s) {
                  s = prefixSchema(s!);
                  appState.onSaveSettings("homepage", s);
                },
              ),
              TextFormField(
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: "Search Engine (page that takes input)"),
                initialValue: removeGeminiScheme(appState.settings["search"]),
                validator: validateGeminiURL,
                onFieldSubmitted: validateAndSaveForm,
                onSaved: (s) {
                  s = prefixSchema(s!);
                  appState.onSaveSettings("search", s);
                },
              ),
            ]))),
      )
    ];

    return SingleChildScrollView(child: Column(children: children));
  }

  String prefixSchema(String s) {
    if (!s.startsWith("gemini://") && !s.startsWith("about:")) {
      s = "gemini://" + s;
    }
    return s;
  }

  String removeGeminiScheme(String s) {
    if (s.startsWith("gemini://")) {
      return s.substring(9);
    }
    return s;
  }

  String? validateGeminiURL(String? s) {
    if (s!.trim().isNotEmpty) {
      try {
        s = removeGeminiScheme(s);

        var u = toSchemeUri(s);
        if (u == null || u.scheme.isEmpty) {
          return "Please use a valid gemini uri";
        }
      } catch (_) {
        return "Please enter a valid uri";
      }
    }
    return null;
  }

  void validateAndSaveForm(String s) {
    if (homepageKey.currentState!.validate()) {
      homepageKey.currentState!.save();
    }
  }
}
