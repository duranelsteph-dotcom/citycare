String normalizeHelpSpeech(String raw) {
  var text = raw.toLowerCase().trim();
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    "'": ' ',
    '’': ' ',
    '-': ' ',
  };
  accents.forEach((from, to) {
    text = text.replaceAll(from, to);
  });
  text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool matchesHelpPhrase(String transcript) {
  final text = normalizeHelpSpeech(transcript);
  if (text.isEmpty) {
    return false;
  }
  const phrases = [
    'au secours',
    'a l aide',
    'a laide',
    'aide moi',
    'aidez moi',
    'sos',
  ];
  for (final phrase in phrases) {
    if (text == phrase || text.contains(phrase)) {
      return true;
    }
  }
  return false;
}
