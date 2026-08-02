<!-- ... existing code ... -->
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

void main() {
<!-- ... existing code ... -->
class _HomeScreenState extends State<HomeScreen> {
  List<Transaccion> _transacciones = [];
  final double _limitePresupuesto = 1000.0;
  String _filtroHistorial = 'Todos';

  // Lista de categorías disponibles
  final List<String> _categorias = [
    'Alimentación',
    'Transporte',
    'Pasajes',
    'Comida Mascotas',
    'Servicios',
    'Entretenimiento',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
<!-- ... existing code ... -->
  double get _saldoTotal => _totalIngresos - _totalGastos;

  // Filtrado de transacciones
  List<Transaccion> get _transaccionesFiltradas {
    if (_filtroHistorial == 'Ingresos') {
      return _transacciones.where((t) => !t.esGasto).toList();
    } else if (_filtroHistorial == 'Gastos') {
      return _transacciones.where((t) => t.esGasto).toList();
    }
    return _transacciones;
  }

  void _mostrarFormulario(BuildContext context) {
    final tituloController = TextEditingController();
    final montoController = TextEditingController();
    bool esGasto = true;
    String categoria = _categorias.first;

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
                items: _categorias
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Ventana para ver y copiar el reporte de gastos de la semana
  void _mostrarModalReporteSemanal(BuildContext context) {
    final ahora = DateTime.now();
    final hace7Dias = ahora.subtract(const Duration(days: 7));
    final gastosSemana = _transacciones
        .where((t) => t.esGasto && t.fecha.isAfter(hace7Dias))
        .toList();

    final totalSemanal = gastosSemana.fold(0.0, (sum, t) => sum + t.monto);

    StringBuffer buffer = StringBuffer();
    buffer.writeln("REPORTE DE GASTOS SEMANAL");
    buffer.writeln("Fecha generación: ${ahora.day}/${ahora.month}/${ahora.year}");
    buffer.writeln("Total Gastado: \$${totalSemanal.toStringAsFixed(2)}\n");
    buffer.writeln("Fecha,Título,Categoría,Monto");
    for (var g in gastosSemana) {
      buffer.writeln("${g.fecha.day}/${g.fecha.month}/${g.fecha.year},\"${g.titulo}\",\"${g.categoria}\",\$${g.monto.toStringAsFixed(2)}");
    }

    final reporteTexto = buffer.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.summarize, color: Colors.teal),
            SizedBox(width: 8),
            Text('Reporte Semanal'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gastos de los últimos 7 días: \$${totalSemanal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                maxHeight: 200,
                child: SingleChildScrollView(
                  child: Text(
                    reporteTexto,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copiar CSV'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: reporteTexto));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte copiado al portapapeles en formato CSV')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final porcentajePresupuesto = (_limitePresupuesto > 0)
        ? (_totalGastos / _limitePresupuesto).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Presupuesto App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Reporte Semanal',
            onPressed: () => _mostrarModalReporteSemanal(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Tarjeta de Balance General
            Card(
<!-- ... existing code ... -->
            // Barra de Límite de Presupuesto
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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

            const SizedBox(height: 15),
            const Divider(),

            // Filtro de Historial (Todos, Ingresos, Gastos)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Historial',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Todos', label: Text('Todos')),
                      ButtonSegment(value: 'Ingresos', label: Text('Ingresos')),
                      ButtonSegment(value: 'Gastos', label: Text('Gastos')),
                    ],
                    selected: {_filtroHistorial},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _filtroHistorial = newSelection.first;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Lista de Historial Filtrada
            _transaccionesFiltradas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No hay transacciones registradas en este filtro.',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _transaccionesFiltradas.length,
                    itemBuilder: (ctx, index) {
                      final t = _transaccionesFiltradas[index];
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
