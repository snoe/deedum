import 'dart:developer';
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
                decoration: InputDecoration(labelText: "Homepage", prefixText: "gemini://"),
                initialValue: settings["homepage"].substring(9),
                validator: (s) {
                  if (s.trim().isNotEmpty) {
                    try {
                      s = removeGeminiScheme(s);

                      var u = Uri.parse(s);
                      if (u.scheme.isNotEmpty) {
                        return "Please use a gemini uri";
                      }
                      u = Uri.parse("gemini://" + s);
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
    if (!s.startsWith("gemini://")) {
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
