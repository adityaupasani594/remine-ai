import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

/// Result model returned from Gemini analysis
class DeviceAnalysis {
  final bool isElectronic;
  final String userMessage;
  final String deviceName;
  final String deviceDetails;
  final List<MaterialSegment> materials;
  final List<String> detectedComponents;
  final double totalValueInr;

  const DeviceAnalysis({
    required this.isElectronic,
    required this.userMessage,
    required this.deviceName,
    required this.deviceDetails,
    required this.materials,
    required this.detectedComponents,
    required this.totalValueInr,
  });
}

class MaterialSegment {
  final String label;
  final double fraction; // 0.0 – 1.0
  final String symbol; // e.g. Au, Cu, Ag
  final String valueInr; // formatted, e.g. ₹1,200

  const MaterialSegment({
    required this.label,
    required this.fraction,
    required this.symbol,
    required this.valueInr,
  });
}

class GeminiService {
  // Primary: injected at build time via:
  //   flutter run --dart-define-from-file=.env
  static const String _compileTimeApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // Secondary: host process environment — useful for IDEs that set env vars.
  static String get _runtimeApiKey =>
      (Platform.environment['GEMINI_API_KEY'] ?? '').trim();

  static String get _resolvedApiKey {
    if (_compileTimeApiKey.isNotEmpty) return _compileTimeApiKey.trim();
    if (_runtimeApiKey.isNotEmpty) return _runtimeApiKey;
    return '';
  }

  static GenerativeModel get _model {
    final apiKey = _resolvedApiKey;
    if (apiKey.isEmpty) {
      throw StateError(
        'Gemini API key not set.\n'
        'Checked:\n'
        '1) --dart-define/--dart-define-from-file (.env)\n'
        '2) Platform.environment["GEMINI_API_KEY"]\n'
        'Run: flutter run --dart-define-from-file=.env',
      );
    }

    return GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: apiKey,
    );
  }

  static const String _prompt = '''
You are an expert e-waste analyser.
First decide if the image contains electronic/e-waste (phones, laptops, chargers, PC parts, circuit boards, small appliances).
If it's NOT an electronic item, return JSON with:
- isElectronic: false
- userMessage: a short friendly message explaining it’s not e-waste and asking for an electronics photo
- deviceName: "Not e-waste"
- deviceDetails: ""
- totalValueInr: 0
- detectedComponents: []
- materials: [{"label":"Other","symbol":"—","fraction":1.0,"valueInr":"₹0"}]

If it IS electronic, return JSON with isElectronic:true and userMessage:"" plus the exact structure below.
Return ONLY a valid JSON object (no markdown, no explanation).

{
  "isElectronic": true,
  "userMessage": "",
  "deviceName": "string",
  "deviceDetails": "string",
  "totalValueInr": 4500,
  "detectedComponents": ["string"],
  "materials": [
    {"label": "Gold", "symbol": "Au", "fraction": 0.18, "valueInr": "₹810"}
  ]
}

Rules:
- fractions should sum to 1.0
- include 3–5 materials
- be realistic for e-waste in India
''';

  static Future<DeviceAnalysis> analyseImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      final response = await _model.generateContent([
        Content.multi([
          TextPart(_prompt),
          DataPart('image/jpeg', bytes),
        ]),
      ]);

      final rawText = (response.text ?? '').trim();
      if (rawText.isEmpty) {
        throw const FormatException('Gemini returned an empty response');
      }

      final json = _parseGeminiJsonObject(rawText);
      return _toAnalysis(json);
    } on GenerativeAIException catch (e) {
      // Includes invalid key, quota exceeded, safety filters, etc.
      throw Exception('Gemini API error: ${e.message}');
    } on SocketException {
      throw Exception('Network error: check your internet connection.');
    } on FormatException catch (e) {
      throw Exception('Could not parse Gemini response: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected analysis error: $e');
    }
  }

  static Map<String, dynamic> _parseGeminiJsonObject(String text) {
    // 1) Direct JSON
    final direct = _tryDecodeObject(text);
    if (direct != null) return direct;

    // 2) Strip fences
    final unfenced = text
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();
    final unfencedDecoded = _tryDecodeObject(unfenced);
    if (unfencedDecoded != null) return unfencedDecoded;

    // 3) Extract first {...} block
    final start = unfenced.indexOf('{');
    final end = unfenced.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final slice = unfenced.substring(start, end + 1);
      final slicedDecoded = _tryDecodeObject(slice);
      if (slicedDecoded != null) return slicedDecoded;
    }

    throw const FormatException('Response is not a JSON object');
  }

  static Map<String, dynamic>? _tryDecodeObject(String input) {
    try {
      final decoded = jsonDecode(input);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
    }
  }

  static DeviceAnalysis _toAnalysis(Map<String, dynamic> json) {
    final isElectronic = (json['isElectronic'] is bool)
        ? (json['isElectronic'] as bool)
        : true;
    final userMessage = (json['userMessage'] ?? '').toString();

    final deviceName = (json['deviceName'] ?? (isElectronic ? 'Unknown device' : 'Not e-waste')).toString();
    final deviceDetails = (json['deviceDetails'] ?? '').toString();
    final double totalValue = isElectronic
        ? _toDouble(json['totalValueInr'], fallback: 0)
        : 0.0;

    final detectedRaw = json['detectedComponents'];
    final detected = detectedRaw is List
        ? detectedRaw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList()
        : <String>[];

    final materialsRaw = json['materials'];
    List<MaterialSegment> materials;
    if (materialsRaw is List && materialsRaw.isNotEmpty) {
      materials = materialsRaw
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .map(
            (m) => MaterialSegment(
              label: (m['label'] ?? 'Other').toString(),
              symbol: (m['symbol'] ?? '—').toString(),
              fraction: _toDouble(m['fraction'], fallback: 0),
              valueInr: (m['valueInr'] ?? '₹0').toString(),
            ),
          )
          .toList();
    } else {
      materials = const [MaterialSegment(label: 'Other', symbol: '—', fraction: 1.0, valueInr: '₹0')];
    }

    final sum = materials.fold<double>(0, (acc, m) => acc + m.fraction);
    if (sum > 0) {
      materials = materials
          .map((m) => MaterialSegment(label: m.label, symbol: m.symbol, fraction: m.fraction / sum, valueInr: m.valueInr))
          .toList();
    }

    return DeviceAnalysis(
      isElectronic: isElectronic,
      userMessage: userMessage,
      deviceName: deviceName,
      deviceDetails: deviceDetails,
      materials: materials,
      detectedComponents: detected,
      totalValueInr: totalValue,
    );
  }

  static double _toDouble(Object? v, {required double fallback}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }
}
