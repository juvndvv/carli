import 'package:flutter/foundation.dart';

@immutable
class SearchResult {
  const SearchResult({
    required this.module,
    required this.type,
    required this.title,
    required this.url,
    this.moduleName,
    this.id,
    this.subtitle,
    this.icon,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    module: json['module'] as String? ?? '',
    moduleName: json['module_name'] as String?,
    type: json['type'] as String? ?? '',
    id: json['id']?.toString(),
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String?,
    url: json['url'] as String? ?? '/',
    icon: json['icon'] as String?,
  );

  final String module;
  final String? moduleName;
  final String type;
  final String? id;
  final String title;
  final String? subtitle;
  final String url;
  final String? icon;
}
