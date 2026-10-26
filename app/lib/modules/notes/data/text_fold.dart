const _plain = 'aaaaeeeeiiiioooouuuunc';
const _accented = 'áàäâéèëêíìïîóòöôúùüûñç';

/// Lower case without accents and with single spaces, for matching typed text against stored names.
String fold(String value) {
  final buffer = StringBuffer();
  for (final char in value.toLowerCase().trim().split('')) {
    final index = _accented.indexOf(char);
    buffer.write(index < 0 ? char : _plain[index]);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

bool foldedContains(String haystack, String needle) {
  final words = fold(needle).split(' ').where((word) => word.isNotEmpty);
  final folded = fold(haystack);
  return words.every(folded.contains);
}
