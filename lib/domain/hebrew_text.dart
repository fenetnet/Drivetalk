/// "ל" + "Dani" reads as "לDani". Hebrew writes a hyphen between a prefix
/// letter and a foreign word ("ל-Dani"), and the voice reads it better too.
/// Names often come from the phone's contacts, in English.
String joinHebrewPrefixes(String text) =>
    text.replaceAllMapped(_gluedPrefix, (m) => '${m[1]}${m[2]}-${m[3]}');

final _gluedPrefix = RegExp(r'(^|[\s"(״׳])([ובלמשהכ]{1,3})([A-Za-z0-9])');
