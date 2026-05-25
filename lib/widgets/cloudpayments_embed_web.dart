// lib/widgets/cloudpayments_embed_web.dart
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

typedef CloudPaymentsResultCallback =
    void Function(Map<String, dynamic> result);

class CloudPaymentsEmbed extends StatefulWidget {
  final double amount;
  final String description;
  final String externalId;
  final CloudPaymentsResultCallback onSuccess;
  final CloudPaymentsResultCallback onFail;

  const CloudPaymentsEmbed({
    required this.amount,
    required this.description,
    required this.externalId,
    required this.onSuccess,
    required this.onFail,
    Key? key,
  }) : super(key: key);

  @override
  State<CloudPaymentsEmbed> createState() => _CloudPaymentsEmbedState();
}

class _CloudPaymentsEmbedState extends State<CloudPaymentsEmbed> {
  late final String _viewType;
  late final StreamSubscription<html.MessageEvent> _messageSubscription;

  @override
  void initState() {
    super.initState();

    _viewType =
        'cloudpayments-widget-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';

    final frame =
        html.IFrameElement()
          ..srcdoc = _html()
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = 'transparent'
          ..allow = 'payment *; clipboard-write *; fullscreen *';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => frame,
    );

    _messageSubscription = html.window.onMessage.listen(_handleMessage);
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    super.dispose();
  }

  void _handleMessage(html.MessageEvent event) {
    final data = event.data;

    if (data is! String) return;

    Map<String, dynamic> payload;

    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) return;
      payload = decoded;
    } catch (_) {
      return;
    }

    if (payload['source'] != 'cloudpayments-widget') return;

    final status = payload['status']?.toString().toLowerCase();

    if (status == 'success') {
      widget.onSuccess(payload);
      return;
    }

    if (status == 'fail' || status == 'error' || status == 'cancel') {
      widget.onFail(payload);
    }
  }

  String _html() {
    final amountForWidget =
        widget.amount <= 0
            ? 1.0
            : double.parse(widget.amount.toStringAsFixed(2));

    final intentParams = {
      'publicTerminalId': 'test_api_00000000000000000000002',
      'description': widget.description,
      'paymentSchema': 'Single',
      'currency': 'RUB',
      'culture': 'ru-RU',
      'amount': amountForWidget,
      'skin': 'modern',
      'autoClose': 3,
      'cryptogramMode': false,
      'externalId': widget.externalId,
      'items': [
        {
          'id': widget.externalId,
          'name': widget.description,
          'count': 1,
          'price': amountForWidget,
        },
      ],
    };

    final paramsJson = jsonEncode(intentParams);
    final safeDescription = const HtmlEscape().convert(widget.description);
    final safeAmount = amountForWidget.toStringAsFixed(2);

    return '''
<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta
    name="viewport"
    content="width=device-width, initial-scale=1, maximum-scale=1"
  >
  <script src="https://widget.cloudpayments.ru/bundles/cloudpayments.js"></script>
  <style>
    html, body {
      margin: 0;
      padding: 0;
      min-height: 100%;
      background: transparent;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: #111827;
    }

    .shell {
      box-sizing: border-box;
      width: 100%;
      min-height: 680px;
      padding: 18px;
      background: #f8fafc;
      border-radius: 18px;
      border: 1px solid #e5e7eb;
    }

    .header {
      padding: 18px;
      border-radius: 16px;
      background: linear-gradient(135deg, #111827, #334155);
      color: white;
      margin-bottom: 16px;
    }

    .bank {
      font-size: 14px;
      opacity: .78;
      margin-bottom: 8px;
    }

    .title {
      font-size: 20px;
      font-weight: 700;
      line-height: 1.25;
      margin-bottom: 10px;
    }

    .amount {
      font-size: 34px;
      font-weight: 800;
      letter-spacing: -0.03em;
    }

    .card {
      padding: 16px;
      border-radius: 16px;
      background: white;
      border: 1px solid #e5e7eb;
      margin-bottom: 14px;
    }

    .muted {
      font-size: 14px;
      color: #64748b;
      line-height: 1.45;
    }

    .methods {
      display: grid;
      gap: 8px;
      margin: 12px 0 16px;
    }

    .method {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 14px;
      border-radius: 12px;
      background: #f1f5f9;
      border: 1px solid #e2e8f0;
      font-size: 15px;
      font-weight: 600;
    }

    .button {
      width: 100%;
      border: 0;
      border-radius: 14px;
      background: #111827;
      color: white;
      padding: 15px 18px;
      font-size: 16px;
      font-weight: 700;
      cursor: pointer;
    }

    .button:disabled {
      opacity: .6;
      cursor: default;
    }

    .footer {
      margin-top: 12px;
      font-size: 12px;
      color: #64748b;
      text-align: center;
      line-height: 1.4;
    }

    .error {
      display: none;
      margin-top: 10px;
      padding: 10px;
      border-radius: 10px;
      background: #fee2e2;
      color: #991b1b;
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="shell">
    <div class="header">
      <div class="bank">CloudPayments · тестовый терминал</div>
      <div class="title">$safeDescription</div>
      <div class="amount">$safeAmount ₽</div>
    </div>

    <div class="card">
      <div class="muted">
        Нажмите кнопку ниже, чтобы открыть реальную тестовую платёжную форму
        CloudPayments. Деньги в тестовом терминале не списываются.
      </div>

      <div class="methods">
        <div class="method">
          <span>Банковская карта</span>
          <span>МИР / Visa / Mastercard</span>
        </div>
        <div class="method">
          <span>Мобильная форма</span>
          <span>адаптивный iframe</span>
        </div>
      </div>

      <button id="payButton" class="button" onclick="startPayment()">
        Открыть платёжную форму
      </button>

      <div id="errorBox" class="error"></div>
    </div>

    <div class="footer">
      Учебная интеграция: результат успешного тестового платежа будет записан
      в PocketBase как подтверждённая оплата.
    </div>
  </div>

  <script>
    const intentParams = $paramsJson;

    function post(payload) {
      window.parent.postMessage(
        JSON.stringify(Object.assign({ source: 'cloudpayments-widget' }, payload)),
        '*'
      );
    }

    function showError(message) {
      const box = document.getElementById('errorBox');
      box.style.display = 'block';
      box.textContent = message;
    }

    function setLoading(value) {
      const button = document.getElementById('payButton');
      button.disabled = value;
      button.textContent = value ? 'Открываем форму...' : 'Открыть платёжную форму';
    }

    function startPayment() {
      try {
        if (!window.cp || !window.cp.CloudPayments) {
          showError('CloudPayments script ещё не загрузился. Повторите через секунду.');
          return;
        }

        setLoading(true);

        const widget = new cp.CloudPayments();

        widget.start(intentParams)
          .then(function(result) {
            setLoading(false);

            const status = result && result.status ? result.status : 'unknown';

            post({
              status: status,
              result: result || null
            });

            if (status !== 'success') {
              showError('Платёж не подтверждён. Статус: ' + status);
            }
          })
          .catch(function(error) {
            setLoading(false);

            const message =
              error && error.message ? error.message : String(error || 'Ошибка оплаты');

            showError(message);

            post({
              status: 'fail',
              message: message
            });
          });
      } catch (error) {
        setLoading(false);

        const message = error && error.message ? error.message : String(error);

        showError(message);

        post({
          status: 'error',
          message: message
        });
      }
    }
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
