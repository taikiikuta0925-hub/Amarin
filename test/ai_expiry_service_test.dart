import 'dart:convert';

import 'package:flutter_application_1/services/ai_expiry_service.dart';
import 'package:flutter_application_1/models/food_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const messages = [
    ProductChatMessage(role: 'user', text: '青森りんごジュースです。期限は2026年10月21日です。'),
  ];

  test('設定したAI endpointへ会話を送り、生成結果を返す', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url,
        Uri.parse('https://example.test/api/identify-product'),
      );
      expect(request.headers['content-type'], 'application/json');
      final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      final sentMessages = requestBody['messages'] as List<dynamic>;
      expect(
        (sentMessages.single as Map<String, dynamic>)['text'],
        contains('青森りんごジュース'),
      );

      return http.Response(
        jsonEncode({
          'reply': '青森りんごジュース、期限は2026年10月21日です。',
          'ready': true,
          'name': '青森りんごジュース',
          'expiryDate': '2026-10-21',
          'category': '飲み物',
          'confidence': 0.98,
        }),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final service = AiExpiryService(
      baseUrl: 'https://example.test/api',
      client: client,
    );

    final result = await service.identifyProduct(messages);

    expect(result.isDemo, isFalse);
    expect(result.ready, isTrue);
    expect(result.name, '青森りんごジュース');
    expect(result.expiryDate, DateTime(2026, 10, 21));
  });

  test('AI serverのエラー時にデモ回答へ置き換えない', () async {
    final service = AiExpiryService(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'error': 'Gemini upstream error'}), 500),
      ),
    );

    await expectLater(
      service.identifyProduct(messages),
      throwsA(
        isA<AiExpiryException>().having(
          (error) => error.message,
          'message',
          'Gemini upstream error',
        ),
      ),
    );
  });

  test('接続先が空なら設定エラーを返す', () async {
    const service = AiExpiryService(baseUrl: '');

    await expectLater(
      service.identifyProduct(messages),
      throwsA(
        isA<AiExpiryException>().having(
          (error) => error.message,
          'message',
          'AIの接続先が設定されていません',
        ),
      ),
    );
  });

  test('登録食品をAIへ送りレシピ候補を読み取る', () async {
    final now = DateTime.now();
    final service = AiExpiryService(
      baseUrl: 'https://example.test/api',
      client: MockClient((request) async {
        expect(request.url.path, '/api/suggest-recipes');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final items = body['items'] as List<dynamic>;
        expect((items.first as Map<String, dynamic>)['name'], '絹ごし豆腐');
        expect(body['preference'], '15分以内');
        return http.Response(
          jsonEncode({
            'recipes': [
              {
                'title': '豆腐のみそ炒め',
                'description': '豆腐を使い切る一品です。',
                'cookTimeMinutes': 15,
                'servings': '2人分',
                'ingredients': [
                  {'name': '絹ごし豆腐', 'amount': '1丁', 'available': true},
                  {'name': 'みそ', 'amount': '大さじ1', 'available': false},
                ],
                'steps': ['豆腐を切る', '炒めて味付けする'],
                'usesRegisteredItems': ['絹ごし豆腐'],
                'tip': '水切りすると崩れにくくなります。',
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final item = FoodItem(
      id: 'tofu',
      name: '絹ごし豆腐',
      category: '冷蔵品',
      expiryDate: now.add(const Duration(days: 2)),
      registeredAt: now,
      registeredWithAi: false,
    );

    final recipes = await service.suggestRecipes([item], preference: '15分以内');

    expect(recipes.single.title, '豆腐のみそ炒め');
    expect(recipes.single.ingredients.first.available, isTrue);
    expect(recipes.single.steps, hasLength(2));
  });

  test('登録食品を踏まえてAIシェフと会話する', () async {
    final now = DateTime.now();
    final service = AiExpiryService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/recipe-chat');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['items'], isNotEmpty);
        expect(body['messages'], isNotEmpty);
        return http.Response(
          jsonEncode({'reply': 'みそで代用できます。'}),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final item = FoodItem(
      id: 'miso',
      name: 'みそ',
      category: '調味料',
      expiryDate: now.add(const Duration(days: 30)),
      registeredAt: now,
      registeredWithAi: false,
    );

    final reply = await service.chatAboutRecipes(
      [item],
      const [ProductChatMessage(role: 'user', text: 'しょうゆの代わりは？')],
    );

    expect(reply, 'みそで代用できます。');
  });
}
