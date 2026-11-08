import 'package:flutter/material.dart';
import 'package:personal_finance/service/gold_service.dart';
import 'package:personal_finance/shared/helpers/number_helper.dart';

import '../../models/gold.dart';
import '../../service/save_service.dart';
import '../../shared/helpers/service_helper.dart';
import '../../shared/widgets/linear_header.dart';
import '../../shared/widgets/save_card.dart';

class SaveScreen extends StatefulWidget {
  const SaveScreen({super.key});

  @override
  State<SaveScreen> createState() => _SaveScreenState();
}

class _SaveScreenState extends State<SaveScreen> {
  late Future<List<List<Object?>>?> _dataFuture;
  Gold? _gold;
  bool _isShow = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = SaveService.readSheet();
    Future.sync(() async {
      final goldData = await GoldService.getGolds();
      _gold = goldData.firstWhere(
        (f) => f.name == 'NHẪN TRÒN TRƠN (Vàng Rồng Thăng Long)',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<List<Object?>>?>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No data found.'));
          }

          final rows = snapshot.data!;
          final list = rows.skip(1).where((f) => f[0] != 'Đã huỷ').toList();
          list.sort((a, b) => a[1].toString().compareTo(b[1].toString()));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearHeader(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.arrow_back),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Text(
                                  'TIẾT KIỆM',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
                          child: Row(
                            children: [
                              Expanded(
                                child: SaveCard(
                                  type: SaveCardType.primary,
                                  title: 'HIỆN CÓ',
                                  image:
                                      'https://res.cloudinary.com/dsxdvql2r/image/upload/v1769158260/award_3225798_axreoh.png',
                                  value: _isShow
                                      ? rows[0][11].toString()
                                      : NumberHelper.hideMoney(),
                                  onPressed: () {
                                    setState(() {
                                      _isShow = !_isShow;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: SaveCard(
                                  type: SaveCardType.contrast,
                                  title: 'TƯƠNG LAI',
                                  image:
                                      'https://res.cloudinary.com/dsxdvql2r/image/upload/v1769158261/rich_3225795_pwz2yp.png',
                                  value: _isShow
                                      ? rows[0][13].toString()
                                      : NumberHelper.hideMoney(),
                                  onPressed: () {
                                    setState(() {
                                      _isShow = !_isShow;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Text(
                  'DANH SÁCH',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      String profit = list[index][7].toString();
                      String percent = list[index][2].toString();
                      if (list[index][1].toString() == '9999' &&
                          _gold != null) {
                        final capital = NumberHelper.parseMoney(
                          list[index][6].toString(),
                        );
                        final value = double.parse(_gold!.purchasePrice);
                        final p =
                            value - capital - NumberHelper.goldDifference;
                        profit = NumberHelper.formatCurrency(p);
                        percent = '${(p * 100 / capital).toStringAsFixed(2)}%';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.transparent,
                              child: ClipOval(
                                child: Image.network(
                                  ServiceHelper.getLogo(
                                    list[index][1].toString(),
                                  ),
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isShow
                                          ? list[index][6].toString()
                                          : NumberHelper.hideMoney(),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '$profit | $percent',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${list[index][3]} đến ${list[index][5]}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                              ),
                              child: Text(
                                'Hàng chờ',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
