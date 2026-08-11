List<int> splitEqualInMinor(int totalInMinor, int participantCount) {
  if (totalInMinor < 0 || participantCount <= 0) {
    throw ArgumentError('Tutar negatif, katılımcı sayısı sıfır olamaz.');
  }
  final base = totalInMinor ~/ participantCount;
  final remainder = totalInMinor % participantCount;
  return List<int>.generate(
    participantCount,
    (index) => base + (index < remainder ? 1 : 0),
    growable: false,
  );
}

List<int> splitByBasisPointsInMinor(int totalInMinor, List<int> basisPoints) {
  if (totalInMinor < 0 ||
      basisPoints.isEmpty ||
      basisPoints.any((value) => value < 0) ||
      basisPoints.fold<int>(0, (sum, value) => sum + value) != 10000) {
    throw ArgumentError('Yüzdelerin toplamı tam olarak %100 olmalıdır.');
  }

  final shares = basisPoints
      .map((value) => (totalInMinor * value) ~/ 10000)
      .toList(growable: false);
  var remainder = totalInMinor - shares.fold<int>(0, (a, b) => a + b);
  for (var index = 0; remainder > 0; index = (index + 1) % shares.length) {
    if (basisPoints[index] == 0) continue;
    shares[index] += 1;
    remainder -= 1;
  }
  return shares;
}
