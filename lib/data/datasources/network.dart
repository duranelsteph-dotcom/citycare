import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_exception.dart';

const offlineException = ApiException(
  'Hors ligne. Enregistrement local : l’heure du téléphone est conservée. '
  'Ce n’est pas Last Write Wins, pas un suivi en direct.',
  statusCode: 0,
);

Future<http.Response> guardedHttp(Future<http.Response> Function() send) async {
  try {
    return await send();
  } on SocketException {
    throw offlineException;
  } on http.ClientException {
    throw offlineException;
  }
}
