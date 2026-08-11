import '../domain/group_models.dart';

class FastSplitShare {
  const FastSplitShare({required this.userId, required this.amountInMinor});

  final String userId;
  final int amountInMinor;
}

class FastSplitCalculation {
  const FastSplitCalculation({
    required this.type,
    required this.totalAmountInMinor,
    required this.shares,
  });

  final SplitType type;
  final int totalAmountInMinor;
  final List<FastSplitShare> shares;

  int get allocatedAmountInMinor =>
      shares.fold<int>(0, (total, share) => total + share.amountInMinor);

  int get differenceInMinor => totalAmountInMinor - allocatedAmountInMinor;

  bool get isBalanced => differenceInMinor == 0;
}

class FastSplitCalculator {
  const FastSplitCalculator._();

  static FastSplitCalculation equal({
    required int totalAmountInMinor,
    required List<String> memberIds,
  }) {
    _validateTotalAndMembers(totalAmountInMinor, memberIds);
    final baseShare = totalAmountInMinor ~/ memberIds.length;
    final remainder = totalAmountInMinor.remainder(memberIds.length);

    return FastSplitCalculation(
      type: SplitType.equal,
      totalAmountInMinor: totalAmountInMinor,
      shares: <FastSplitShare>[
        for (var index = 0; index < memberIds.length; index += 1)
          FastSplitShare(
            userId: memberIds[index],
            amountInMinor: baseShare + (index < remainder ? 1 : 0),
          ),
      ],
    );
  }

  static FastSplitCalculation percentage({
    required int totalAmountInMinor,
    required List<String> memberIds,
    required Map<String, int> percentageBasisPoints,
  }) {
    _validateTotalAndMembers(totalAmountInMinor, memberIds);
    _validateShareKeys(memberIds, percentageBasisPoints.keys);
    if (percentageBasisPoints.values.any(
      (basisPoints) => basisPoints < 0 || basisPoints > 10000,
    )) {
      throw const FormatException(
        'Yüzde payları 0 ile 10.000 basis point arasında olmalıdır.',
      );
    }
    final totalBasisPoints = memberIds.fold<int>(
      0,
      (total, id) => total + (percentageBasisPoints[id] ?? 0),
    );
    if (totalBasisPoints != 10000) {
      throw const FormatException('Yüzdelerin toplamı %100 olmalıdır.');
    }

    final rawShares = <int>[
      for (final id in memberIds)
        (totalAmountInMinor * (percentageBasisPoints[id] ?? 0)) ~/ 10000,
    ];
    var remainder =
        totalAmountInMinor - rawShares.fold<int>(0, (a, b) => a + b);
    for (var index = 0; remainder > 0; index = (index + 1) % rawShares.length) {
      if ((percentageBasisPoints[memberIds[index]] ?? 0) > 0) {
        rawShares[index] += 1;
        remainder -= 1;
      }
    }

    return FastSplitCalculation(
      type: SplitType.percentage,
      totalAmountInMinor: totalAmountInMinor,
      shares: <FastSplitShare>[
        for (var index = 0; index < memberIds.length; index += 1)
          FastSplitShare(
            userId: memberIds[index],
            amountInMinor: rawShares[index],
          ),
      ],
    );
  }

  static FastSplitCalculation fixedAmount({
    required int totalAmountInMinor,
    required List<String> memberIds,
    required Map<String, int> amountsInMinor,
  }) {
    _validateTotalAndMembers(totalAmountInMinor, memberIds);
    _validateShareKeys(memberIds, amountsInMinor.keys);
    if (amountsInMinor.values.any((amount) => amount < 0)) {
      throw const FormatException('Sabit pay tutarı negatif olamaz.');
    }
    return FastSplitCalculation(
      type: SplitType.fixedAmount,
      totalAmountInMinor: totalAmountInMinor,
      shares: <FastSplitShare>[
        for (final id in memberIds)
          FastSplitShare(userId: id, amountInMinor: amountsInMinor[id] ?? 0),
      ],
    );
  }

  static void _validateTotalAndMembers(int total, List<String> memberIds) {
    if (total <= 0) {
      throw const FormatException('Toplam tutar sıfırdan büyük olmalıdır.');
    }
    if (memberIds.isEmpty) {
      throw const FormatException('En az bir katılımcı seçilmelidir.');
    }
    if (memberIds.any((id) => id.trim().isEmpty)) {
      throw const FormatException('Katılımcı kimliği boş olamaz.');
    }
    if (memberIds.toSet().length != memberIds.length) {
      throw const FormatException('Katılımcı kimlikleri tekrarlanamaz.');
    }
  }

  static void _validateShareKeys(
    List<String> memberIds,
    Iterable<String> shareUserIds,
  ) {
    final selectedMembers = memberIds.toSet();
    if (shareUserIds.any((id) => !selectedMembers.contains(id))) {
      throw const FormatException(
        'Seçili olmayan katılımcı için pay girilemez.',
      );
    }
  }
}
