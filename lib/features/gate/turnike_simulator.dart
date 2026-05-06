import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/corporate_theme.dart';

class TurnikeSimulatorScreen extends StatefulWidget {
  const TurnikeSimulatorScreen({super.key});

  @override
  State<TurnikeSimulatorScreen> createState() => _TurnikeSimulatorScreenState();
}

class _TurnikeSimulatorScreenState extends State<TurnikeSimulatorScreen>
    with SingleTickerProviderStateMixin {
  static const _gateId = 'gate_1';
  static const _basePayload = 'ADUPASS_GATE1';

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _gateStream;
  late final Timer _qrTimer;
  late final AnimationController _successPulseController;

  String _qrData = _generateQrData();
  bool _resetScheduled = false;

  @override
  void initState() {
    super.initState();
    _gateStream = FirebaseFirestore.instance
        .collection('gates')
        .doc(_gateId)
        .snapshots();

    _successPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _qrTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _qrData = _generateQrData());
    });
  }

  @override
  void dispose() {
    _qrTimer.cancel();
    _successPulseController.dispose();
    super.dispose();
  }

  static String _generateQrData() {
    return '${_basePayload}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _resetGateAfterDelay() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    await FirebaseFirestore.instance.collection('gates').doc(_gateId).set({
      'status': 'waiting',
      'studentName': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('ADÜPass Turnike Simülasyonu'),
        foregroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _gateStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondaryBlue),
              ),
            );
          }

          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final status = (data['status'] as String?)?.trim().toLowerCase();
          final studentName =
              ((data['studentName'] as String?)?.trim().isNotEmpty ?? false)
              ? (data['studentName'] as String).trim()
              : 'Öğrenci';

          if (status == 'success') {
            if (!_resetScheduled) {
              _resetScheduled = true;
              unawaited(
                _resetGateAfterDelay().whenComplete(() {
                  if (mounted) {
                    _resetScheduled = false;
                  }
                }),
              );
            }
            return _SuccessStateView(
              animation: _successPulseController,
              studentName: studentName,
            );
          }

          _resetScheduled = false;
          return _WaitingStateView(qrData: _qrData);
        },
      ),
    );
  }
}

class _WaitingStateView extends StatelessWidget {
  const _WaitingStateView({required this.qrData});

  final String qrData;

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.paddingOf(context).bottom;
    final size = MediaQuery.sizeOf(context);
    final viewHeight = size.height;
    final panelWidth = size.width / 2;
    final qrSide = math
        .min(
          280.0,
          math.max(
            160.0,
            math.min(panelWidth * 0.72, viewHeight * 0.32),
          ),
        )
        .toDouble();

    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: AppColors.borderLight),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + paddingBottom),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.borderLight,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: AppColors.secondaryBlue,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Turnike QR',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Kod her 3 saniyede bir yenilenir.',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.borderLight),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: QrImageView(
                                  key: ValueKey<String>(qrData),
                                  data: qrData,
                                  size: qrSide,
                                  version: QrVersions.auto,
                                  gapless: true,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: AppColors.primary,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: const Text(
                                'Telefonunuzda ADÜPass uygulamasını açın, '
                                '"Turnike QR Kodu Tara" düğmesine basın ve bu '
                                'kodu kameraya hizalayın.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + paddingBottom),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Yapay Zeka Yüz Tanıma Aktif',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.15,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AspectRatio(
                        aspectRatio: 3 / 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.secondaryBlue,
                                AppColors.accentCyan,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentCyan.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Container(
                                  width: double.infinity,
                                  color: AppColors.surfaceMuted,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.videocam_rounded,
                                        size: math.min(56, qrSide * 0.35),
                                        color: AppColors.secondaryBlue
                                            .withValues(alpha: 0.85),
                                      ),
                                      const SizedBox(height: 14),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        child: Text(
                                          'Sistem Yüzünüzü Bekliyor',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.textDark,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        child: Text(
                                          'Kamera akışı bu simülasyonda '
                                          'gösterilmez; canlı ortamda yüz '
                                          'doğrulama etkinleştirilir.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12.5,
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessStateView extends StatelessWidget {
  const _SuccessStateView({required this.animation, required this.studentName});

  final Animation<double> animation;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.secondaryBlue,
            const Color(0xFF168A5C),
            AppColors.accentCyan.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.05).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 30,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 76,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Hoş geldiniz, $studentName',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'GEÇİŞ BAŞARILI — TURNİKE AÇILDI',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
