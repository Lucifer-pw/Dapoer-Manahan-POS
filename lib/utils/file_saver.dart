import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_mobile.dart';

void downloadFile(String url, String name) {
  saveFile(url, name);
}
