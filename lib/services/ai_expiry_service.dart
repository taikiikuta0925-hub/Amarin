import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/food_item.dart';
import '../models/recipe_suggestion.dart';

class AiExpiryResult {
  const AiExpiryResult({
    required this.name,
    required this.expiryDate,
    required this.category,
    required this.confidence,
    required this.isDemo,
  });

  final String name;
  final DateTime expiryDate;
  final String category;
  final double confidence;
  final bool isDemo;
}

class ProductChatMessage {
  const ProductChatMessage({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, String> toJson() => {'role': role, 'text': text};
}

class ProductAgentResult {
  const ProductAgentResult({
    required this.reply,
    required this.ready,
    required this.name,
    required this.expiryDate,
    required this.category,
    required this.confidence,
    required this.isDemo,
  });

  final String reply;
  final bool ready;
  final String name;
  final DateTime? expiryDate;
  final String category;
  final double confidence;
  final bool isDemo;
}

class AiExpiryService {
  const AiExpiryService({String baseUrl = endpoint, http.Client? client})
    : _baseUrl = baseUrl,
      _client = client,
      isDemo = false;

  const AiExpiryService.demo() : _baseUrl = '', _client = null, isDemo = true;

  static const endpoint = String.fromEnvironment(
    'AI_API_BASE_URL',
    defaultValue: 'https://tabekiri-ai.tx-appe-chi.workers.dev',
  );

  final String _baseUrl;
  final http.Client? _client;
  final bool isDemo;

  bool get isConfigured => !isDemo && _baseUrl.trim().isNotEmpty;

  Future<AiExpiryResult> analyze(XFile image) async {
    if (isDemo) {
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      return AiExpiryResult(
        name: 'プレーンヨーグルト',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        category: '乳製品',
        confidence: 0.94,
        isDemo: true,
      );
    }

    final uri = _endpointFor('analyze-expiry');
    final bytes = await image.readAsBytes();
    final decoded = await _post(uri, {
      'imageBase64': base64Encode(bytes),
      'mimeType': image.mimeType ?? _mimeTypeFor(image.name),
      'today': _dateOnly(DateTime.now()),
      'locale': 'ja-JP',
    });
    final payload = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : decoded;
    final expiryText = payload['expiryDate'] as String?;
    final expiryDate = expiryText == null
        ? null
        : DateTime.tryParse(expiryText);
    if (expiryDate == null) {
      throw const AiExpiryException('写真から賞味期限を読み取れませんでした');
    }

    return AiExpiryResult(
      name: payload['name'] as String? ?? '',
      expiryDate: expiryDate,
      category: payload['category'] as String? ?? 'その他',
      confidence: (payload['confidence'] as num?)?.toDouble() ?? 0,
      isDemo: false,
    );
  }

  Future<ProductAgentResult> identifyProduct(
    List<ProductChatMessage> messages,
  ) async {
    if (isDemo) return _demoIdentify(messages);

    final decoded = await _post(_endpointFor('identify-product'), {
      'messages': messages.map((message) => message.toJson()).toList(),
      'today': _dateOnly(DateTime.now()),
      'locale': 'ja-JP',
    });
    final reply = decoded['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw const AiExpiryException('AIからの回答を読み取れませんでした。もう一度お試しください');
    }
    final expiryText = decoded['expiryDate'] as String? ?? '';
    final expiryDate = DateTime.tryParse(expiryText);
    final name = decoded['name'] as String? ?? '';
    final ready =
        decoded['ready'] == true &&
        name.trim().isNotEmpty &&
        expiryDate != null;
    return ProductAgentResult(
      reply: reply,
      ready: ready,
      name: name,
      expiryDate: expiryDate,
      category: decoded['category'] as String? ?? 'その他',
      confidence: (decoded['confidence'] as num?)?.toDouble() ?? 0,
      isDemo: false,
    );
  }

  Future<List<RecipeSuggestion>> suggestRecipes(
    List<FoodItem> items, {
    String preference = '',
  }) async {
    final usableItems = items.where((item) => !item.isConsumed).toList();
    if (usableItems.isEmpty) {
      throw const AiExpiryException('レシピに使える食品を先に登録してください');
    }
    if (isDemo) return _demoRecipes(usableItems);

    final decoded = await _post(_endpointFor('suggest-recipes'), {
      'items': _recipeItems(usableItems),
      'preference': preference.trim(),
      'today': _dateOnly(DateTime.now()),
      'locale': 'ja-JP',
    });
    final rawRecipes = decoded['recipes'];
    if (rawRecipes is! List) {
      throw const AiExpiryException('AIからレシピを読み取れませんでした。もう一度お試しください');
    }
    final recipes = rawRecipes
        .whereType<Map<String, dynamic>>()
        .map(RecipeSuggestion.fromJson)
        .where(
          (recipe) => recipe.title.trim().isNotEmpty && recipe.steps.isNotEmpty,
        )
        .toList();
    if (recipes.isEmpty) {
      throw const AiExpiryException('条件に合うレシピを作れませんでした。条件を変えてお試しください');
    }
    return recipes;
  }

  Future<String> chatAboutRecipes(
    List<FoodItem> items,
    List<ProductChatMessage> messages,
  ) async {
    final usableItems = items.where((item) => !item.isConsumed).toList();
    if (usableItems.isEmpty) {
      throw const AiExpiryException('相談に使える食品を先に登録してください');
    }
    if (messages.isEmpty) throw const AiExpiryException('質問を入力してください');
    if (isDemo) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return '登録食材を確認しました。実際のAI接続では、代用品や調理方法を具体的に提案します。';
    }

    final decoded = await _post(_endpointFor('recipe-chat'), {
      'items': _recipeItems(usableItems),
      'messages': messages.map((message) => message.toJson()).toList(),
      'today': _dateOnly(DateTime.now()),
      'locale': 'ja-JP',
    });
    final reply = decoded['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw const AiExpiryException('AIからの回答を読み取れませんでした。もう一度お試しください');
    }
    return reply.trim();
  }

  List<Map<String, dynamic>> _recipeItems(List<FoodItem> items) => items
      .map(
        (item) => {
          'name': item.name,
          'category': item.category,
          'expiryDate': _dateOnly(item.expiryDate),
          'daysRemaining': item.daysRemaining,
        },
      )
      .toList();

  Uri _endpointFor(String action) {
    final baseUrl = _baseUrl.trim();
    if (baseUrl.isEmpty) {
      throw const AiExpiryException('AIの接続先が設定されていません');
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const AiExpiryException('AIの接続先URLが正しくありません');
    }
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (segments.isNotEmpty &&
        (segments.last == 'analyze-expiry' ||
            segments.last == 'identify-product' ||
            segments.last == 'suggest-recipes' ||
            segments.last == 'recipe-chat')) {
      segments[segments.length - 1] = action;
    } else {
      segments.add(action);
    }
    return uri.replace(pathSegments: segments);
  }

  Future<Map<String, dynamic>> _post(
    Uri uri,
    Map<String, dynamic> payload,
  ) async {
    final http.Response response;
    try {
      final post = _client?.post ?? http.post;
      response = await post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const AiExpiryException('AIの応答がタイムアウトしました。もう一度お試しください');
    } on http.ClientException {
      throw const AiExpiryException('AIサーバーに接続できませんでした。通信環境を確認してください');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiExpiryException(
        _errorMessage(
          response.body,
          fallback: 'AIサーバーでエラーが発生しました (${response.statusCode})',
        ),
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // 不正な応答は固定回答へ置き換えず、画面で再試行を案内する。
    }
    throw const AiExpiryException('AIからの回答を読み取れませんでした。もう一度お試しください');
  }

  Future<ProductAgentResult> _demoIdentify(
    List<ProductChatMessage> messages,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final conversation = messages
        .where((message) => message.role == 'user')
        .map((message) => message.text)
        .join(' ');
    final product = _detectDemoProduct(conversation);
    final expiryDate = _detectDemoDate(conversation);

    if (product == null) {
      return const ProductAgentResult(
        reply: 'どんな食品ですか？ パッケージの名前や種類を教えてください。',
        ready: false,
        name: '',
        expiryDate: null,
        category: 'その他',
        confidence: 0,
        isDemo: true,
      );
    }
    if (expiryDate == null) {
      return ProductAgentResult(
        reply: '$productのパッケージに印字された賞味期限または消費期限はいつですか？',
        ready: false,
        name: product,
        expiryDate: null,
        category: _demoCategory(product),
        confidence: .7,
        isDemo: true,
      );
    }
    return ProductAgentResult(
      reply: '$product、期限は${_dateOnly(expiryDate)}ですね。この内容で登録できます。',
      ready: true,
      name: product,
      expiryDate: expiryDate,
      category: _demoCategory(product),
      confidence: .9,
      isDemo: true,
    );
  }

  Future<List<RecipeSuggestion>> _demoRecipes(List<FoodItem> items) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final names = items.take(3).map((item) => item.name).toList();
    return [
      RecipeSuggestion(
        title: '${names.first}のかんたん炒め',
        description: '登録食材を無駄なく使うデモレシピです。',
        cookTimeMinutes: 15,
        servings: '2人分',
        ingredients: names
            .map(
              (name) =>
                  RecipeIngredient(name: name, amount: '適量', available: true),
            )
            .toList(),
        steps: const ['材料を食べやすい大きさに切ります。', '火が通るまで炒め、味を調えます。'],
        usesRegisteredItems: names,
        tip: '実際のAI接続時は、登録内容に合わせて詳しいレシピを生成します。',
      ),
    ];
  }

  String? _detectDemoProduct(String text) {
    const products = ['ヨーグルト', '牛乳', '豆腐', '納豆', '卵', 'チーズ', 'ハム', 'パン'];
    for (final product in products) {
      if (text.contains(product)) return product;
    }
    return null;
  }

  String _demoCategory(String product) {
    if (product == '牛乳') return '飲み物';
    if (product == 'ヨーグルト' || product == 'チーズ') return '乳製品';
    if (product == 'ハム') return '肉・魚';
    return '冷蔵品';
  }

  DateTime? _detectDemoDate(String text) {
    final iso = RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(text);
    if (iso != null) {
      return DateTime.tryParse(
        '${iso.group(1)}-${iso.group(2)!.padLeft(2, '0')}-${iso.group(3)!.padLeft(2, '0')}',
      );
    }
    final japanese = RegExp(
      r'(?:(\d{4})年)?\s*(\d{1,2})月\s*(\d{1,2})日',
    ).firstMatch(text);
    if (japanese == null) return null;
    final now = DateTime.now();
    final year = int.tryParse(japanese.group(1) ?? '') ?? now.year;
    final month = int.tryParse(japanese.group(2) ?? '');
    final day = int.tryParse(japanese.group(3) ?? '');
    if (month == null || day == null) return null;
    final candidate = DateTime(year, month, day);
    if (candidate.month != month || candidate.day != day) return null;
    return candidate;
  }

  String _errorMessage(String responseBody, {required String fallback}) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final message = decoded['error'];
      if (message is String && message.trim().isNotEmpty) return message;
    } catch (_) {
      // 読めないエラーレスポンスは利用者向けメッセージへ置き換える。
    }
    return fallback;
  }

  String _mimeTypeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class AiExpiryException implements Exception {
  const AiExpiryException(this.message);

  final String message;

  @override
  String toString() => message;
}
