import 'dart:html' as html;

void saveFile(String url, String name) async {
  try {
    // Fetch the image as a blob to allow direct download of cross-origin files (e.g. Firebase Storage)
    final response = await html.window.fetch(url);
    final blob = await response.blob();
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: objectUrl)
      ..setAttribute('download', name)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(objectUrl);
  } catch (e) {
    // Fallback: If CORS or fetch fails, open in a new tab where user can right click / hold to save
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('target', '_blank')
      ..setAttribute('download', name)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
  }
}
