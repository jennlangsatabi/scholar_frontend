// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

String read(String key) => html.window.localStorage[key] ?? '';

void write(String key, String value) {
  if (value.isEmpty) {
    html.window.localStorage.remove(key);
    return;
  }
  html.window.localStorage[key] = value;
}

void remove(String key) {
  html.window.localStorage.remove(key);
}
