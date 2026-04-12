import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:personal_finance/shared/helpers/number_helper.dart';

class VisaCard extends StatefulWidget {
  const VisaCard({super.key, required this.totalMoney});
  final String totalMoney;

  @override
  State<VisaCard> createState() => _VisaCardState();
}

class _VisaCardState extends State<VisaCard> {
  bool _isShow = false;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _isShow = !_isShow;
          });
        },
        child: Stack(
          children: [
            Container(
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FM',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Stack(
                        children: [
                          SizedBox(
                            width: 32,
                            child: CircleAvatar(
                              radius: 8.0,
                              backgroundColor: Color(
                                0xffff0000,
                              ).withValues(alpha: 0.8),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            child: CircleAvatar(
                              radius: 8.0,
                              backgroundColor: Color(
                                0xffff9500,
                              ).withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TỔNG TÀI SẢN',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _isShow
                                  ? widget.totalMoney
                                  : NumberHelper.hideMoney(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.8),
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        icon: Icon(
                          _isShow
                              ? CupertinoIcons.eye_slash
                              : CupertinoIcons.eye,
                          size: 24,
                          color: Theme.of(context).primaryColor,
                        ),
                        label: Text(
                          _isShow ? 'Hiện' : 'Ẩn',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned.fill(child: Image.asset('assets/images/phoenix.png')),
          ],
        ),
      ),
    );
  }
}
