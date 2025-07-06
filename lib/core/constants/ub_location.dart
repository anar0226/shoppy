const List<String> kUbDistricts = [
  'Багануур',
  'Багахангай',
  'Баянгол',
  'Баянзүрх',
  'Чингэлтэй',
  'Хан-Уул',
  'Налайх',
  'Сонгинохайрхан',
  'Сүхбаатар',
];

final Map<String, List<int>> kUbDistrictKhoroos = {
  'Багануур': [1, 2, 3, 4, 5],
  'Багахангай': [1, 2],
  'Баянгол': List.generate(34, (i) => i + 1),
  'Баянзүрх': List.generate(43, (i) => i + 1),
  'Налайх': List.generate(7, (i) => i + 1),
  'Сонгинохайрхан': List.generate(43, (i) => i + 1),
  'Сүхбаатар': List.generate(20, (i) => i + 1),
  'Хан-Уул': List.generate(25, (i) => i + 1),
  'Чингэлтэй': List.generate(24, (i) => i + 1),
};
