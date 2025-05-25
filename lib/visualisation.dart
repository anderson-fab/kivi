import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// Classe pour stocker les infos d'un capteur
class SensorInfo {
  final String path;
  final String title;
  final String unit;
  final Color color;
  final String description;

  SensorInfo({
    required this.path,
    required this.title,
    required this.unit,
    required this.color,
    required this.description,
  });
}

/// Widget pour afficher un graphique des 10 dernières mesures d'un capteur
class SensorGraph extends StatefulWidget {
  final SensorInfo sensor;
  const SensorGraph({required this.sensor});

  @override
  _SensorGraphState createState() => _SensorGraphState();
}

class _SensorGraphState extends State<SensorGraph> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  late StreamSubscription<DatabaseEvent> _sub;
  List<FlSpot> _spots = [];
  List<String> _labels = [];

  @override
  void initState() {
    super.initState();
    // Écoute en temps réel des 10 dernières clés
    _sub = _db
        .child(widget.sensor.path)
        .orderByKey()
        .limitToLast(10)
        .onValue
        .listen(_onData);
  }

  void _onData(DatabaseEvent event) {
    final raw = event.snapshot.value as Map<dynamic, dynamic>?;
    if (raw == null) return;
    // Trier par timestamp croissant
    final entries = raw.entries
        .map((e) => MapEntry(e.key.toString(), (e.value as num).toDouble()))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = <FlSpot>[];
    final labels = <String>[];
    for (var i = 0; i < entries.length; i++) {
      final key = entries[i].key;
      final value = entries[i].value;
      final dt = DateTime.parse(key).toLocal();
      spots.add(FlSpot(i.toDouble(), value));
      labels.add(DateFormat('HH:mm:ss').format(dt));
    }

    setState(() {
      _spots = spots;
      _labels = labels;
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_spots.isEmpty) {
      return Card(
        margin: EdgeInsets.all(10),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Chargement ${widget.sensor.title}...')),
        ),
      );
    }

    // Calculer min et max Y pour l'axe gauche
    final minY = _spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final maxY = _spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final yInterval = (maxY - minY) / 9;

    return Card(
      margin: EdgeInsets.all(10),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.sensor.title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(widget.sensor.description,
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 1.0,
                maxScale: 5.0,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: true),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= _labels.length)
                              return const Text('');
                            return Transform.rotate(
                              angle: -0.6,
                              child: Text(
                                _labels[i],
                                style: TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: yInterval,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(1),
                              style: TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchInput) =>
                            Colors.white.withOpacity(0.8),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((ts) {
                            final textStyle = TextStyle(
                              color: widget.sensor.color,
                              fontWeight: FontWeight.bold,
                            );
                            final label = _labels[ts.spotIndex];
                            return LineTooltipItem(
                              '$label\n${ts.y.toStringAsFixed(1)} ${widget.sensor.unit}',
                              textStyle,
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _spots,
                        isCurved: false,
                        color: widget.sensor.color,
                        barWidth: 2,
                        dotData: FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Unité : ${widget.sensor.unit}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page principale avec sélection dynamique des capteurs
class VisualisationPage extends StatefulWidget {
  @override
  _VisualisationPageState createState() => _VisualisationPageState();
}

class _VisualisationPageState extends State<VisualisationPage> {
  final List<SensorInfo> sensors = [
    SensorInfo(
      path: 'DHT/temperature_history',
      title: 'Température',
      unit: '°C',
      color: Colors.red,
      description: 'Évolution de la température sur les 10 dernières mesures.',
    ),
    SensorInfo(
      path: 'DHT/humidity_history',
      title: 'Humidité',
      unit: '%',
      color: Colors.blue,
      description: 'Évolution de l’humidité sur les 10 dernières mesures.',
    ),
    SensorInfo(
      path: 'MQ2/gasLevel_history',
      title: 'Gaz MQ2',
      unit: 'ppm',
      color: Colors.green,
      description:
          'Évolution du niveau de gaz MQ2 sur les 10 dernières mesures.',
    ),
    SensorInfo(
      path: 'MQ135/gasLevel_history',
      title: 'Gaz MQ135',
      unit: 'ppm',
      color: Colors.orange,
      description:
          'Évolution du niveau de gaz MQ135 sur les 10 dernières mesures.',
    ),
  ];

  late Map<String, bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {for (var s in sensors) s.title: true};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Visualisation des données')),
      body: Column(
        children: [
          // Sélection dynamique des capteurs
          Padding(
            padding: EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: sensors.map((s) {
                return FilterChip(
                  label: Text(s.title),
                  selected: _selected[s.title]!,
                  onSelected: (sel) {
                    setState(() => _selected[s.title] = sel);
                  },
                );
              }).toList(),
            ),
          ),
          // Affichage des graphes sélectionnés
          Expanded(
            child: ListView(
              children: sensors
                  .where((s) => _selected[s.title]!)
                  .map((s) => SensorGraph(sensor: s))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
