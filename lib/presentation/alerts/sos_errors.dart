import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_exception.dart';
import '../../data/datasources/network.dart';

/// Message SOS affiché tel quel : jamais « indisponible pour le moment ».
String describeSosFailure(Object error) {
  if (error is ApiException) {
    final text = error.message.trim();
    if (text.isNotEmpty) {
      return text;
    }
    if (error.isOffline || error.statusCode == 0) {
      return 'Serveur injoignable.';
    }
    if (error.statusCode == 401) {
      return 'Authentification requise';
    }
    return 'Impossible de joindre CityCare (${error.statusCode}).';
  }
  if (error is FormatException) {
    return 'Serveur injoignable (réponse invalide).';
  }
  if (error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException ||
      error is HandshakeException) {
    return connectionFailure(error).message;
  }
  return connectionFailure(error).message;
}
