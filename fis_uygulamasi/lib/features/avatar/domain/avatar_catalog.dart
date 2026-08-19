import 'package:flutter/material.dart';

import '../presentation/widgets/person_avatar_painter.dart';

class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.spec,
    required this.background,
  });

  final String id;
  final PersonAvatarSpec spec;
  final Color background;
}

// Skin tones.
const _skinLight = Color(0xFFF6D3B8);
const _skinMedium = Color(0xFFE8B48C);
const _skinTan = Color(0xFFC98B5E);
const _skinDeep = Color(0xFF8D5A3B);

// Hair colors.
const _hairBlack = Color(0xFF2B2320);
const _hairDarkBrown = Color(0xFF4A3222);
const _hairBrown = Color(0xFF6B4A2E);
const _hairBlonde = Color(0xFFE3C16F);
const _hairRed = Color(0xFFB5551F);
const _hairGray = Color(0xFFB7B0A8);

// Outfit colors.
const _navy = Color(0xFF2E3A59);
const _charcoal = Color(0xFF3B3F45);
const _forest = Color(0xFF2F5D50);
const _burgundy = Color(0xFF7A2E3B);
const _teal = Color(0xFF1F6F78);
const _mustard = Color(0xFFC98A1D);
const _plum = Color(0xFF5B3A6B);
const _terracotta = Color(0xFFC15A34);
const _slate = Color(0xFF48545C);
const _rose = Color(0xFFB5556B);

// Accent (tie / necklace) colors.
const _orange = Color(0xFFE07A2E);
const _gold = Color(0xFFD4AF37);
const _crimson = Color(0xFFB23A48);

// Keep the id set in sync with the backend allowlist:
// backend/app/auth_schemas.py -> ALLOWED_AVATAR_IDS
const avatarCatalog = <AvatarOption>[
  AvatarOption(
    id: 'man',
    background: Color(0xFFD5EBFC),
    spec: PersonAvatarSpec(
      skinTone: _skinLight,
      hairColor: _hairDarkBrown,
      hairStyle: HairStyle.short,
      outfitColor: _navy,
      outfitStyle: OutfitStyle.suit,
      accentColor: _orange,
    ),
  ),
  AvatarOption(
    id: 'woman',
    background: Color(0xFFFBE0EA),
    spec: PersonAvatarSpec(
      skinTone: _skinLight,
      hairColor: _hairBlack,
      hairStyle: HairStyle.bob,
      outfitColor: _burgundy,
      outfitStyle: OutfitStyle.dress,
      accentColor: _gold,
    ),
  ),
  AvatarOption(
    id: 'person',
    background: Color(0xFFDFF3EB),
    spec: PersonAvatarSpec(
      skinTone: _skinMedium,
      hairColor: _hairBrown,
      hairStyle: HairStyle.side,
      outfitColor: _teal,
      outfitStyle: OutfitStyle.blouse,
    ),
  ),
  AvatarOption(
    id: 'elder_woman',
    background: Color(0xFFF3E1FB),
    spec: PersonAvatarSpec(
      skinTone: _skinLight,
      hairColor: _hairGray,
      hairStyle: HairStyle.bob,
      outfitColor: _plum,
      outfitStyle: OutfitStyle.turtleneck,
    ),
  ),
  AvatarOption(
    id: 'elder_man',
    background: Color(0xFFE7ECEF),
    spec: PersonAvatarSpec(
      skinTone: _skinMedium,
      hairColor: _hairGray,
      hairStyle: HairStyle.bald,
      outfitColor: _charcoal,
      outfitStyle: OutfitStyle.suit,
      accentColor: _crimson,
    ),
  ),
  AvatarOption(
    id: 'curly_woman',
    background: Color(0xFFFFE9A8),
    spec: PersonAvatarSpec(
      skinTone: _skinTan,
      hairColor: _hairBlack,
      hairStyle: HairStyle.curly,
      outfitColor: _mustard,
      outfitStyle: OutfitStyle.casual,
    ),
  ),
  AvatarOption(
    id: 'curly_man',
    background: Color(0xFFDCE6E4),
    spec: PersonAvatarSpec(
      skinTone: _skinMedium,
      hairColor: _hairDarkBrown,
      hairStyle: HairStyle.curly,
      outfitColor: _forest,
      outfitStyle: OutfitStyle.suit,
      accentColor: _gold,
    ),
  ),
  AvatarOption(
    id: 'redhead_woman',
    background: Color(0xFFFFDAB3),
    spec: PersonAvatarSpec(
      skinTone: _skinLight,
      hairColor: _hairRed,
      hairStyle: HairStyle.long,
      outfitColor: _rose,
      outfitStyle: OutfitStyle.casual,
    ),
  ),
  AvatarOption(
    id: 'redhead_man',
    background: Color(0xFFD9E8FB),
    spec: PersonAvatarSpec(
      skinTone: _skinLight,
      hairColor: _hairRed,
      hairStyle: HairStyle.short,
      outfitColor: _slate,
      outfitStyle: OutfitStyle.suit,
      accentColor: _teal,
    ),
  ),
  AvatarOption(
    id: 'blonde_woman',
    background: Color(0xFFFFF1B8),
    spec: PersonAvatarSpec(
      skinTone: _skinLight,
      hairColor: _hairBlonde,
      hairStyle: HairStyle.long,
      outfitColor: _teal,
      outfitStyle: OutfitStyle.dress,
      accentColor: Color(0xFFA65D77),
    ),
  ),
  AvatarOption(
    id: 'blonde_man',
    background: Color(0xFFE3EAF0),
    spec: PersonAvatarSpec(
      skinTone: _skinMedium,
      hairColor: _hairBlonde,
      hairStyle: HairStyle.quiff,
      outfitColor: _terracotta,
      outfitStyle: OutfitStyle.casual,
    ),
  ),
  AvatarOption(
    id: 'bald_woman',
    background: Color(0xFFF6D9E6),
    spec: PersonAvatarSpec(
      skinTone: _skinTan,
      hairColor: _hairBlack,
      hairStyle: HairStyle.bald,
      outfitColor: _plum,
      outfitStyle: OutfitStyle.dress,
      accentColor: _gold,
    ),
  ),
  AvatarOption(
    id: 'bald_man',
    background: Color(0xFFD7F0E4),
    spec: PersonAvatarSpec(
      skinTone: _skinDeep,
      hairColor: _hairBlack,
      hairStyle: HairStyle.bald,
      outfitColor: _burgundy,
      outfitStyle: OutfitStyle.suit,
      accentColor: _orange,
    ),
  ),
  AvatarOption(
    id: 'bearded_man',
    background: Color(0xFFDDF0D2),
    spec: PersonAvatarSpec(
      skinTone: _skinMedium,
      hairColor: _hairBlack,
      hairStyle: HairStyle.short,
      outfitColor: _navy,
      outfitStyle: OutfitStyle.casual,
      hasBeard: true,
    ),
  ),
  AvatarOption(
    id: 'girl',
    background: Color(0xFFFFE1C2),
    spec: PersonAvatarSpec(
      skinTone: _skinLight,
      hairColor: _hairBrown,
      hairStyle: HairStyle.ponytail,
      outfitColor: _mustard,
      outfitStyle: OutfitStyle.casual,
    ),
  ),
  AvatarOption(
    id: 'boy',
    background: Color(0xFFE9E5FB),
    spec: PersonAvatarSpec(
      skinTone: _skinLight,
      hairColor: _hairBlonde,
      hairStyle: HairStyle.short,
      outfitColor: _teal,
      outfitStyle: OutfitStyle.casual,
    ),
  ),
];

AvatarOption? avatarById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final option in avatarCatalog) {
    if (option.id == id) return option;
  }
  return null;
}
