import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _stt.initialize();
    return _initialized;
  }

  bool get isListening => _stt.isListening;

  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String error) onError,
  }) async {
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'ja_JP',
        cancelOnError: false,
        partialResults: true,
      ),
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
    );
    _stt.errorListener = (error) => onError(error.errorMsg);
  }

  Future<void> stop() async {
    await _stt.stop();
  }

  void dispose() {
    _stt.cancel();
  }
}
