import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class FallingItem {
  final String id;
  final String imageAsset;
  double x; // 0.0 a 1.0
  double y; // 0.0 a 1.0
  final double speed;
  final double size;

  FallingItem({
    required this.id,
    required this.imageAsset,
    required this.x,
    this.y = 0.0,
    required this.speed,
    this.size = 64.0,
  });
}

class AtrapaCocoScreen extends StatefulWidget {
  final String? currentLanguageCode;

  const AtrapaCocoScreen({super.key, this.currentLanguageCode});

  @override
  State<AtrapaCocoScreen> createState() => _AtrapaCocoScreenState();
}

class _AtrapaCocoScreenState extends State<AtrapaCocoScreen>
    with TickerProviderStateMixin {
  final List<Map<String, String>> _catalog = [
    {
      'id': 'libro',
      'label': 'LIBRO',
      'asset': 'assets/images/arcade/juegos/atrapa_coco/caida1/libro.png'
    },
    {
      'id': 'manzana',
      'label': 'MANZANA',
      'asset': 'assets/images/arcade/juegos/atrapa_coco/caida1/apple.png'
    },
    {
      'id': 'platano',
      'label': 'BANANO',
      'asset': 'assets/images/arcade/juegos/atrapa_coco/caida1/banana.png'
    },
    {
      'id': 'cafe',
      'label': 'CAFÉ',
      'asset': 'assets/images/arcade/juegos/atrapa_coco/caida1/cafe.png'
    },
    {
      'id': 'lapiz',
      'label': 'LÁPIZ',
      'asset': 'assets/images/arcade/juegos/atrapa_coco/caida1/lapiz.png'
    },
    {
      'id': 'limon',
      'label': 'LIMÓN',
      'asset': 'assets/images/arcade/juegos/atrapa_coco/caida1/limon.png'
    },
    {
      'id': 'maiz',
      'label': 'MAÍZ',
      'asset': 'assets/images/arcade/juegos/atrapa_coco/caida1/maiz.png'
    },
  ];

  late Map<String, String> _currentTarget;
  int _score = 0;
  int _streak = 0;
  int _lives = 3;
  double _cocoX = 0.5;
  final double _cocoSize = 100.0;
  static const double _cocoRelativeY = 0.82; // Posición base de Coco (82% de altura)

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  double _spawnTimer = 0.0;

  final List<FallingItem> _items = [];
  final Random _random = Random();
  bool _isGameOver = false;

  late AnimationController _winAnimController;
  late Animation<double> _targetScaleAnim;
  late AnimationController _shakeAnimController;
  late Animation<double> _shakeAnim;

  bool _showSuccessBadge = false;
  bool _showErrorFlash = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _pickNewTarget();
    _spawnInitialItems();
    _startTickerLoop();
  }

  void _setupAnimations() {
    _winAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _targetScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 60),
    ]).animate(
      CurvedAnimation(parent: _winAnimController, curve: Curves.easeOutBack),
    );

    _shakeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -6.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeAnimController, curve: Curves.linear));
  }

  void _pickNewTarget() {
    _currentTarget = _catalog[_random.nextInt(_catalog.length)];
  }

  void _spawnInitialItems() {
    _items.clear();
    // Primer item: el objetivo directo
    _items.add(FallingItem(
      id: _currentTarget['id']!,
      imageAsset: _currentTarget['asset']!,
      x: 0.35,
      y: 0.05,
      speed: 0.22,
    ));
    // Segundo item aleatorio
    final distractor = _catalog[_random.nextInt(_catalog.length)];
    _items.add(FallingItem(
      id: distractor['id']!,
      imageAsset: distractor['asset']!,
      x: 0.70,
      y: -0.15,
      speed: 0.25,
    ));
  }

  void _startTickerLoop() {
    _lastTick = Duration.zero;
    _ticker?.stop();
    _ticker = createTicker((elapsed) {
      if (_lastTick == Duration.zero) {
        _lastTick = elapsed;
        return;
      }
      final double dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
      _lastTick = elapsed;

      if (!_isGameOver && mounted) {
        _updateGame(dt);
      }
    });
    _ticker!.start();
  }

  void _spawnItem() {
    final bool shouldSpawnTarget =
        _random.nextDouble() < 0.45 && !_items.any((i) => i.id == _currentTarget['id']);

    final itemData = shouldSpawnTarget
        ? _currentTarget
        : _catalog[_random.nextInt(_catalog.length)];

    _items.add(
      FallingItem(
        id: itemData['id']!,
        imageAsset: itemData['asset']!,
        x: 0.15 + _random.nextDouble() * 0.70,
        y: -0.05,
        speed: 0.20 + _random.nextDouble() * 0.12,
      ),
    );
  }

  void _updateGame(double dt) {
    setState(() {
      _spawnTimer += dt;
      if (_spawnTimer >= 1.2) {
        _spawnItem();
        _spawnTimer = 0.0;
      }

      for (int i = _items.length - 1; i >= 0; i--) {
        final item = _items[i];
        item.y += item.speed * dt;

        // Zona de impacto centrada en la posición de Coco
        if ((item.y - _cocoRelativeY).abs() <= 0.06) {
          final double distance = (item.x - _cocoX).abs();
          if (distance < 0.14) {
            if (item.id == _currentTarget['id']) {
              _onCorrectCatch();
              break;
            } else {
              _onWrongCatch();
              _items.removeAt(i);
              continue;
            }
          }
        }

        // Si sale de pantalla por la parte inferior
        if (item.y > 1.05) {
          final bool missedTarget = item.id == _currentTarget['id'];
          _items.removeAt(i);
          if (missedTarget) {
            _onWrongCatch();
            // Aseguramos que haya un objetivo nuevo en camino si aún sigue jugando
            if (!_isGameOver && !_items.any((elem) => elem.id == _currentTarget['id'])) {
              _spawnItem();
            }
          }
        }
      }
    });
  }

  void _onCorrectCatch() {
    _streak++;
    _score += 10 + (_streak > 3 ? 5 : 0);
    _items.clear();

    _showSuccessBadge = true;
    _winAnimController.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _showSuccessBadge = false);
    });

    _pickNewTarget();
    _spawnInitialItems();
  }

  void _onWrongCatch() {
    _streak = 0;
    _lives--;
    _showErrorFlash = true;

    _shakeAnimController.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _showErrorFlash = false);
    });

    if (_lives <= 0) {
      _triggerGameOver();
    }
  }

  void _triggerGameOver() {
    _isGameOver = true;
    _ticker?.stop();
    _showGameOverModal();
  }

  void _showGameOverModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'GameOver',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E3A8A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: Color(0xFFFFD54F), width: 3),
            ),
            title: const Text(
              '¡Juego Terminado!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/arcade/juegos/atrapa_coco/coco_atrapa.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.sentiment_neutral, size: 70, color: Colors.amber),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Puntuación: $_score',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Salir', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9100),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _restartGame();
                },
                child: const Text('Reintentar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _restartGame() {
    setState(() {
      _score = 0;
      _streak = 0;
      _lives = 3;
      _isGameOver = false;
      _pickNewTarget();
      _spawnInitialItems();
    });
    _startTickerLoop();
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _winAnimController.dispose();
    _shakeAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double gameWidth = constraints.maxWidth;
          final double gameHeight = constraints.maxHeight;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              if (_isGameOver) return;
              setState(() {
                _cocoX += details.delta.dx / gameWidth;
                _cocoX = _cocoX.clamp(0.12, 0.88);
              });
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Flash rojo al cometer fallo
                if (_showErrorFlash)
                  Positioned.fill(
                    child: Container(color: Colors.red.withValues(alpha: 0.25)),
                  ),

                // Barra superior (vidas y puntos)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () {
                          _ticker?.stop();
                          Navigator.pop(context);
                        },
                      ),
                      Row(
                        children: List.generate(3, (index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(
                              Icons.favorite,
                              size: 24,
                              color: index < _lives ? Colors.redAccent : Colors.white24,
                            ),
                          );
                        }),
                      ),
                      Row(
                        children: [
                          if (_streak > 1)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '🔥 x$_streak',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '⭐ $_score',
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Objetivo centrado
                Positioned(
                  top: MediaQuery.of(context).padding.top + 60,
                  left: 0,
                  right: 0,
                  child: ScaleTransition(
                    scale: _targetScaleAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentTarget['label']!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 200,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Ítems cayendo
                ..._items.map((item) {
                  return Positioned(
                    left: (item.x * gameWidth) - (item.size / 2),
                    top: item.y * gameHeight,
                    child: SizedBox(
                      width: item.size,
                      height: item.size,
                      child: Image.asset(
                        item.imageAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.help, color: Colors.white),
                        ),
                      ),
                    ),
                  );
                }),

                // Notificación de +10
                if (_showSuccessBadge)
                  Positioned(
                    left: (_cocoX * gameWidth) - 30,
                    top: (gameHeight * _cocoRelativeY) - 50,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.shade700,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '+10 ✨',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                // Coco con Shake Animation sincronizado
                AnimatedBuilder(
                  animation: _shakeAnimController,
                  builder: (context, child) {
                    return Positioned(
                      left: (_cocoX * gameWidth) - (_cocoSize / 2) + _shakeAnim.value,
                      top: (gameHeight * _cocoRelativeY) - (_cocoSize / 2),
                      child: child!,
                    );
                  },
                  child: SizedBox(
                    width: _cocoSize,
                    height: _cocoSize,
                    child: Image.asset(
                      'assets/images/arcade/juegos/atrapa_coco/coco_atrapa.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.face, size: 50, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}