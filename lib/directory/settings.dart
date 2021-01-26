import 'dart:developer';
import 'package:deedum/shared.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Settings extends StatelessWidget {
  final Map settings;
  final onSaveSettings;
  final homepageKey = GlobalKey<FormState>();

  Settings(this.settings, this.onSaveSettings);

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
          padding: EdgeInsets.all(8),
          child: (Form(
              key: homepageKey,
              child: TextFormField(
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: "Homepage"),
                initialValue: removeGeminiScheme(settings["homepage"]),
                validator: (s) {
                  if (s.trim().isNotEmpty) {
                    try {
                      s = removeGeminiScheme(s);

                      var u = toSchemeUri(s);
                      if (u.scheme.isEmpty) {
                        return "Please use a valid gemini uri";
                      }
                    } catch (_) {
                      return "Please enter a valid uri";
                    }
                  }
                  return null;
                },
                onFieldSubmitted: (s) {
                  if (homepageKey.currentState.validate()) {
                    homepageKey.currentState.save();
                  }
                },
                onSaved: (s) {
                  s = prefixSchema(s);
                  onSaveSettings("homepage", s);
                },
              ))))
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
}
