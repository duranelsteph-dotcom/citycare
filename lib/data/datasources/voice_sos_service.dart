import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../../domain/voice_help_phrase.dart';

enum VoiceListenStatus { matched, noMatch, unavailable, cancelled }

class VoiceListenOutcome {
  const VoiceListenOutcome({required this.status, this.transcript = ''});

  final VoiceListenStatus status;
  final String transcript;
}

class VoiceSosService {
  VoiceSosService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  Future<VoiceListenOutcome> listen({Duration timeout = const Duration(seconds: 8)}) async {
    final finished = Completer<void>();
    final available = await _speech.initialize(
      onStatus: (status) {
        if ((status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) &&
            !finished.isCompleted) {
          finished.complete();
        }
      },
      onError: (_) {
        if (!finished.isCompleted) {
          finished.complete();
        }
      },
    );
    if (!available) {
      return const VoiceListenOutcome(status: VoiceListenStatus.unavailable);
    }
    var buffer = '';
    try {
      await _speech.listen(
        onResult: (result) {
          buffer = result.recognizedWords;
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
          localeId: 'fr_FR',
          listenFor: timeout,
          pauseFor: const Duration(seconds: 2),
        ),
      );
      await finished.future.timeout(timeout + const Duration(seconds: 2), onTimeout: () {});
    } catch (_) {
      return VoiceListenOutcome(status: VoiceListenStatus.unavailable, transcript: buffer);
    } finally {
      if (_speech.isListening) {
        await _speech.stop();
      }
    }
    if (buffer.trim().isEmpty) {
      return const VoiceListenOutcome(status: VoiceListenStatus.noMatch);
    }
    if (matchesHelpPhrase(buffer)) {
      return VoiceListenOutcome(status: VoiceListenStatus.matched, transcript: buffer);
    }
    return VoiceListenOutcome(status: VoiceListenStatus.noMatch, transcript: buffer);
  }
}
