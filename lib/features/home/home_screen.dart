import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:personal_finance/service/fcm_service.dart';

import '../../data/feature_data.dart';
import '../../service/save_service.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/header.dart';
import '../../shared/widgets/home_card.dart';
import '../../shared/widgets/linear_header.dart';
import '../../shared/widgets/visa_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<List<List<Object?>>?> _dataFuture;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final token = await FcmService.getFcmToken();
        await FcmService.addLog(
          deviceType: 'android',
          fcmToken: token ?? '',
          userId: user.uid,
        );
      }
    });
    _dataFuture = SaveService.readSheet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
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
          return Column(
            children: [
              LinearHeader(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Header(
                          openDrawer: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                        ),
                      ),
                      Expanded(
                        child: VisaCard(totalMoney: rows[0][11].toString()),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: homeFeatureData.length,
                    itemBuilder: (BuildContext context, int index) {
                      var arguments =
                          switch (homeFeatureData[index]['navigator']) {
                            '/save' => rows,
                            _ => null,
                          };
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: HomeCard(
                          image: homeFeatureData[index]['image'] ?? '',
                          title: homeFeatureData[index]['title'] ?? '',
                          body: homeFeatureData[index]['body'] ?? '',
                          onPressed: () {
                            if (homeFeatureData[index]['navigator'] == null ||
                                homeFeatureData[index]['navigator'] == '/') {
                              return;
                            }
                            Navigator.pushNamed(
                              context,
                              homeFeatureData[index]['navigator'] ?? '/',
                              arguments: arguments,
                            );
                          },
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
