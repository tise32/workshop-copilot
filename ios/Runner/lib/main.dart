import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const WorkshopApp());

class WorkshopApp extends StatelessWidget {
  const WorkshopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1115),
      ),
      home: const CopilotScreen(),
    );
  }
}

class CopilotScreen extends StatefulWidget {
  const CopilotScreen({super.key});

  @override
  State<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends State<CopilotScreen> {
  // Điền trực tiếp DeepSeek API Key của bạn
  final String deepseekApiKey = const String.fromEnvironment('sk-a35a2ff9ce8f420bb279cf8572c451a8');
  late stt.SpeechToText _speech;
  late FlutterTts _tts;

  bool _isListening = false;
  bool _isLoading = false;
  String _recognizedText = "Nhấn giữ nút để nghe tiếng Trung...";
  String _vietnameseMeaning = "";
  String _chineseReply = "";
  String _pinyin = "";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initAudioEngine();
  }

  void _initAudioEngine() async {
    await _speech.initialize();
    await _tts.setLanguage("vi-VN");
    await _tts.setSpeechRate(0.55); // Tốc độ đọc tự nhiên, rõ ràng
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
        _recognizedText = "Đang lắng nghe đối phương nói...";
      });
      _speech.listen(
        localeId: "zh_CN", // Khóa cứng tiếng Trung đại lục
        onResult: (val) {
          setState(() {
            _recognizedText = val.recognizedWords;
          });
        },
      );
    }
  }

  void _stopListeningAndProcess() async {
    await _speech.stop();
    setState(() => _isListening = false);

    if (_recognizedText.isNotEmpty && !_recognizedText.contains("...")) {
      _fetchDeepSeekAssist(_recognizedText);
    }
  }

  Future<void> _fetchDeepSeekAssist(String text) async {
    setState(() => _isLoading = true);

    const systemPrompt = """
    Bạn là Kỹ sư trưởng xưởng sản xuất. Đối phương vừa nói tiếng Trung: 
    Hãy phân tích và trả về đúng 3 dòng định dạng sau, không thêm lời mở đầu:
    NGHIA: [Bản dịch tiếng Việt chuẩn thuật ngữ kỹ thuật nhà xưởng]
    DAP: [Một câu đối đáp ngắn gọn, sắc bén bằng chữ Hán]
    PINYIN: [Phiên âm Pinyin kèm thanh điệu]
    """;

    try {
      final response = await http.post(
        Uri.parse("https://api.deepseek.com/chat/completions"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $deepseekApiKey",
        },
        body: jsonEncode({
          "model": "deepseek-chat",
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": text}
          ],
          "temperature": 0.2,
          "max_tokens": 120
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String reply = data['choices'][0]['message']['content'];

        String nghia = "";
        String dap = "";
        String pinyin = "";

        for (var line in reply.split("\n")) {
          if (line.startsWith("NGHIA:")) nghia = line.replaceFirst("NGHIA:", "").trim();
          if (line.startsWith("DAP:")) dap = line.replaceFirst("DAP:", "").trim();
          if (line.startsWith("PINYIN:")) pinyin = line.replaceFirst("PINYIN:", "").trim();
        }

        setState(() {
          _vietnameseMeaning = nghia;
          _chineseReply = dap;
          _pinyin = pinyin;
        });

        // Đọc ngay bản dịch tiếng Việt vào tai nghe
        if (nghia.isNotEmpty) {
          await _tts.speak(nghia);
        }
      }
    } catch (e) {
      setState(() => _vietnameseMeaning = "Lỗi mạng hoặc API: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("COPILOT KỸ THUẬT XƯỞNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E222B),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hộp hiển thị tín hiệu nghe được
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueGrey.shade800),
                ),
                child: Text(
                  _recognizedText,
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 16),

              // Bảng điều khiển tác chiến (Hiện lớn chữ Hán + Pinyin)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E222B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _chineseReply.isNotEmpty ? Colors.amber : Colors.transparent, width: 2),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("NGHĨA TIẾNG VIỆT:", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                _vietnameseMeaning.isEmpty ? "..." : _vietnameseMeaning,
                                style: const TextStyle(fontSize: 18, color: Colors.greenAccent, fontWeight: FontWeight.w600),
                              ),
                              const Divider(height: 30, color: Colors.white24),
                              const Text("CÂU TRẢ LỜI ĐỀ XUẤT:", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              // Chữ Hán to bản cho môi trường xưởng
                              Text(
                                _chineseReply.isEmpty ? "..." : _chineseReply,
                                style: const TextStyle(fontSize: 32, color: Colors.amber, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              // Phiên âm Pinyin
                              Text(
                                _pinyin.isEmpty ? "" : _pinyin,
                                style: const TextStyle(fontSize: 18, color: Colors.lightBlueAccent, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Phím kích hoạt thu âm lớn ở đáy màn hình
              GestureDetector(
                onTapDown: (_) => _startListening(),
                onTapUp: (_) => _stopListeningAndProcess(),
                child: Container(
                  height: 75,
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.redAccent : Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _isListening ? Colors.red.withOpacity(0.4) : Colors.amber.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _isListening ? "ĐANG THU ÂM (THẢ TAY ĐỂ XỬ LÝ)..." : "GIỮ ĐỂ BẮT TIẾNG TRUNG",
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
