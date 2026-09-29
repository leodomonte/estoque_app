import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class LeitorCodigoPage extends StatefulWidget {
  const LeitorCodigoPage({super.key});

  @override
  State<LeitorCodigoPage> createState() => _LeitorCodigoPageState();
}

class _LeitorCodigoPageState extends State<LeitorCodigoPage> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean8,
      BarcodeFormat.ean13,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _codigoEncontrado = false;

  Future<void> _aoDetectar(BarcodeCapture captura) async {
    if (_codigoEncontrado) return;
    for (final codigo in captura.barcodes) {
      final valor = codigo.rawValue;
      if (valor == null || valor.trim().isEmpty) continue;
      _codigoEncontrado = true;
      await _controller.stop();
      if (mounted) Navigator.pop(context, valor.trim());
      return;
    }
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear código de barras')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _aoDetectar),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 300,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Centralize o código de barras dentro da moldura.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
