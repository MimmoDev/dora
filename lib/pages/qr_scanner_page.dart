import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../repositories/check_in_repository.dart';
import '../repositories/auth_repository.dart';
import 'check_in_result_page.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  final _checkInRepo = CheckInRepository();
  final _authRepo = AuthRepository();
  bool _isProcessing = false;
  bool _hasPermission = false; // Inizia a false, verrà controllato all'avvio
  bool _isScannerStarted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanner();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Ferma lo scanner quando l'app va in background
      _controller.stop();
      _isScannerStarted = false;
    } else if (state == AppLifecycleState.resumed && _hasPermission) {
      // Quando l'app torna in foreground, riavvia solo se ha permesso
      _startScanner();
    }
  }

  Future<void> _startScanner() async {
    try {
      // Ferma lo scanner se era già avviato
      if (_isScannerStarted) {
        await _controller.stop();
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      // Avvia lo scanner - mobile_scanner mostrerà automaticamente la modale nativa di iOS
      // per richiedere il permesso se necessario
      await _controller.start();
      if (!mounted) return;
      
      setState(() {
        _hasPermission = true;
        _isScannerStarted = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Errore avvio scanner: $e');
      setState(() {
        _hasPermission = false;
        _isScannerStarted = false;
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('permission') || errorStr.contains('denied') || errorStr.contains('authorized')) {
          _errorMessage = 'Permesso fotocamera negato. Abilitalo nelle impostazioni.';
        } else if (errorStr.contains('camera') || errorStr.contains('unavailable')) {
          _errorMessage = 'Fotocamera non disponibile. Verifica che non sia utilizzata da un\'altra app.';
        } else {
          _errorMessage = 'Errore accesso fotocamera: $e';
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrCode = barcodes.first.rawValue;
    if (qrCode == null || qrCode.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final userId = _authRepo.currentUser?.id;
      if (userId == null) {
        throw Exception('Sessione non trovata');
      }
      
      // Valida il check-in
      final result = await _checkInRepo.validateCheckIn(userId, qrCode);
      
      final isValid = result['valid'] as bool;
      final status = result['status'] as String;
      
      // Crea il record di check-in
      if (isValid) {
        await _checkInRepo.createCheckIn(
          userId: userId,
          bookingId: result['booking_id'] as String?,
          appointmentId: result['appointment_id'] as String?,
          status: status,
        );
      }

      if (!mounted) return;

      // Naviga alla pagina di risultato
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CheckInResultPage(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se c'è un errore o non ha permessi, mostra un messaggio
    if (_errorMessage != null || !_hasPermission) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scansiona QR Code'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                Text(
                  _errorMessage ?? 'Permesso fotocamera richiesto',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Vai nelle Impostazioni > Dora > Fotocamera e abilita l\'accesso',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Riprova ad avviare lo scanner
                        await _startScanner();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Riprova'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scansiona QR Code'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isScannerStarted
          ? Stack(
              children: [
                // Scanner
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    debugPrint('Errore scanner: $error');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Errore scanner: $error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isScannerStarted = false;
                                _errorMessage = null;
                              });
                              _startScanner();
                            },
                            child: const Text('Riprova'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          
          // Overlay con guida
          CustomPaint(
            painter: _ScannerOverlayPainter(),
            child: Container(),
          ),
          
          // Istruzioni
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Inquadra il QR Code della palestra\nper timbrare il tuo ingresso',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          
                // Loading overlay
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Verifica in corso...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text('Avvio scanner...'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _startScanner,
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final centerSquareSize = size.width * 0.7;
    final left = (size.width - centerSquareSize) / 2;
    final top = (size.height - centerSquareSize) / 2;

    // Disegna l'overlay scuro con un buco al centro
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, centerSquareSize, centerSquareSize),
          const Radius.circular(12),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Disegna gli angoli del frame
    final framePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final cornerLength = 30.0;

    // Angolo in alto a sinistra
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      framePaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      framePaint,
    );

    // Angolo in alto a destra
    canvas.drawLine(
      Offset(left + centerSquareSize - cornerLength, top),
      Offset(left + centerSquareSize, top),
      framePaint,
    );
    canvas.drawLine(
      Offset(left + centerSquareSize, top),
      Offset(left + centerSquareSize, top + cornerLength),
      framePaint,
    );

    // Angolo in basso a sinistra
    canvas.drawLine(
      Offset(left, top + centerSquareSize - cornerLength),
      Offset(left, top + centerSquareSize),
      framePaint,
    );
    canvas.drawLine(
      Offset(left, top + centerSquareSize),
      Offset(left + cornerLength, top + centerSquareSize),
      framePaint,
    );

    // Angolo in basso a destra
    canvas.drawLine(
      Offset(left + centerSquareSize - cornerLength, top + centerSquareSize),
      Offset(left + centerSquareSize, top + centerSquareSize),
      framePaint,
    );
    canvas.drawLine(
      Offset(left + centerSquareSize, top + centerSquareSize - cornerLength),
      Offset(left + centerSquareSize, top + centerSquareSize),
      framePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


