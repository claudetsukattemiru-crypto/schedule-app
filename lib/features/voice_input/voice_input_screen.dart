import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/parsing/jp_datetime_parser.dart';
import '../../domain/voice/speech_service.dart';
import '../confirm/confirm_event_screen.dart';

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen> {
  final _speech = SpeechService();
  final _parser = JpDateTimeParser();

  bool _isListening = false;
  String _transcript = '';
  String _statusText = 'マイクボタンを押して話してください';
  Timer? _safetyTimer;

  static const _maxListenMs = 30000;

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _speech.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
      return;
    }

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setState(() => _statusText = 'マイクの権限が必要です');
      return;
    }

    final available = await _speech.initialize();
    if (!available) {
      setState(() => _statusText = '音声認識を初期化できませんでした');
      return;
    }

    setState(() {
      _isListening = true;
      _transcript = '';
      _statusText = '話しかけてください…（もう一度押すと終了）';
    });

    _safetyTimer = Timer(const Duration(milliseconds: _maxListenMs), () {
      if (_isListening) _stopListening();
    });

    await _speech.startListening(
      onResult: (text, isFinal) {
        setState(() => _transcript = text);
        if (isFinal && text.isNotEmpty) {
          _stopListening();
        }
      },
      onError: (err) {
        setState(() => _statusText = '認識エラー: $err');
        _stopListening();
      },
    );
  }

  Future<void> _stopListening() async {
    _safetyTimer?.cancel();
    await _speech.stop();
    setState(() {
      _isListening = false;
      _statusText = '認識完了';
    });

    if (_transcript.isNotEmpty) {
      final parsed = _parser.parse(_transcript);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConfirmEventScreen(parsed: parsed),
          ),
        );
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('音声で予定を追加'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Text(_transcript.isEmpty ? '（音声が表示されます）' : _transcript,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.red : const Color(0xFF00A0E9),
                ),
                child: Icon(
                  _isListening ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(_statusText,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
