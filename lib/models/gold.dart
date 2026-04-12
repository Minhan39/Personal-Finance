class Gold {
  final String id;
  final String name;
  final String karaContent;
  final String goldContent;
  final String purchasePrice;
  final String sellingPrice;
  final String worldPrice;
  final String time;

  Gold({
    required this.id,
    required this.name,
    required this.karaContent,
    required this.goldContent,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.worldPrice,
    required this.time,
  });

  factory Gold.fromMap(Map<String, dynamic> map) {
    final idx = map['@row'] ?? '';
    return Gold(
      id: idx,
      name: map['@n_$idx'] ?? '',
      karaContent: map['@k_$idx'] ?? '',
      goldContent: map['@h_$idx'] ?? '',
      purchasePrice: map['@pb_$idx'] ?? '',
      sellingPrice: map['@ps_$idx'] ?? '',
      worldPrice: map['@pt_$idx'] ?? '',
      time: map['@d_$idx'] ?? '',
    );
  }
}
