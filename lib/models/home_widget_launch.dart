class HomeWidgetLaunch {
  const HomeWidgetLaunch({
    required this.requestId,
    required this.accountId,
    required this.kind,
  });
  final String requestId, accountId, kind;
  static HomeWidgetLaunch? parse(Object? value) {
    if (value is! Map) return null;
    final request = value['requestId'];
    final account = value['accountId'];
    final kind = value['kind'];
    if (request is! String ||
        request.isEmpty ||
        account is! String ||
        account.isEmpty ||
        account.contains('/') ||
        (kind != 'expense' && kind != 'income'))
      return null;
    return HomeWidgetLaunch(
      requestId: request,
      accountId: account,
      kind: kind as String,
    );
  }
}
