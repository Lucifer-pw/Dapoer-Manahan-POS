import 'package:url_launcher/url_launcher.dart';

void saveFile(String url, String name) async {
  try {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    // Ignore error
  }
}
