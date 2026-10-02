enum ServerAddressProblem { invalid, insecure }

abstract final class ServerAddress {
  static const _localHosts = {'127.0.0.1', 'localhost', '10.0.2.2'};

  static (String?, ServerAddressProblem?) parse(String text, {required bool allowCleartext}) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      return (null, ServerAddressProblem.invalid);
    }
    final permitted = uri.scheme == 'https' || allowCleartext || _localHosts.contains(uri.host);
    if (!permitted) return (null, ServerAddressProblem.insecure);
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return (uri.replace(path: path).toString(), null);
  }
}
