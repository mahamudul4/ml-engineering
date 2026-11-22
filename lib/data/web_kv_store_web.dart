import 'dart:js_interop';

@JS('window.localStorage.getItem')
external JSString? _localStorageGet(JSString key);

@JS('window.localStorage.setItem')
external void _localStorageSet(JSString key, JSString value);

/// Reads a string from browser `window.localStorage` (returns null on error).
String? readWebStore(String key) {
  try {
    return _localStorageGet(key.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

/// Writes a string to browser `window.localStorage` (silently ignores quota/private errors).
void writeWebStore(String key, String value) {
  try {
    _localStorageSet(key.toJS, value.toJS);
  } catch (_) {}
}

