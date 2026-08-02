import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

void main() {
  runApp(const PresupuestoApp());
}

class PresupuestoApp extends StatelessWidget {
  const PresupuestoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gastos Ruth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// Modelos de datos
class Transaccion {
  final String id;
  final String titulo;
  final double monto;
  final bool esGasto;
  final String categoria;
  final DateTime fecha;

  Transaccion({
    required this.id,
    required this.titulo,
    required this.monto,
    required this.esGasto,
    required this.categoria,
    required this.fecha,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'titulo': titulo,
        'monto': monto,
        'esGasto': esGasto,
        'categoria': categoria,
        'fecha': fecha.toIso8601String(),
      };

  factory Transaccion.fromMap(Map<String, dynamic> map) => Transaccion(
        id: map['id'],
        titulo: map['titulo'],
        monto: (map['monto'] as num).toDouble(),
        esGasto: map['esGasto'],
        categoria: map['categoria'],
        fecha: DateTime.parse(map['fecha']),
      );
}

class Apartado {
  final String id;
  final String nombre;
  final double monto;
  final String nota;

  Apartado({
    required this.id,
    required this.nombre,
    required this.monto,
    required this.nota,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'monto': monto,
        'nota': nota,
      };

  factory Apartado.fromMap(Map<String, dynamic> map) => Apartado(
        id: map['id'],
        nombre: map['nombre'],
        monto: (map['monto'] as num).toDouble(),
        nota: map['nota'] ?? '',
      );
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  List<Transaccion> _transacciones = [];
  List<Apartado> _apartados = [];
  List<String> _categorias = [
    'Alimentación',
    'Transporte',
    'Comida Mascotas',
    'Salud',
    'Servicios',
    'Entretenimiento',
    'Otros',
  ];

  final double _limitePresupuesto = 1000.0;
  String _filtroHistorial = 'Todos';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();

    // Cargar Transacciones
    final String? dataTrans = prefs.getString('transacciones');
    if (dataTrans != null) {
      final List<dynamic> jsonList = jsonDecode(dataTrans);
      _transacciones = jsonList.map((x) => Transaccion.fromMap(x)).toList();
    }

    // Cargar Apartados
    final String? dataApartados = prefs.getString('apartados');
    if (dataApartados != null) {
      final List<dynamic> jsonList = jsonDecode(dataApartados);
      _apartados = jsonList.map((x) => Apartado.fromMap(x)).toList();
    }

    // Cargar Categorías Personalizadas
    final String? dataCategorias = prefs.getString('categorias');
    if (dataCategorias != null) {
      final List<dynamic> listCat = jsonDecode(dataCategorias);
      _categorias = listCat.map((x) => x.toString()).toList();
    }

    setState(() {});
  }

  Future<void> _guardarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'transacciones', jsonEncode(_transacciones.map((x) => x.toMap()).toList()));
    await prefs.setString(
        'apartados', jsonEncode(_apartados.map((x) => x.toMap()).toList()));
    await prefs.setString('categorias', jsonEncode(_categorias));
  }

  // Cálculos de Balance
  double get _totalIngresosActuales => _transacciones
      .where((t) => !t.esGasto && !t.fecha.isAfter(DateTime.now()))
      .fold(0.0, (sum, item) => sum + item.monto);

  double get _totalGastosActuales => _transacciones
      .where((t) => t.esGasto && !t.fecha.isAfter(DateTime.now()))
      .fold(0.0, (sum, item) => sum + item.monto);

  double get _saldoTotalReal => _totalIngresosActuales - _totalGastosActuales;

  double get _totalApartados =>
      _apartados.fold(0.0, (sum, item) => sum + item.monto);

  double get _saldoLibreDisponible => _saldoTotalReal - _totalApartados;

  // Futuros
  double get _totalIngresosFuturos => _transacciones
      .where((t) => !t.esGasto && t.fecha.isAfter(DateTime.now()))
      .fold(0.0, (sum, item) => sum + item.monto);

  double get _totalGastosFuturos => _transacciones
      .where((t) => t.esGasto && t.fecha.isAfter(DateTime.now()))
      .fold(0.0, (sum, item) => sum + item.monto);

  double get _saldoFuturoProyectado =>
      _saldoTotalReal + _totalIngresosFuturos - _totalGastosFuturos;

  // Acciones Transacciones
  void _agregarOEditarTransaccion({Transaccion? transaccionExistente}) {
    final tituloController =
        TextEditingController(text: transaccionExistente?.titulo ?? '');
    final montoController = TextEditingController(
        text: transaccionExistente != null
            ? transaccionExistente.monto.toStringAsFixed(2)
            : '');
    bool esGasto = transaccionExistente?.esGasto ?? true;
    String categoria = transaccionExistente?.categoria ?? _categorias.first;
    DateTime fechaSeleccionada =
        transaccionExistente?.fecha ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                transaccionExistente == null
                    ? 'Nueva Transacción'
                    : 'Editar Transacción',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextField(
                controller: tituloController,
                decoration: const InputDecoration(labelText: 'Descripción / Título'),
              ),
              TextField(
                controller: montoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto (\$)'),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tipo:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Gasto')),
                      ButtonSegment(value: false, label: Text('Ingreso')),
                    ],
                    selected: {esGasto},
                    onSelectionChanged: (val) {
                      setModalState(() => esGasto = val.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: _categorias.contains(categoria)
                          ? categoria
                          : _categorias.first,
                      isExpanded: true,
                      items: _categorias
                          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => categoria = val);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
                    tooltip: 'Agregar nueva categoría',
                    onPressed: () => _mostrarModalNuevaCategoria(context, () {
                      setModalState(() {});
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fecha: ${fechaSeleccionada.day}/${fechaSeleccionada.month}/${fechaSeleccionada.year}',
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Cambiar'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fechaSeleccionada,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setModalState(() => fechaSeleccionada = picked);
                      }
                    },
                  )
                ],
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: () {
                  final monto = double.tryParse(montoController.text);
                  if (tituloController.text.isEmpty || monto == null || monto <= 0) return;

                  setState(() {
                    if (transaccionExistente != null) {
                      _transacciones.removeWhere((t) => t.id == transaccionExistente.id);
                    }
                    _transacciones.insert(
                      0,
                      Transaccion(
                        id: transaccionExistente?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        titulo: tituloController.text,
                        monto: monto,
                        esGasto: esGasto,
                        categoria: categoria,
                        fecha: fechaSeleccionada,
                      ),
                    );
                  });
                  _guardarDatos();
                  Navigator.of(context).pop();
                },
                child: Text(transaccionExistente == null ? 'Guardar' : 'Actualizar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _eliminarTransaccion(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Registro'),
        content: const Text('¿Estás segura de eliminar este movimiento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _transacciones.removeWhere((t) => t.id == id);
              });
              _guardarDatos();
              Navigator.of(ctx).pop();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarModalNuevaCategoria(BuildContext context, VoidCallback onAdded) {
    final catController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Categoría'),
        content: TextField(
          controller: catController,
          decoration: const InputDecoration(hintText: 'Ej. Veterinario, Gimnasio...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (catController.text.trim().isNotEmpty) {
                setState(() {
                  _categorias.add(catController.text.trim());
                });
                _guardarDatos();
                onAdded();
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  // Acciones Apartados
  void _agregarOEditarApartado({Apartado? apartadoExistente}) {
    final nombreController =
        TextEditingController(text: apartadoExistente?.nombre ?? '');
    final montoController = TextEditingController(
        text: apartadoExistente != null
            ? apartadoExistente.monto.toStringAsFixed(2)
            : '');
    final notaController =
        TextEditingController(text: apartadoExistente?.nota ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(apartadoExistente == null ? 'Nuevo Apartado' : 'Editar Apartado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre (Ej: Renta, Vacaciones)'),
              ),
              TextField(
                controller: montoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto a Reservar (\$)'),
              ),
              TextField(
                controller: notaController,
                decoration: const InputDecoration(labelText: '¿Para qué usarás este dinero?'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final monto = double.tryParse(montoController.text);
              if (nombreController.text.isEmpty || monto == null || monto < 0) return;

              setState(() {
                if (apartadoExistente != null) {
                  _apartados.removeWhere((a) => a.id == apartadoExistente.id);
                }
                _apartados.add(Apartado(
                  id: apartadoExistente?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  nombre: nombreController.text,
                  monto: monto,
                  nota: notaController.text,
                ));
              });
              _guardarDatos();
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _eliminarApartado(String id) {
    setState(() {
      _apartados.removeWhere((a) => a.id == id);
    });
    _guardarDatos();
  }

  // Reporte CSV
  void _mostrarModalReporteSemanal(BuildContext context) {
    final ahora = DateTime.now();
    final hace7Dias = ahora.subtract(const Duration(days: 7));
    final gastosSemana = _transacciones
        .where((t) => t.esGasto && t.fecha.isAfter(hace7Dias))
        .toList();

    final totalSemanal = gastosSemana.fold(0.0, (sum, t) => sum + t.monto);

    StringBuffer buffer = StringBuffer();
    buffer.writeln("REPORTE DE GASTOS SEMANAL - GASTOS RUTH");
    buffer.writeln("Fecha: ${ahora.day}/${ahora.month}/${ahora.year}");
    buffer.writeln("Total Gastado: \$${totalSemanal.toStringAsFixed(2)}\n");
    buffer.writeln("Fecha,Título,Categoría,Monto");
    for (var g in gastosSemana) {
      buffer.writeln(
          "${g.fecha.day}/${g.fecha.month}/${g.fecha.year},\"${g.titulo}\",\"${g.categoria}\",\$${g.monto.toStringAsFixed(2)}");
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reporte Semanal'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gastos últimos 7 días: \$${totalSemanal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey.shade100,
                  child: SingleChildScrollView(
                    child: Text(buffer.toString(),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copiar CSV'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: buffer.toString()));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte copiado al portapapeles')),
              );
            },
          )
        ],
      ),
    );
  }

  // Pestañas Principales
  Widget _buildVistaInicio() {
    List<Transaccion> filtradas = _transacciones.where((t) {
      if (_filtroHistorial == 'Ingresos') return !t.esGasto;
      if (_filtroHistorial == 'Gastos') return t.esGasto;
      return true;
    }).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Tarjeta Principal de Balance
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Saldo Libre Disponible (Sin Apartados)',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  Text(
                    '\$${_saldoLibreDisponible.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _saldoLibreDisponible >= 0 ? Colors.teal : Colors.red,
                    ),
                  ),
                  const Divider(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Saldo Real', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('\$${_saldoTotalReal.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('En Apartados', style: TextStyle(fontSize: 12, color: Colors.orange)),
                          Text('-\$${_totalApartados.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Límite de Presupuesto
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Límite de Gastos Mensual:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${_totalGastosActuales.toStringAsFixed(0)} / \$$_limitePresupuesto'),
                  ],
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: (_limitePresupuesto > 0)
                      ? (_totalGastosActuales / _limitePresupuesto).clamp(0.0, 1.0)
                      : 0.0,
                  color: (_totalGastosActuales / _limitePresupuesto) > 0.85
                      ? Colors.red
                      : Colors.teal,
                  backgroundColor: Colors.grey.shade300,
                  minHeight: 8,
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),
          const Divider(),

          // Filtro e Historial
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Historial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Todos', label: Text('Todos')),
                    ButtonSegment(value: 'Ingresos', label: Text('Ingresos')),
                    ButtonSegment(value: 'Gastos', label: Text('Gastos')),
                  ],
                  selected: {_filtroHistorial},
                  onSelectionChanged: (val) {
                    setState(() => _filtroHistorial = val.first);
                  },
                ),
              ],
            ),
          ),

          filtradas.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('No hay registros en esta categoría.',
                      style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtradas.length,
                  itemBuilder: (ctx, index) {
                    final t = filtradas[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: t.esGasto ? Colors.red.shade100 : Colors.green.shade100,
                        child: Icon(
                          t.esGasto ? Icons.arrow_downward : Icons.arrow_upward,
                          color: t.esGasto ? Colors.red : Colors.green,
                        ),
                      ),
                      title: Text(t.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${t.categoria} • ${t.fecha.day}/${t.fecha.month}/${t.fecha.year}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${t.esGasto ? '-' : '+'}\$${t.monto.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: t.esGasto ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                            onPressed: () => _agregarOEditarTransaccion(transaccionExistente: t),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () => _eliminarTransaccion(t.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildVistaApartados() {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.savings, size: 40, color: Colors.teal),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Guardado en Apartados',
                              style: TextStyle(fontSize: 13, color: Colors.black54)),
                          Text('\$${_totalApartados.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mis Metas / Apartados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo Apartado'),
                  onPressed: () => _agregarOEditarApartado(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _apartados.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(
                      child: Text('No has creado apartados aún. ¡Crea uno para separar dinero de gastos!',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _apartados.length,
                    itemBuilder: (ctx, index) {
                      final a = _apartados[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.orangeAccent,
                            child: Icon(Icons.lock, color: Colors.white),
                          ),
                          title: Text(a.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(a.nota.isNotEmpty ? a.nota : 'Sin nota especificada'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('\$${a.monto.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.teal)),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                onPressed: () => _agregarOEditarApartado(apartadoExistente: a),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                onPressed: () => _eliminarApartado(a.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildVistaGraficosYReportes() {
    // Calcular gastos por categoría
    Map<String, double> gastosPorCategoria = {};
    for (var cat in _categorias) {
      gastosPorCategoria[cat] = 0.0;
    }

    double totalGastadoGlobal = 0.0;
    for (var t in _transacciones) {
      if (t.esGasto) {
        gastosPorCategoria[t.categoria] =
            (gastosPorCategoria[t.categoria] ?? 0.0) + t.monto;
        totalGastadoGlobal += t.monto;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Control de Gastos por Categoría',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('Total Gastado Registrado: \$${totalGastadoGlobal.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 15),

          totalGastadoGlobal == 0
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Text('No hay gastos registrados para generar gráfico.'),
                  ),
                )
              : Column(
                  children: _categorias.map((cat) {
                    final monto = gastosPorCategoria[cat] ?? 0.0;
                    final porcentaje =
                        (totalGastadoGlobal > 0) ? (monto / totalGastadoGlobal) : 0.0;
                    if (monto == 0) return const SizedBox.shrink();

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('\$${monto.toStringAsFixed(2)} (${(porcentaje * 100).toStringAsFixed(1)}%)',
                                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: porcentaje,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade200,
                              color: Colors.teal,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

          const SizedBox(height: 25),
          const Divider(),
          const Text('Resumen Cierre Semanal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Saldo Cierre Semana Pasada:'),
                      Text('\$${_saldoTotalReal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Este saldo disponible se traslada automáticamente como punto de partida para cubrir los gastos e ingresos de la presente semana.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVistaCalendarioYFuturos() {
    final transaccionesFuturas =
        _transacciones.where((t) => t.fecha.isAfter(DateTime.now())).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.purple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saldo Futuro Proyectado',
                      style: TextStyle(fontSize: 13, color: Colors.black54)),
                  Text(
                    '\$${_saldoFuturoProyectado.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Incluye: Saldo Actual (\$${_saldoTotalReal.toStringAsFixed(2)}) + Ingresos Programados (\$${_totalIngresosFuturos.toStringAsFixed(2)}) - Gastos Programados (\$${_totalGastosFuturos.toStringAsFixed(2)})',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Ingresos y Gastos Programados (Futuros)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          transaccionesFuturas.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text('No tienes movimientos programados para fechas futuras.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transaccionesFuturas.length,
                  itemBuilder: (ctx, index) {
                    final t = transaccionesFuturas[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              t.esGasto ? Colors.red.shade100 : Colors.green.shade100,
                          child: Icon(
                            t.esGasto ? Icons.event_busy : Icons.event_available,
                            color: t.esGasto ? Colors.red : Colors.green,
                          ),
                        ),
                        title: Text(t.titulo,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${t.categoria} • ${t.fecha.day}/${t.fecha.month}/${t.fecha.year}'),
                        trailing: Text(
                          '${t.esGasto ? '-' : '+'}\$${t.monto.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: t.esGasto ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> paginas = [
      _buildVistaInicio(),
      _buildVistaApartados(),
      _buildVistaGraficosYReportes(),
      _buildVistaCalendarioYFuturos(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos Ruth'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Reporte Semanal',
            onPressed: () => _mostrarModalReporteSemanal(context),
          ),
        ],
      ),
      body: paginas[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.savings), label: 'Apartados'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Gráficos'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendario'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _agregarOEditarTransaccion(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
