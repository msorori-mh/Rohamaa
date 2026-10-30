/// dart:io does not exist in the web build. Browser network failures surface
/// as ClientException / XMLHttpRequest errors, which `isNetworkError` matches
/// by text.
bool isSocketException(Object error) => false;
