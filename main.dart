//main.dart

//تطبيق Flutter لقراءة شرائح NFC (يدعم الوضع الحقيقي والمحاكاة). 
//يتيح قراءة UID وبيانات NDEF مع واجهة عصرية وسهلة الاستخدام.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';



void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NFC - محاكات/حقيقي',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const NfcHomePage(),
    );
  }
}

class NfcHomePage extends StatefulWidget {
  const NfcHomePage({super.key});
  @override
  State<NfcHomePage> createState() => _NfcHomePageState();
}

class _NfcHomePageState extends State<NfcHomePage> {
  String _statusMessage = "📡 جاهز. اضغط 'ابدأ القراءة' لبدء المسح.";
  String _readResult = "";
  bool _isScanning = false;

  @override
  void dispose() {
    if (_isScanning) {
      NfcManager.instance.stopSession();
    }
    super.dispose();
  }

  /// بيانات محاكاة (عندما لا يوجد NFC في الجهاز)
  Map<String, String> _generateSimulatedTag() {
    return {
      "uid": "04:A3:BC:92:1F",
      "ndef": "Hello from Demo (Simulated NDEF text)",
      "type": "ISO14443-A (simulated)"
    };
  }

  /// بدء القراءة
  Future<void> _onStartPressed() async {
    setState(() {
      _readResult = "";
      _statusMessage = "⏳ التحقق من توفر NFC...";
    });

    try {
      bool available = await NfcManager.instance.isAvailable();

      if (!available) {
        setState(() {
          _statusMessage =
              "⚠️ جهازك لا يدعم NFC. هل تريد تجربة وضع المحاكاة؟";
        });
        bool simulate = await _showSimulationDialog();
        if (simulate) {
          final tag = _generateSimulatedTag();
          setState(() {
            _readResult = _formatResultFromMap(tag);
            _statusMessage = "🎭 محاكاة قراءة بطاقة NFC (Demo Mode)";
          });
        }
        return;
      }

      setState(() {
        _statusMessage = "📡 ضع البطاقة بالقرب من الجهاز...";
        _isScanning = true;
      });

     await NfcManager.instance.startSession(
  pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
  onDiscovered: (NfcTag tag) async {
    try {
      String uid = "Unknown UID";

      final data = tag.data as Map<String, dynamic>;

      final nfca = data["nfca"] as Map<String, dynamic>?;
      final nfcaIdentifier = nfca?["identifier"];
      if (nfcaIdentifier is Uint8List) {
        uid = nfcaIdentifier
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(":")
            .toUpperCase();
      } else {
        final mifare = data["mifare"] as Map<String, dynamic>?;
        final id2 = mifare?["identifier"];
        if (id2 is Uint8List) {
          uid = id2
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(":")
              .toUpperCase();
        }
      }

      String ndefText = "No NDEF data found.";

final ndefData = data["ndef"] as Map<String, dynamic>?;
if (ndefData != null) {
  final cachedMessage = ndefData["cachedMessage"] as Map<String, dynamic>?;
  if (cachedMessage != null) {
    final records = cachedMessage["records"] as List?;
    if (records != null && records.isNotEmpty) {
      ndefText = "";
      for (var r in records) {
        final payload = r["payload"];
        if (payload is Uint8List) {
          try {
            ndefText += String.fromCharCodes(payload) + "\n";
          } catch (_) {
            ndefText += payload.toString() + "\n";
          }
        }
      }
    }
  }
}

      final result = {
        "uid": uid,
        "type": data.keys.join(", "),
        "ndef": ndefText,
      };

      if (!mounted) return;
      setState(() {
        _readResult = _formatResultFromMap(result);
        _statusMessage = "✅ تم قراءة البطاقة بنجاح.";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _readResult = "❌ خطأ أثناء معالجة البطاقة:\n$e";
        _statusMessage = "⚠️ فشل القراءة.";
      });
    } finally {
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  },
);

    } on PlatformException catch (p) {
      setState(() {
        _statusMessage = "❌ خطأ بالنظام:\n${p.message}";
        _readResult = p.toString();
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "❌ خطأ غير متوقع:\n$e";
        _readResult = e.toString();
        _isScanning = false;
      });
    }
  }

  /// عرض حوار المحاكاة
  Future<bool> _showSimulationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("تشغيل المحاكاة؟"),
              content: const Text(
                  "جهازك لا يدعم NFC أو أنك تستخدم محاكي. هل تريد تجربة وضع المحاكاة؟"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("لا"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("نعم"),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// تنسيق النتيجة
  String _formatResultFromMap(Map data) {
    final buffer = StringBuffer();
    if (data["uid"] != null) buffer.writeln("🔑 UID: ${data["uid"]}");
    if (data["type"] != null) buffer.writeln("📦 Type: ${data["type"]}");
    if (data["ndef"] != null) buffer.writeln("\n📘 NDEF:\n${data["ndef"]}");
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("قارئ NFC "),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            children: [
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.nfc,
                        size: 60,
                        color: _isScanning ? Colors.green : Colors.deepPurple,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (_readResult.isNotEmpty) ...[
                        const Divider(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "📋 بيانات البطاقة:",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700]),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SelectableText(
                            _readResult,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
             ElevatedButton.icon(
  onPressed: _isScanning ? null : _onStartPressed,
  icon: const Icon(Icons.play_arrow, size: 24),
  label: Text(
    _isScanning ? "جاري المسح..." : "ابدأ القراءة",
    style: const TextStyle(fontSize: 16,color: Color.fromARGB(255, 177, 174, 179), fontWeight: FontWeight.bold),
  ),
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    backgroundColor: const Color.fromARGB(255, 73, 17, 110),
  ),
),

              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  final tag = _generateSimulatedTag();
                  setState(() {
                    _readResult = _formatResultFromMap(tag);
                    _statusMessage = "🎭 محاكاة يدوية - بيانات تجريبية";
                  });
                },
                icon: const Icon(Icons.developer_mode),
                label: const Text("تجربة المحاكاة يدوياً"),
              ),
              const Spacer(),
              const Text(
                "ℹ️ ملاحظة: المحاكيات (Android Emulator / iOS Simulator) لا تدعم NFC الحقيقي.\nاستخدم هاتف حقيقي يدعم NFC للاختبار.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
