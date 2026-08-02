import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const PresupuestoApp());
}

class PresupuestoApp extends StatelessWidget {
  const PresupuestoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Presupuesto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

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
        monto: map['monto'],
        esGasto: map['esGasto'],
        categoria: map['categoria'],
        fecha: DateTime.parse(map['fecha']),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Transaccion> _transacciones = [];
  double _limitePresupuesto = 1000.0; // Presupuesto mensual configurado

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('transacciones');
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      setState(() {
        _transacciones = jsonList.map((x) => Transaccion.fromMap(x)).toList();
      });
    }
  }

  Future<void> _guardarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_transacciones.map((x) => x.toMap()).toList());
    await prefs.setString('transacciones', data);
  }

  void _agregarTransaccion(String titulo, double monto, bool esGasto, String categoria) {
    setState(() {
      _transacciones.add(Transaccion(
        id: DateTime.now().toString(),
        titulo: titulo,
        monto: monto,
        esGasto: esGasto,
        categoria: categoria,
        fecha: DateTime.now(),
      ));
    });
    _guardarDatos();
  }

  double get _totalIngresos => _transacciones
      .where((t) => !t.esGasto)
      .fold(0.0, (sum, item) => sum + item.monto);

  double get _totalGastos => _transacciones
      .where((t) => t.esGasto)
      .fold(0.0, (sum, item) => sum + item.monto);

  double get _saldoTotal => _totalIngresos - _totalGastos;

  void _mostrarFormulario(BuildContext context) {
    final tituloController = TextEditingController();
    final montoController = TextEditingController();
    bool esGasto = true;
    String categoria = 'Alimentación';

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
              Text('Nueva Transacción', style: Theme.of(context).textTheme.titleLarge),
              TextField(
                controller: tituloController,
                decoration: const InputDecoration(labelText: 'Descripción / Título'),
              ),
              TextField(
                controller: montoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monto (\$)'),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tipo:'),
                  FilterChip(
                    label: Text(esGasto ? 'Gasto' : 'Ingreso'),
                    selected: esGasto,
                    onSelected: (val) => setModalState(() => esGasto = val),
                    selectedColor: Colors.redAccent.shade100,
                  ),
                ],
              ),
              DropdownButton<String>(
                value: categoria,
                isExpanded: true,
                items: ['Alimentación', 'Transporte', 'Servicios', 'Entretenimiento', 'Otros']
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) => setModalState(() => categoria = val!),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: () {
                  final monto = double.tryParse(montoController.text);
                  if (tituloController.text.isEmpty || monto == null || monto <= 0) return;
                  _agregarTransaccion(tituloController.text, monto, esGasto, categoria);
                  Navigator.of(context).pop();
                },
                child: const Text('Guardar'),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final porcentajePresupuesto = (_totalGastos / _limitePresupuesto).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Presupuesto App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Targeta de Balance General
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Saldo Total', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text('\$${_saldoTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _saldoTotal >= 0 ? Colors.green : Colors.red,
                        )),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Ingresos', style: TextStyle(color: Colors.green)),
                            Text('+\$${_totalIngresos.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Gastos', style: TextStyle(color: Colors.red)),
                            Text('-\$${_totalGastos.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Barra de Límite de Presupuesto
            Padding(
              padding: const EdgeInsets.horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Límite de Gastos Mensual:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('\$${_totalGastos.toStringAsFixed(0)} / \$$_limitePresupuesto'),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: porcentajePresupuesto,
                    color: porcentajePresupuesto > 0.85 ? Colors.red : Colors.teal,
                    backgroundColor: Colors.grey.shade300,
                    minHeight: 10,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            const Divider(),

            // Lista de Historial
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transacciones.length,
              itemBuilder: (ctx, index) {
                final t = _transacciones[index];
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
                  trailing: Text(
                    '${t.esGasto ? '-' : '+'}\$${t.monto.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: t.esGasto ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
