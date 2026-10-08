/// **Les liens d'un texte de message** — l'onglet « Liens » de « Médias, liens
/// et docs ».
///
/// Seules les adresses `http(s)://` explicites comptent : un nom de domaine nu
/// (« eglise.fr ») ou une adresse électronique ne sont pas des liens ici, comme
/// dans WhatsApp où l'onglet ne liste que ce qui s'ouvre au navigateur.
library;

final RegExp _candidate = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

/// Ce qui termine une phrase plutôt qu'une adresse.
const String _trailing = '.,;:!?\'"»…';

/// Les adresses `http(s)` de [text], dans l'ordre, doublons compris.
///
/// La ponctuation finale (« voir https://a.fr/x. ») est retirée, et une
/// parenthèse ou un crochet fermant ne reste que s'il referme une ouverture de
/// l'adresse elle-même (`https://fr.wikipedia.org/wiki/Foi_(théologie)`).
List<String> extractLinks(String? text) {
  if (text == null || !text.toLowerCase().contains('http')) return const [];
  final links = <String>[];
  for (final match in _candidate.allMatches(text)) {
    var url = match[0]!;
    while (url.isNotEmpty) {
      final last = url[url.length - 1];
      if (_trailing.contains(last) ||
          (last == ')' && _count(url, '(') < _count(url, ')')) ||
          (last == ']' && _count(url, '[') < _count(url, ']'))) {
        url = url.substring(0, url.length - 1);
      } else {
        break;
      }
    }
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.contains('.') || host == 'localhost') links.add(url);
  }
  return links;
}

int _count(String s, String char) => char.allMatches(s).length;
