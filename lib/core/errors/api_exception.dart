class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

String apiErrorMessage(Object? decoded, int statusCode) {
  if (decoded is Map<String, dynamic>) {
    final detail = decoded['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail is List && detail.isNotEmpty) {
      return detail.map((item) {
        if (item is Map && item['msg'] != null) {
          return item['msg'].toString();
        }
        return item.toString();
      }).join('\n');
    }
  }
  if (statusCode == 401) {
    return 'Identifiants incorrects';
  }
  if (statusCode == 0) {
    return 'Hors ligne. Les données seront synchronisées plus tard.';
  }
  return 'Impossible de joindre CityCare ($statusCode)';
}

extension ApiExceptionOffline on ApiException {
  bool get isOffline => statusCode == 0;
}
