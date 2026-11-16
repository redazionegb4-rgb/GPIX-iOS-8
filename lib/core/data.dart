import 'dart:convert';

typedef J = Map<String, dynamic>;
J object(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};
List<J> objects(dynamic value) =>
    value is List ? value.map(object).toList() : <J>[];
List<String> strings(dynamic value) =>
    value is List ? value.map((e) => '$e').toList() : <String>[];

extension Json on Map<String, dynamic> {
  String str(String key, [String fallback = '']) =>
      this[key]?.toString() ?? fallback;
  bool flag(String key) => this[key] == true || this[key] == 1;
  double number(String key, [double fallback = 0]) =>
      this[key] is num ? (this[key] as num).toDouble() : fallback;
  J obj(String key) => object(this[key]);
  List<J> rows(String key) => objects(this[key]);
  List<String> ids(String key) => strings(this[key]);
}

int _sequence = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
double get now => DateTime.now().millisecondsSinceEpoch / 1000;
String relative(dynamic value) {
  final t = DateTime.fromMillisecondsSinceEpoch(
    ((value is num ? value : 0) * 1000).round(),
  );
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Ora';
  if (d.inHours < 1) return '${d.inMinutes} min';
  if (d.inDays < 1) return '${d.inHours} h';
  if (d.inDays < 7) return '${d.inDays} g';
  return '${t.day}/${t.month}/${t.year}';
}

String clock(dynamic value) {
  final t = DateTime.fromMillisecondsSinceEpoch(
    ((value is num ? value : 0) * 1000).round(),
  );
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

String stableJson(J data) => jsonEncode(data);
