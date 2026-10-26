import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/dates.dart';
import 'finance_changes.dart';
import 'json.dart';
import 'models.dart';

const homeCountry = 'ES';
const bankCallbackScheme = 'carli';
const expiryWarningDays = 7;
const newAccountTarget = 'new';
const syncPollInterval = Duration(seconds: 3);
const syncPollAttempts = 10;

final extraAspsps = [(country: 'LT', pattern: RegExp('revolut', caseSensitive: false))];

const bankCallbackErrors = {
  'cancelado': 'Has cancelado la autorización en el banco. No se ha conectado nada.',
  'estado': 'El enlace de vuelta del banco ha caducado o ya se había usado. Vuelve a intentarlo.',
  'proveedor': 'El banco no ha podido completar la conexión. Inténtalo de nuevo en unos minutos.',
};

enum BankConnectionStatus {
  active,
  expired,
  revoked,
  error;

  static BankConnectionStatus of(String? value) =>
      values.firstWhere((status) => status.name == value, orElse: () => BankConnectionStatus.active);
}

class Aspsp {
  const Aspsp({required this.name, required this.country, required this.logo, required this.consentDays});

  factory Aspsp.fromJson(Json json) => Aspsp(
    name: json['name'] as String,
    country: json['country'] as String,
    logo: json['logo'] as String?,
    consentDays: intOf(json['consent_days']),
  );

  final String name;
  final String country;
  final String? logo;
  final int consentDays;
}

class BankLinkedAccount {
  const BankLinkedAccount({required this.id, required this.name, required this.syncFromDate});

  factory BankLinkedAccount.fromJson(Json json) => BankLinkedAccount(
    id: json['id'] as String,
    name: json['name'] as String,
    syncFromDate: parseIsoDateOrNull(json['sync_from_date']),
  );

  final String id;
  final String name;
  final DateTime? syncFromDate;
}

class BankConnection {
  const BankConnection({
    required this.id,
    required this.aspspName,
    required this.status,
    required this.expiresInDays,
    required this.lastSyncedAt,
    required this.lastError,
    required this.linkedAccounts,
    this.lastSyncTransfers = 0,
  });

  factory BankConnection.fromJson(Json json) => BankConnection(
    id: json['id'] as String,
    aspspName: json['aspsp_name'] as String,
    status: BankConnectionStatus.of(json['status'] as String?),
    expiresInDays: intOf(json['expires_in_days']),
    lastSyncedAt: json['last_synced_at'] is String ? DateTime.parse(json['last_synced_at'] as String).toLocal() : null,
    lastError: json['last_error'] as String?,
    linkedAccounts: parseList(json['linked_accounts'], BankLinkedAccount.fromJson),
    lastSyncTransfers: intOf(json['last_sync_transfers']),
  );

  final String id;
  final String aspspName;
  final BankConnectionStatus status;
  final int expiresInDays;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final List<BankLinkedAccount> linkedAccounts;
  final int lastSyncTransfers;
}

class BankAccountCandidate {
  const BankAccountCandidate({
    required this.externalAccountUid,
    required this.name,
    required this.iban,
    required this.currency,
    required this.suggestedAccountType,
    required this.linkedAccountId,
    required this.linkedAccountName,
    required this.linkedSyncFromDate,
  });

  factory BankAccountCandidate.fromJson(Json json) {
    final linked = json['linked_account'] as Json?;
    return BankAccountCandidate(
      externalAccountUid: json['external_account_uid'] as String,
      name: json['name'] as String?,
      iban: json['iban'] as String?,
      currency: json['currency'] as String?,
      suggestedAccountType: accountTypeOf(json['suggested_account_type'] as String?),
      linkedAccountId: linked?['id'] as String?,
      linkedAccountName: linked?['name'] as String?,
      linkedSyncFromDate: parseIsoDateOrNull(linked?['sync_from_date']),
    );
  }

  final String externalAccountUid;
  final String? name;
  final String? iban;
  final String? currency;
  final AccountType suggestedAccountType;
  final String? linkedAccountId;
  final String? linkedAccountName;
  final DateTime? linkedSyncFromDate;
}

class CategoryRule {
  const CategoryRule({
    required this.id,
    required this.pattern,
    required this.income,
    required this.categoryId,
    required this.category,
  });

  factory CategoryRule.fromJson(Json json) => CategoryRule(
    id: json['id'] as String,
    pattern: json['pattern'] as String,
    income: json['kind'] == 'income',
    categoryId: json['category_id'] as String,
    category: json['category'] is Json ? CategorySummary.fromJson(json['category'] as Json) : null,
  );

  final String id;
  final String pattern;
  final bool income;
  final String categoryId;
  final CategorySummary? category;

  String categoryLabel(String? parentName) {
    final category = this.category;
    final name = category == null
        ? 'Categoría eliminada'
        : (parentName == null ? category.name : '$parentName › ${category.name}');
    return income ? '$name · ingreso' : name;
  }
}

typedef BankConnectionState = ({String label, BankTone tone, bool canSync, bool canRenew});

enum BankTone { positive, warning, negative, neutral }

String expiresInLabel(int days) => days <= 0 ? 'Caduca hoy' : (days == 1 ? 'Caduca mañana' : 'Caduca en $days días');

BankConnectionState bankConnectionState(BankConnection connection) => switch (connection.status) {
  BankConnectionStatus.expired => (label: 'Caducada', tone: BankTone.negative, canSync: false, canRenew: true),
  BankConnectionStatus.revoked => (label: 'Desconectada', tone: BankTone.neutral, canSync: false, canRenew: false),
  BankConnectionStatus.error => (label: 'Error', tone: BankTone.negative, canSync: true, canRenew: true),
  BankConnectionStatus.active =>
    connection.expiresInDays <= expiryWarningDays
        ? (label: expiresInLabel(connection.expiresInDays), tone: BankTone.warning, canSync: true, canRenew: true)
        : (label: 'Activa', tone: BankTone.positive, canSync: true, canRenew: true),
};

String formatDateTime(DateTime value, {DateTime? now}) {
  final reference = today(now);
  final day = dateOnly(value);
  final time = '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  if (day == reference) return 'hoy a las $time';
  if (daysBetween(day, reference) == 1) return 'ayer a las $time';
  return '${formatShortDate(day, withYear: day.year != reference.year)}, $time';
}

String lastSyncLabel(BankConnection connection, {DateTime? now}) => connection.lastSyncedAt == null
    ? 'Aún no se ha sincronizado'
    : 'Sincronizado ${formatDateTime(connection.lastSyncedAt!, now: now)}';

String linkedAccountLabel(BankLinkedAccount account) => account.syncFromDate == null
    ? account.name
    : '${account.name} · desde el ${formatShortDate(account.syncFromDate!, withYear: true)}';

String _normalize(String text) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n', 'à': 'a', 'è': 'e', 'ò': 'o'};
  return text.toLowerCase().split('').map((char) => accents[char] ?? char).join();
}

bool matchesAspsp(Aspsp aspsp, String query) => _normalize(aspsp.name).contains(_normalize(query.trim()));

String aspspSubtitle(Aspsp aspsp) {
  final consent = 'Permiso de ${aspsp.consentDays} días';
  return aspsp.country == homeCountry ? consent : '${aspsp.country} · $consent';
}

List<Aspsp> mergeAspsps(List<Aspsp> home, List<Aspsp> extra) {
  final seen = {for (final aspsp in home) '${aspsp.country}:${aspsp.name}'};
  return [...home, ...extra.where((aspsp) => !seen.contains('${aspsp.country}:${aspsp.name}'))]
    ..sort((left, right) => _normalize(left.name).compareTo(_normalize(right.name)));
}

String? maskIban(String? iban) {
  if (iban == null || iban.isEmpty) return null;
  final compact = iban.replaceAll(RegExp(r'\s+'), '');
  return compact.length <= 4 ? compact : '•••• ${compact.substring(compact.length - 4)}';
}

String candidateTitle(BankAccountCandidate candidate) {
  final name = candidate.name?.trim();
  return name == null || name.isEmpty ? candidate.suggestedAccountType.label : name;
}

String candidateSubtitle(BankAccountCandidate candidate) => [
  maskIban(candidate.iban),
  candidate.currency,
  if (candidate.linkedAccountName != null) 'vinculada a ${candidate.linkedAccountName}',
].whereType<String>().join(' · ');

bool isEuroAccount(BankAccountCandidate candidate) =>
    candidate.currency == null || candidate.currency!.toUpperCase() == 'EUR';

String defaultNewAccountName(String bank, BankAccountCandidate candidate) {
  final name = candidate.name?.trim();
  return name != null && name.isNotEmpty
      ? '$bank $name'
      : '$bank ${candidate.suggestedAccountType.label.toLowerCase()}';
}

Set<String> duplicateTargets(List<String?> targets) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final target in targets) {
    if (target == null || target == newAccountTarget) continue;
    if (!seen.add(target)) duplicates.add(target);
  }
  return duplicates;
}

String syncedMessage(BankConnection connection) => switch (connection.lastSyncTransfers) {
  0 => '${connection.aspspName} sincronizado',
  1 => '${connection.aspspName} sincronizado · 1 transferencia entre tus cuentas detectada',
  final count => '${connection.aspspName} sincronizado · $count transferencias entre tus cuentas detectadas',
};

bool syncFinished(BankConnection before, BankConnection after) =>
    after.lastSyncedAt != before.lastSyncedAt || after.status != before.status || after.lastError != before.lastError;

sealed class BankAuthResult {
  const BankAuthResult();

  static BankAuthResult fromCallback(String url) {
    final uri = Uri.parse(url);
    final error = uri.queryParameters['error'];
    if (error != null) return BankAuthFailed(error);
    final connection = uri.queryParameters['connection'];
    if (connection == null) return const BankAuthFailed('estado');
    return BankAuthCompleted(connection, renewed: uri.queryParameters['renovado'] == '1');
  }
}

final class BankAuthCompleted extends BankAuthResult {
  const BankAuthCompleted(this.connectionId, {required this.renewed});

  final String connectionId;
  final bool renewed;
}

final class BankAuthFailed extends BankAuthResult {
  const BankAuthFailed(this.reason);

  final String reason;

  String get message => bankCallbackErrors[reason] ?? 'No se ha podido conectar el banco. Vuelve a intentarlo.';
}

final class BankAuthCancelled extends BankAuthResult {
  const BankAuthCancelled();
}

abstract interface class BankAuthenticator {
  Future<BankAuthResult> authorize(String url);
}

class WebAuthBankAuthenticator implements BankAuthenticator {
  const WebAuthBankAuthenticator();

  @override
  Future<BankAuthResult> authorize(String url) async {
    try {
      return BankAuthResult.fromCallback(
        await FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: bankCallbackScheme),
      );
    } on PlatformException catch (error) {
      return error.code == 'CANCELED' ? const BankAuthCancelled() : const BankAuthFailed('proveedor');
    }
  }
}

final bankAuthenticatorProvider = Provider<BankAuthenticator>((ref) => const WebAuthBankAuthenticator());

final bankApiProvider = Provider<BankApi>((ref) => BankApi(ref.watch(dioProvider)));

class BankApi {
  BankApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/finance';

  Future<List<BankConnection>> connections() async {
    final response = await _dio.get<Json>('$_base/bank/connections');
    return parseList(response.data!['data'], BankConnection.fromJson);
  }

  Future<BankConnection> connection(String id) async {
    final response = await _dio.get<Json>('$_base/bank/connections/$id');
    return BankConnection.fromJson(response.data!['data'] as Json);
  }

  Future<List<Aspsp>> aspsps(String country) async {
    final response = await _dio.get<Json>('$_base/bank/aspsps', queryParameters: {'country': country});
    return parseList(response.data!['data'], Aspsp.fromJson);
  }

  Future<String> connect(Aspsp aspsp) async {
    final response = await _dio.post<Json>(
      '$_base/bank/connections',
      data: {'aspsp_name': aspsp.name, 'aspsp_country': aspsp.country, 'return_to': 'app'},
    );
    return (response.data!['data'] as Json)['auth_url'] as String;
  }

  Future<String> renew(String id) async {
    final response = await _dio.post<Json>('$_base/bank/connections/$id/renew', data: {'return_to': 'app'});
    return (response.data!['data'] as Json)['auth_url'] as String;
  }

  Future<List<BankAccountCandidate>> bankAccounts(String id) async {
    final response = await _dio.get<Json>('$_base/bank/connections/$id/accounts');
    return parseList(response.data!['data'], BankAccountCandidate.fromJson);
  }

  Future<BankConnection> link(String id, List<Json> accounts) async {
    final response = await _dio.post<Json>('$_base/bank/connections/$id/accounts', data: {'accounts': accounts});
    return BankConnection.fromJson(response.data!['data'] as Json);
  }

  Future<bool> sync(String id) async {
    final response = await _dio.post<Json>('$_base/bank/connections/$id/sync', data: const <String, Object>{});
    return (response.data!['data'] as Json)['queued'] == true;
  }

  Future<void> disconnect(String id) => _dio.delete<void>('$_base/bank/connections/$id');

  Future<List<CategoryRule>> rules() async {
    final response = await _dio.get<Json>('$_base/category-rules');
    return parseList(response.data!['data'], CategoryRule.fromJson);
  }

  Future<CategoryRule> createRule(String pattern, String categoryId) async {
    final response = await _dio.post<Json>(
      '$_base/category-rules',
      data: {'pattern': pattern, 'category_id': categoryId},
    );
    return CategoryRule.fromJson(response.data!['data'] as Json);
  }

  Future<void> deleteRule(String id) => _dio.delete<void>('$_base/category-rules/$id');

  Future<int> similarCount(String transactionId) async {
    final response = await _dio.get<Json>('$_base/transactions/$transactionId/similar');
    return intOf((response.data!['data'] as Json)['count']);
  }

  Future<({int updated, String? pattern})> categorizeSimilar(String transactionId, String categoryId) async {
    final response = await _dio.post<Json>(
      '$_base/transactions/$transactionId/categorize-similar',
      data: {'category_id': categoryId, 'remember': true},
    );
    final data = response.data!['data'] as Json;
    return (updated: intOf(data['updated']), pattern: (data['rule'] as Json?)?['pattern'] as String?);
  }
}

final bankConnectionsProvider = FutureProvider<List<BankConnection>>((ref) async {
  ref.watchFinance(const [FinanceScope.bank]);
  return ref.watch(bankApiProvider).connections();
});

final categoryRulesProvider = FutureProvider<List<CategoryRule>>((ref) async {
  ref.watchFinance(const [FinanceScope.rules, FinanceScope.categories]);
  return ref.watch(bankApiProvider).rules();
});

final bankRepositoryProvider = Provider<BankRepository>(
  (ref) => BankRepository(ref.watch(bankApiProvider), ref.read(financeChangesProvider.notifier)),
);

class BankRepository {
  BankRepository(this._api, this._changes, {this.pollInterval = syncPollInterval});

  final BankApi _api;
  final FinanceChanges _changes;
  final Duration pollInterval;

  Future<List<Aspsp>> aspsps() async {
    final (home, extras) = await (
      _api.aspsps(homeCountry),
      Future.wait([
        for (final extra in extraAspsps)
          _api
              .aspsps(extra.country)
              .then(
                (list) => [
                  for (final aspsp in list)
                    if (extra.pattern.hasMatch(aspsp.name)) aspsp,
                ],
                onError: (_) => <Aspsp>[],
              ),
      ]),
    ).wait;
    return mergeAspsps(home, [for (final list in extras) ...list]);
  }

  Future<String> connect(Aspsp aspsp) => _api.connect(aspsp);

  Future<String> renew(String id) => _api.renew(id);

  Future<BankConnection> connection(String id) => _api.connection(id);

  Future<List<BankAccountCandidate>> bankAccounts(String id) => _api.bankAccounts(id);

  Future<BankConnection> link(String id, List<Json> accounts) async {
    final connection = await _api.link(id, accounts);
    _changes.notify(const [FinanceScope.bank, FinanceScope.accounts]);
    return connection;
  }

  Future<bool> sync(String id) => _api.sync(id);

  Future<void> disconnect(String id) async {
    await _api.disconnect(id);
    _changes.notify(const [FinanceScope.bank, FinanceScope.accounts, FinanceScope.transactions]);
  }

  Future<BankConnection?> awaitSync(BankConnection before, {bool Function()? active}) async {
    for (var attempt = 0; attempt < syncPollAttempts && (active?.call() ?? true); attempt++) {
      await Future<void>.delayed(pollInterval);
      final BankConnection current;
      try {
        current = await _api.connection(before.id);
      } on Object {
        continue;
      }
      if (syncFinished(before, current)) {
        synced();
        return current;
      }
    }
    synced();
    return null;
  }

  void synced() {
    _changes.notify(const [FinanceScope.bank]);
    _changes.notifyTransactions();
  }

  Future<void> deleteRule(String id) async {
    await _api.deleteRule(id);
    _changes.notify(const [FinanceScope.rules]);
  }

  Future<void> createRule(String pattern, String categoryId) async {
    await _api.createRule(pattern, categoryId);
    _changes.notify(const [FinanceScope.rules]);
  }

  Future<int> similarCount(String transactionId) => _api.similarCount(transactionId);

  Future<({int updated, String? pattern})> categorizeSimilar(String transactionId, String categoryId) async {
    final result = await _api.categorizeSimilar(transactionId, categoryId);
    _changes.notify(const [FinanceScope.rules]);
    _changes.notifyTransactions();
    return result;
  }
}
