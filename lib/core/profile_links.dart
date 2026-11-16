import 'data.dart';

const socialNames = <String, String>{
  'instagram': 'Instagram',
  'facebook': 'Facebook',
  'threads': 'Threads',
  'whatsapp': 'WhatsApp',
  'telegram': 'Telegram',
  'tiktok': 'TikTok',
  'youtube': 'YouTube',
  'x': 'X',
  'website': 'Sito web',
};
J socialLink(String type, String raw, String title) {
  if (!socialNames.containsKey(type))
    throw const FormatException('Scegli un social.');
  var value = raw.trim();
  if (type == 'website') {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty || value.length > 500 || RegExp(r'\s').hasMatch(value)) {
      throw const FormatException('Inserisci un indirizzo HTTPS valido, ad esempio https://esempio.it.');
    }
    return {'type': type, 'value': value, 'url': value, 'title': title.trim().isEmpty ? (uri.host.length>60 ? uri.host.substring(0,60) : uri.host) : title.trim()};
  }
  if (type == 'whatsapp') {
    value = value.replaceAll(RegExp(r'[\s()+-]'), '');
    if (!RegExp(r'^[1-9][0-9]{6,14}$').hasMatch(value))
      throw const FormatException(
        'Inserisci il numero completo di prefisso internazionale.',
      );
  } else {
    value = value.replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[a-zA-Z0-9_.-]{1,80}$').hasMatch(value))
      throw const FormatException(
        'Inserisci lo username o ID del profilo, senza indirizzi web.',
      );
  }
  final urls = {
    'instagram': 'https://www.instagram.com/$value/',
    'facebook': 'https://www.facebook.com/$value',
    'threads': 'https://www.threads.com/@$value',
    'whatsapp': 'https://wa.me/$value',
    'telegram': 'https://t.me/$value',
    'tiktok': 'https://www.tiktok.com/@$value',
    'youtube': 'https://www.youtube.com/@$value',
    'x': 'https://x.com/$value',
  };
  return {
    'type': type,
    'value': value,
    'title': title.trim().isEmpty
        ? (type == 'whatsapp' ? '+$value' : value)
        : title.trim(),
    'url': urls[type],
  };
}

Uri profileAppUri(J link) {
  final value = link.str('value');
  return Uri.parse(switch (link.str('type')) {
    'whatsapp' => 'whatsapp://send?phone=$value',
    'telegram' => 'tg://resolve?domain=$value',
    'instagram' => 'instagram://user?username=$value',
    'x' => 'twitter://user?screen_name=$value',
    'facebook' when RegExp(r'^[0-9]+$').hasMatch(value) =>
      'fb://profile/$value',
    _ => link.str('url'),
  });
}

J resolveSocialLink(J link) {
  if (link.str('type').isNotEmpty) return link;
  final uri = Uri.tryParse(link.str('url'));
  if (uri == null || uri.scheme != 'https') return link;
  final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
  final type = const {
    'instagram.com': 'instagram',
    'facebook.com': 'facebook',
    'm.facebook.com': 'facebook',
    'threads.net': 'threads',
    'threads.com': 'threads',
    'wa.me': 'whatsapp',
    't.me': 'telegram',
    'tiktok.com': 'tiktok',
    'youtube.com': 'youtube',
    'x.com': 'x',
    'twitter.com': 'x',
  }[host];
  if (type == null) {try {return socialLink('website', link.str('url'), link.str('title'));} on FormatException {return link;}}
  if (uri.pathSegments.isEmpty) return link;
  var value = uri.pathSegments.first;
  if (type == 'facebook' && value == 'profile.php')
    value = uri.queryParameters['id'] ?? '';
  try {
    return socialLink(type, value, link.str('title'));
  } on FormatException {
    return link;
  }
}
