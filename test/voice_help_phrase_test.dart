import 'package:citycare/domain/voice_help_phrase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches French help phrases after accent stripping', () {
    expect(matchesHelpPhrase('Au secours !'), isTrue);
    expect(matchesHelpPhrase('à l’aide'), isTrue);
    expect(matchesHelpPhrase('AIDE-MOI'), isTrue);
    expect(matchesHelpPhrase('SOS'), isTrue);
    expect(matchesHelpPhrase('bonjour'), isFalse);
    expect(matchesHelpPhrase(''), isFalse);
  });
}
