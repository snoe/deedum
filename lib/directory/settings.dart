import 'package:deedum/directory/directory_element.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Settings extends DirectoryElement {
  final Map settings;
  final void Function(String, String) onSaveSettings;
  final homepageKey = GlobalKey<FormState>();

  Settings({
    Key? key,
    required this.settings,
    required this.onSaveSettings,
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
  Widget build(BuildContext context) {
    var children = [
      Padding(
        padding: const EdgeInsets.all(8),
        child: (Form(
            key: homepageKey,
            child: Column(children: <Widget>[
              TextFormField(
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: "Homepage"),
                initialValue: removeGeminiScheme(settings["homepage"]),
                validator: validateGeminiURL,
                onFieldSubmitted: validateAndSaveForm,
                onSaved: (s) {
                  s = prefixSchema(s!);
                  onSaveSettings("homepage", s);
                },
              ),
              TextFormField(
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: "Search Engine (page that takes input)"),
                initialValue: removeGeminiScheme(settings["search"]),
                validator: validateGeminiURL,
                onFieldSubmitted: validateAndSaveForm,
                onSaved: (s) {
                  s = prefixSchema(s!);
                  onSaveSettings("search", s);
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
