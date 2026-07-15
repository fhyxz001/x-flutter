/// 代理方案
///
/// 对应 Android 端 `ProxyScheme`。
class ProxyScheme {
  final String id;
  final String name;
  final String host;
  final int port;

  ProxyScheme({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
  });

  factory ProxyScheme.fromJson(Map<String, dynamic> json) {
    return ProxyScheme(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
      };
}

/// 代理配置
///
/// 对应 Android 端 `ProxyConfig`。
class ProxyConfig {
  final bool enabled;
  final List<ProxyScheme> schemes;
  final String selectedId;

  ProxyConfig({
    this.enabled = false,
    this.schemes = const [],
    this.selectedId = '',
  });

  ProxyConfig copyWith({
    bool? enabled,
    List<ProxyScheme>? schemes,
    String? selectedId,
  }) {
    return ProxyConfig(
      enabled: enabled ?? this.enabled,
      schemes: schemes ?? this.schemes,
      selectedId: selectedId ?? this.selectedId,
    );
  }

  factory ProxyConfig.fromJson(Map<String, dynamic> json) {
    return ProxyConfig(
      enabled: json['enabled'] as bool? ?? false,
      schemes: (json['schemes'] as List<dynamic>?)
              ?.map((e) => ProxyScheme.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      selectedId: json['selectedId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'schemes': schemes.map((e) => e.toJson()).toList(),
        'selectedId': selectedId,
      };
}
