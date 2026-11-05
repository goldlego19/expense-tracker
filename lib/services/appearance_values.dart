/// Parse an opaque RGB accent; other lengths/alpha values are rejected.
int? parseAccentHex(String value) {
  final hex = value.trim().replaceFirst(RegExp(r'^#'), '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return 0xff000000 | int.parse(hex, radix: 16);
}

String accentHex(int argb) =>
    '#${(argb & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';
