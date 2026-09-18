import assert from 'node:assert/strict';
import test from 'node:test';

import worker from './gemini-worker.js';

const request = () =>
  new Request('https://worker.test/identify-product', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      messages: [
        { role: 'user', text: 'りんごジュース、期限は2026-10-21です' },
      ],
      today: '2026-09-05',
      locale: 'ja-JP',
    }),
  });

test('high demand時は次のGeminiモデルへ切り替える', async () => {
  const originalFetch = globalThis.fetch;
  const urls = [];
  globalThis.fetch = async (url) => {
    urls.push(String(url));
    if (urls.length === 1) {
      return Response.json(
        { error: { message: 'This model is currently experiencing high demand.' } },
        { status: 503 },
      );
    }
    return Response.json({
      candidates: [
        {
          content: {
            parts: [
              {
                text: JSON.stringify({
                  reply: '確認できました。',
                  ready: true,
                  name: 'りんごジュース',
                  expiryDate: '2026-10-21',
                  category: '飲み物',
                  confidence: 0.95,
                }),
              },
            ],
          },
        },
      ],
    });
  };

  try {
    const response = await worker.fetch(request(), {
      GEMINI_API_KEY: 'test-key',
      GEMINI_MODEL: 'gemini-3.8-flash',
      GEMINI_FALLBACK_MODELS: 'gemini-3.5-flash,gemini-3.5-flash-lite',
    });
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.modelUsed, 'gemini-3.5-flash');
    assert.equal(urls.length, 2);
    assert.match(urls[0], /gemini-3\.8-flash/);
    assert.match(urls[1], /gemini-3\.5-flash/);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('修正が必要な400エラーでは別モデルへ切り替えない', async () => {
  const originalFetch = globalThis.fetch;
  let requestCount = 0;
  globalThis.fetch = async () => {
    requestCount += 1;
    return Response.json(
      { error: { message: 'Invalid request payload' } },
      { status: 400 },
    );
  };

  try {
    const response = await worker.fetch(request(), {
      GEMINI_API_KEY: 'test-key',
      GEMINI_MODEL: 'gemini-3.8-flash',
      GEMINI_FALLBACK_MODELS: 'gemini-3.5-flash',
    });
    const body = await response.json();

    assert.equal(response.status, 500);
    assert.equal(body.error, 'Invalid request payload');
    assert.equal(requestCount, 1);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('全モデルが混雑中なら日本語の再試行メッセージを返す', async () => {
  const originalFetch = globalThis.fetch;
  let requestCount = 0;
  globalThis.fetch = async () => {
    requestCount += 1;
    return Response.json(
      { error: { message: 'This model is currently experiencing high demand.' } },
      { status: 503 },
    );
  };

  try {
    const response = await worker.fetch(request(), {
      GEMINI_API_KEY: 'test-key',
      GEMINI_MODEL: 'gemini-3.8-flash',
      GEMINI_FALLBACK_MODELS: 'gemini-3.5-flash,gemini-3.5-flash-lite',
    });
    const body = await response.json();

    assert.equal(response.status, 503);
    assert.equal(
      body.error,
      'AIが混み合っています。少し待ってからもう一度お試しください。',
    );
    assert.equal(requestCount, 3);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('登録食品から期限切れを除外してレシピを生成する', async () => {
  const originalFetch = globalThis.fetch;
  let upstreamBody;
  globalThis.fetch = async (_url, init) => {
    upstreamBody = JSON.parse(init.body);
    return Response.json({
      candidates: [
        {
          content: {
            parts: [
              {
                text: JSON.stringify({
                  recipes: [
                    {
                      title: '豆腐のみそ炒め',
                      description: '期限の近い豆腐を使います。',
                      cookTimeMinutes: 15,
                      servings: '2人分',
                      ingredients: [
                        { name: '豆腐', amount: '1丁', available: true },
                        { name: 'みそ', amount: '大さじ1', available: true },
                      ],
                      steps: ['豆腐を切る', 'みそと炒める'],
                      usesRegisteredItems: ['豆腐', 'みそ'],
                      tip: '水切りすると崩れにくくなります。',
                    },
                  ],
                }),
              },
            ],
          },
        },
      ],
    });
  };

  try {
    const response = await worker.fetch(
      new Request('https://worker.test/suggest-recipes', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          items: [
            { name: '豆腐', category: '冷蔵品', daysRemaining: 1 },
            { name: 'みそ', category: '調味料', daysRemaining: 30 },
            { name: '古い牛乳', category: '飲み物', daysRemaining: -2 },
          ],
          preference: '15分以内',
          today: '2026-09-17',
        }),
      }),
      { GEMINI_API_KEY: 'test-key', GEMINI_MODEL: 'gemini-test' },
    );
    const body = await response.json();
    const prompt = upstreamBody.contents[0].parts[0].text;

    assert.equal(response.status, 200);
    assert.equal(body.recipes[0].title, '豆腐のみそ炒め');
    assert.match(prompt, /豆腐/);
    assert.match(prompt, /みそ/);
    assert.doesNotMatch(prompt, /古い牛乳/);
    assert.equal(upstreamBody.generationConfig.maxOutputTokens, 4096);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('登録食品と履歴を使ってAIシェフが回答する', async () => {
  const originalFetch = globalThis.fetch;
  let upstreamBody;
  globalThis.fetch = async (_url, init) => {
    upstreamBody = JSON.parse(init.body);
    return Response.json({
      candidates: [
        {
          content: {
            parts: [{ text: JSON.stringify({ reply: 'みそで味付けできます。' }) }],
          },
        },
      ],
    });
  };

  try {
    const response = await worker.fetch(
      new Request('https://worker.test/recipe-chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          items: [{ name: 'みそ', category: '調味料', daysRemaining: 30 }],
          messages: [{ role: 'user', text: 'しょうゆなしで作れる？' }],
          today: '2026-09-17',
        }),
      }),
      { GEMINI_API_KEY: 'test-key', GEMINI_MODEL: 'gemini-test' },
    );
    const body = await response.json();
    const prompt = upstreamBody.contents[0].parts[0].text;

    assert.equal(response.status, 200);
    assert.equal(body.reply, 'みそで味付けできます。');
    assert.match(prompt, /しょうゆなし/);
    assert.match(prompt, /みそ/);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('毎日の名言をGeminiで生成する', async () => {
  const originalFetch = globalThis.fetch;
  let upstreamBody;
  globalThis.fetch = async (_url, init) => {
    upstreamBody = JSON.parse(init.body);
    return Response.json({
      candidates: [
        {
          content: {
            parts: [
              {
                text: JSON.stringify({
                  quote: 'ひと皿を救う選択が、明日の食卓を少し豊かにする。',
                  note: '今日は期限の近いものを一つ、手前へ。',
                }),
              },
            ],
          },
        },
      ],
    });
  };

  try {
    const response = await worker.fetch(
      new Request('https://worker.test/daily-quote', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          today: '2026-09-18',
          activeCount: 4,
          rescuedCount: 12,
        }),
      }),
      { GEMINI_API_KEY: 'test-key', GEMINI_MODEL: 'gemini-test' },
    );
    const body = await response.json();
    const prompt = upstreamBody.contents[0].parts[0].text;

    assert.equal(response.status, 200);
    assert.match(body.quote, /ひと皿/);
    assert.match(body.note, /期限/);
    assert.match(prompt, /2026-09-18/);
    assert.match(prompt, /登録食品数: 4/);
    assert.match(prompt, /食べきった食品数: 12/);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
