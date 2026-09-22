import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nicalingo/core/theme/app_colors.dart';

class SoporteScreen extends StatefulWidget {
  const SoporteScreen({super.key});

  @override
  State<SoporteScreen> createState() => _SoporteScreenState();
}

class _SoporteScreenState extends State<SoporteScreen> {
  final TextEditingController _mensajeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _mensajes = [];
  bool _cargando = true;
  bool _enviando = false;
  File? _imagenSeleccionada;
  RealtimeChannel? _canalRealtime;
  
  // Nueva variable para el motivo obligatorio
  String? _categoriaSeleccionada;

  // Lista de categorías disponibles
  final List<Map<String, String>> _categorias = [
    {'value': 'duda', 'label': '❓ Duda'},
    {'value': 'error', 'label': '🐛 Error'},
    {'value': 'sugerencia', 'label': '💡 Sugerencia'},
    {'value': 'pagos', 'label': '💳 Pagos'},
    {'value': 'embajador', 'label': '🎖️ Embajador'},
  ];

  @override
  void initState() {
    super.initState();
    _cargarMensajes();
    _iniciarSuscripcionRealtime();
  }

  @override
  void dispose() {
    _canalRealtime?.unsubscribe();
    _mensajeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarMensajes() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _cargando = false);
      return;
    }

    try {
      final response = await _supabase
          .from('mensajes_soporte')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _mensajes = List<Map<String, dynamic>>.from(response);
          _cargando = false;
        });
        _hacerScrollAlFinal();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar mensajes: $e'),
            backgroundColor: const Color(0xFFE64638),
          ),
        );
      }
    }
  }

  void _iniciarSuscripcionRealtime() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _canalRealtime = _supabase
        .channel('public:mensajes_soporte:user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mensajes_soporte',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _cargarMensajes();
          },
        )
        .subscribe();
  }

  Future<void> _seleccionarImagen() async {
    final XFile? pick = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pick != null) {
      setState(() {
        _imagenSeleccionada = File(pick.path);
      });
    }
  }

  void _quitarImagen() {
    setState(() {
      _imagenSeleccionada = null;
    });
  }

  Future<void> _enviarMensaje() async {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty && _imagenSeleccionada == null) return;

    // Validación obligatoria del motivo del mensaje
    if (_categoriaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona un motivo para tu mensaje.'),
          backgroundColor: Color(0xFFE64638),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para comentar.'),
          backgroundColor: Color(0xFFE64638),
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    String? imagenUrl;

    try {
      // 1. Si adjuntó imagen, subirla a Supabase Storage
      if (_imagenSeleccionada != null) {
        final ext = _imagenSeleccionada!.path.split('.').last;
        final nombreArchivo = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

        await _supabase.storage.from('soporte_imagenes').upload(
              nombreArchivo,
              _imagenSeleccionada!,
            );

        imagenUrl = _supabase.storage.from('soporte_imagenes').getPublicUrl(nombreArchivo);
      }

      // 2. Insertar mensaje en la BD incluyendo la categoría
      await _supabase.from('mensajes_soporte').insert({
        'user_id': userId,
        'mensaje': texto.isEmpty ? 'Captura adjunta' : texto,
        'imagen_url': imagenUrl,
        'categoria': _categoriaSeleccionada,
        'es_respuesta_admin': false,
      });

      _mensajeController.clear();
      setState(() {
        _imagenSeleccionada = null;
        _enviando = false;
        // Opcional: _categoriaSeleccionada = null; si deseas que elijan en cada mensaje nuevo
      });

      _hacerScrollAlFinal();
    } catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo enviar el mensaje: $e'),
            backgroundColor: const Color(0xFFE64638),
          ),
        );
      }
    }
  }

  void _hacerScrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Iconos/background/home_back.jpg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Cabecera
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          "Comentarios y Soporte",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Lista de Mensajes
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B86C4).withAlpha(160),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withAlpha(50),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: _cargando
                          ? const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            )
                          : _mensajes.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: Colors.white.withAlpha(180),
                                          size: 46,
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          '¿Tienes alguna duda o reporte de error?\n¡Escríbenos o manda tu captura!',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  itemCount: _mensajes.length,
                                  itemBuilder: (context, index) {
                                    final item = _mensajes[index];
                                    final esAdmin = item['es_respuesta_admin'] == true;
                                    final contenido = item['mensaje'] ?? '';
                                    final imagenUrl = item['imagen_url'] as String?;

                                    return _BurbujaMensaje(
                                      mensaje: contenido,
                                      imagenUrl: imagenUrl,
                                      esAdmin: esAdmin,
                                    );
                                  },
                                ),
                    ),
                  ),
                ),

                // Previsualización de imagen seleccionada
                if (_imagenSeleccionada != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _imagenSeleccionada!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: GestureDetector(
                              onTap: _quitarImagen,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE64638),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Selector de Motivos (Chips horizontales)
                Padding(
                  padding: const EdgeInsets.only(left: 18, right: 18, bottom: 8),
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _categorias.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _categorias[index];
                        final isSelected = _categoriaSeleccionada == cat['value'];
                        return ChoiceChip(
                          label: Text(cat['label']!),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            setState(() {
                              _categoriaSeleccionada = selected ? cat['value'] : null;
                            });
                          },
                          selectedColor: const Color(0xFFFCE392), // Color Sinskira Butter
                          backgroundColor: const Color(0xFF6B86C4).withAlpha(190),
                          checkmarkColor: const Color(0xFF093E37),
                          labelStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF093E37) : Colors.white,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? Colors.transparent : Colors.white.withAlpha(70),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Caja de texto inferior
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B86C4).withAlpha(190),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withAlpha(70),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Botón para adjuntar imagen
                            IconButton(
                              icon: const Icon(
                                Icons.image_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: _enviando ? null : _seleccionarImagen,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _mensajeController,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                textCapitalization: TextCapitalization.sentences,
                                maxLines: null,
                                decoration: InputDecoration(
                                  hintText: 'Escribe tu mensaje...',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white.withAlpha(180),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                ),
                                onSubmitted: (_) => _enviarMensaje(),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF1E3A8A),
                              ),
                              child: _enviando
                                  ? const Padding(
                                      padding: EdgeInsets.all(10.0),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      onPressed: _enviarMensaje,
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
          ),
        ],
      ),
    );
  }
}

class _BurbujaMensaje extends StatelessWidget {
  final String mensaje;
  final String? imagenUrl;
  final bool esAdmin;

  const _BurbujaMensaje({
    required this.mensaje,
    this.imagenUrl,
    required this.esAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: esAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: esAdmin
              ? Colors.white.withAlpha(235)
              : const Color(0xFF1E3A8A),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: esAdmin ? const Radius.circular(4) : const Radius.circular(18),
            bottomRight: esAdmin ? const Radius.circular(18) : const Radius.circular(4),
          ),
          border: Border.all(
            color: Colors.white.withAlpha(60),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              esAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (esAdmin)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.support_agent_rounded,
                      size: 13,
                      color: Color(0xFF1E3A8A),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Soporte NicaLingo',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
              ),

            // Muestra la imagen si viene adjunta
            if (imagenUrl != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imagenUrl!,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 140,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white70,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ],

            if (mensaje.isNotEmpty && mensaje != 'Captura adjunta')
              Text(
                mensaje,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: esAdmin ? const Color(0xFF1E3A8A) : AppColors.textWhite,
                ),
              ),
          ],
        ),
      ),
    );
  }
}