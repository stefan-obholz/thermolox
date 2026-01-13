const String kThermoloxApiBase =
    'https://thermolox-proxy.stefan-obholz.workers.dev';

const String kWorkerAppToken = String.fromEnvironment('WORKER_APP_TOKEN');

Map<String, String> buildWorkerHeaders({
  String? contentType,
  String? accept,
}) {
  final headers = <String, String>{};
  if (contentType != null && contentType.isNotEmpty) {
    headers['Content-Type'] = contentType;
  }
  if (accept != null && accept.isNotEmpty) {
    headers['Accept'] = accept;
  }
  if (kWorkerAppToken.isNotEmpty) {
    headers['X-Worker-Token'] = kWorkerAppToken;
  }
  return headers;
}
