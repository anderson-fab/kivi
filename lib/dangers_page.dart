import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class DangersPage extends StatefulWidget {
  @override
  _DangersPageState createState() => _DangersPageState();
}

class _DangersPageState extends State<DangersPage> {
  final database = FirebaseDatabase.instance.ref();
  String selectedRoom = 'Cuisine';
  bool isDiagnosticMode = false;
  Map<String, dynamic> diagnosticResults = {};
  Map<String, Map<String, double>> roomThresholds = {
    'Cuisine': {'temp': 35.0, 'humidity': 70.0, 'mq2': 100.0, 'mq135': 1000.0},
    'Chambre': {'temp': 38.0, 'humidity': 30.0, 'mq2': 50.0, 'mq135': 1200.0},
    'Salle de Bain': {
      'temp': 40.0,
      'humidity': 85.0,
      'mq2': 50.0,
      'mq135': 800.0,
    },
    'Garde-Manger': {
      'temp': 28.0,
      'humidity': 80.0,
      'mq2': 50.0,
      'mq135': 500.0,
    },
    'Salon': {'temp': 35.0, 'humidity': 70.0, 'mq2': 50.0, 'mq135': 1500.0},
    'Garage': {'temp': 45.0, 'humidity': 60.0, 'mq2': 50.0, 'mq135': 50.0},
  };

  Map<String, dynamic> sensorData = {
    'temperature': 25.0,
    'humidity': 45.0,
    'mq2': 20.0,
    'mq135': 800.0,
  };

  @override
  void initState() {
    super.initState();
    _setupFirebaseListener();
  }

  void _setupFirebaseListener() {
    database.child('DHT').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && mounted) {
        setState(() {
          sensorData['temperature'] = data['temperature']?.toDouble() ?? 0.0;
          sensorData['humidity'] = data['humidity']?.toDouble() ?? 0.0;
        });
      }
    });

    database.child('MQ2').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && mounted) {
        setState(() {
          sensorData['mq2'] = data['gasLevel']?.toDouble() ?? 0.0;
        });
      }
    });

    database.child('MQ135').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && mounted) {
        setState(() {
          sensorData['mq135'] = data['gasLevel']?.toDouble() ?? 0.0;
        });
      }
    });
  }

  Future<void> _startDiagnostic() async {
    if (!mounted) return;

    setState(() {
      isDiagnosticMode = true;
      diagnosticResults = {};
    });

    try {
      final now = DateTime.now();
      final startTime = now.subtract(Duration(hours: 48));
      final isoStartTime = startTime.toIso8601String();

      final tempSnapshot =
          await database
              .child('DHT/temperature_history')
              .orderByKey()
              .startAt(isoStartTime)
              .get();
      final humiditySnapshot =
          await database
              .child('DHT/humidity_history')
              .orderByKey()
              .startAt(isoStartTime)
              .get();
      final mq2Snapshot =
          await database
              .child('MQ2/gasLevel_history')
              .orderByKey()
              .startAt(isoStartTime)
              .get();
      final mq135Snapshot =
          await database
              .child('MQ135/gasLevel_history')
              .orderByKey()
              .startAt(isoStartTime)
              .get();

      final analysis = _analyzeData(
        tempData: tempSnapshot.value as Map?,
        humidityData: humiditySnapshot.value as Map?,
        mq2Data: mq2Snapshot.value as Map?,
        mq135Data: mq135Snapshot.value as Map?,
      );

      if (mounted) {
        setState(() {
          diagnosticResults = analysis;
          isDiagnosticMode = false;
        });
        _showDiagnosticDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isDiagnosticMode = false);
        _showAlert(
          'Erreur',
          'Impossible de générer le diagnostic: ${e.toString()}',
        );
      }
    }
  }

  Map<String, dynamic> _analyzeData({
    required Map? tempData,
    required Map? humidityData,
    required Map? mq2Data,
    required Map? mq135Data,
  }) {
    final thresholds = roomThresholds[selectedRoom]!;
    final alerts = <String>[];
    final stats = <String, dynamic>{};
    final List<double> tempValues = [];
    final List<double> humidityValues = [];
    final List<double> mq2Values = [];
    final List<double> mq135Values = [];

    _processData(tempData, tempValues);
    _processData(humidityData, humidityValues);
    _processData(mq2Data, mq2Values);
    _processData(mq135Data, mq135Values);

    stats['temp_avg'] = _calculateAverage(tempValues);
    stats['temp_max'] = _calculateMax(tempValues);
    stats['humidity_avg'] = _calculateAverage(humidityValues);
    stats['mq2_peaks'] = _countThresholdExceeded(mq2Values, thresholds['mq2']!);
    stats['mq135_peaks'] = _countThresholdExceeded(
      mq135Values,
      thresholds['mq135']!,
    );

    if (stats['temp_max'] > thresholds['temp']!) {
      alerts.add(
        'Température > ${thresholds['temp']}°C (max: ${stats['temp_max']?.toStringAsFixed(1)}°C)',
      );
    }
    if (selectedRoom == 'Chambre' &&
        stats['humidity_avg'] < thresholds['humidity']!) {
      alerts.add(
        'Air trop sec (moyenne: ${stats['humidity_avg']?.toStringAsFixed(1)}%)',
      );
    }
    if (stats['mq2_peaks'] > 0) {
      alerts.add('${stats['mq2_peaks']} pics de gaz détectés');
    }
    if (selectedRoom == 'Garage' && stats['mq135_peaks'] > 0) {
      alerts.add('${stats['mq135_peaks']} pics de CO dangereux');
    }

    return {
      'alerts': alerts,
      'stats': stats,
      'recommendations': _generateRecommendations(alerts),
    };
  }

  void _processData(Map? data, List<double> output) {
    if (data == null) return;
    data.forEach((key, value) {
      if (value != null) output.add(value.toDouble());
    });
  }

  double _calculateAverage(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculateMax(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a > b ? a : b);
  }

  int _countThresholdExceeded(List<double> values, double threshold) {
    return values.where((v) => v > threshold).length;
  }

  List<String> _generateRecommendations(List<String> alerts) {
    final recommendations = <String>[];
    final thresholds = roomThresholds[selectedRoom]!;

    if (alerts.any((a) => a.contains('Température'))) {
      recommendations.addAll([
        '- Installer un ventilateur/climatiseur',
        '- Vérifier l\'isolation thermique',
      ]);
    }
    if (alerts.any((a) => a.contains('Air trop sec'))) {
      recommendations.add('- Utiliser un humidificateur');
    }
    if (alerts.any((a) => a.contains('gaz détectés'))) {
      recommendations.addAll([
        '- Vérifier les fuites de gaz',
        '- Aérer immédiatement en cas d\'alerte',
      ]);
    }
    if (alerts.any((a) => a.contains('CO dangereux'))) {
      recommendations.addAll([
        '- Ne pas utiliser de groupes électrogènes en espace clos',
        '- Installer un détecteur de CO',
      ]);
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'Aucun problème majeur détecté. La qualité environnementale est bonne.',
      );
    }

    return recommendations;
  }

  void _showDiagnosticDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Rapport de Diagnostic - $selectedRoom'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Période analysée: 48 dernières heures',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  if (diagnosticResults['alerts']?.isNotEmpty ?? false) ...[
                    Text(
                      'Problèmes détectés:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    ...diagnosticResults['alerts']
                        .map<Widget>(
                          (alert) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('• $alert'),
                          ),
                        )
                        .toList(),
                    SizedBox(height: 16),
                  ],
                  Text(
                    'Statistiques:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Température moyenne: ${diagnosticResults['stats']?['temp_avg']?.toStringAsFixed(1) ?? 'N/A'}°C',
                  ),
                  Text(
                    'Température max: ${diagnosticResults['stats']?['temp_max']?.toStringAsFixed(1) ?? 'N/A'}°C',
                  ),
                  Text(
                    'Humidité moyenne: ${diagnosticResults['stats']?['humidity_avg']?.toStringAsFixed(1) ?? 'N/A'}%',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Recommandations:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  ...diagnosticResults['recommendations']
                      .map<Widget>(
                        (rec) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(rec),
                        ),
                      )
                      .toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Fermer'),
              ),
            ],
          ),
    );
  }

  void _checkForAlerts() {
    if (!mounted) return;
    final thresholds = roomThresholds[selectedRoom]!;

    if (sensorData['temperature'] > thresholds['temp']!) {
      _showAlert(
        'Température élevée',
        'La température est trop élevée dans la $selectedRoom',
      );
    }

    if (selectedRoom == 'Chambre' &&
        sensorData['humidity'] < thresholds['humidity']!) {
      _showAlert('Air trop sec', 'L\'air est trop sec pour les nourrissons');
    }

    if (sensorData['mq2'] > thresholds['mq2']!) {
      _showAlert(
        'Gaz détecté',
        'Gaz inflammable détecté dans la $selectedRoom',
        isCritical: true,
      );
    }

    if (selectedRoom == 'Garage' &&
        sensorData['mq135'] > thresholds['mq135']!) {
      _showAlert(
        'Monoxyde de carbone',
        'CO DÉTECTÉ - ÉVACUEZ IMMÉDIATEMENT',
        isCritical: true,
      );
    }
  }

  void _showAlert(String title, String message, {bool isCritical = false}) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              title,
              style: TextStyle(color: isCritical ? Colors.red : Colors.orange),
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAlerts();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Surveillance Domestique'),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildRoomSelector(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildRoomDashboard(),
                  SizedBox(height: 20),
                  _buildSensorCards(),
                  SizedBox(height: 20),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sélectionnez une pièce:', style: TextStyle(fontSize: 16)),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedRoom,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            items:
                [
                  'Cuisine',
                  'Chambre',
                  'Salle de Bain',
                  'Garde-Manger',
                  'Salon',
                  'Garage',
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
            onChanged: (newValue) {
              if (mounted) {
                setState(() {
                  selectedRoom = newValue!;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoomDashboard() {
    final thresholds = roomThresholds[selectedRoom]!;
    final isAirQualityGood = sensorData['mq135'] < thresholds['mq135']!;
    final isTempGood = sensorData['temperature'] < thresholds['temp']!;
    final isHumidityGood =
        selectedRoom == 'Salle de Bain'
            ? sensorData['humidity'] < thresholds['humidity']!
            : sensorData['humidity'] > thresholds['humidity']!;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'État actuel - $selectedRoom',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusIndicator('Air', isAirQualityGood, Icons.air),
              _buildStatusIndicator(
                'Température',
                isTempGood,
                Icons.thermostat,
              ),
              _buildStatusIndicator(
                'Humidité',
                isHumidityGood,
                Icons.water_drop,
              ),
            ],
          ),
          SizedBox(height: 16),
          if (selectedRoom == 'Cuisine') _buildCuisineSpecific(),
          if (selectedRoom == 'Chambre') _buildChambreSpecific(),
          if (selectedRoom == 'Salle de Bain') _buildSalleDeBainSpecific(),
          if (selectedRoom == 'Garde-Manger') _buildGardeMangerSpecific(),
          if (selectedRoom == 'Garage') _buildGarageSpecific(),
          if (selectedRoom == 'Salon') _buildSalonSpecific(),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isGood, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isGood ? Colors.green[100] : Colors.red[100],
          ),
          child: Icon(icon, color: isGood ? Colors.green : Colors.red),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12)),
        Text(
          isGood ? 'Bon' : 'Dangereux',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isGood ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildSensorCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildSensorCard(
            'Température',
            '${sensorData['temperature']?.toStringAsFixed(1) ?? '--'}°C',
            Icons.thermostat,
          ),
          _buildSensorCard(
            'Humidité',
            '${sensorData['humidity']?.toStringAsFixed(1) ?? '--'}%',
            Icons.water_drop,
          ),
          _buildSensorCard(
            'Gaz (MQ2)',
            '${sensorData['mq2']?.toStringAsFixed(1) ?? '--'} ppm',
            Icons.local_fire_department,
          ),
          _buildSensorCard(
            'Qualité Air',
            '${sensorData['mq135']?.toStringAsFixed(1) ?? '--'} ppm',
            Icons.air,
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(String title, String value, IconData icon) {
    return Container(
      width: 150,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: Colors.blue),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            icon: Icon(
              isDiagnosticMode ? Icons.hourglass_top : Icons.analytics,
            ),
            label: Text(
              isDiagnosticMode
                  ? 'Diagnostic en cours...'
                  : 'Lancer un diagnostic (48h)',
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
              backgroundColor: Colors.blue[50],
              foregroundColor: Colors.blue,
            ),
            onPressed: isDiagnosticMode ? null : _startDiagnostic,
          ),
          SizedBox(height: 12),
          if (selectedRoom == 'Cuisine')
            ElevatedButton.icon(
              icon: Icon(Icons.local_fire_department),
              label: Text('Conseils cuisson sécuritaire'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.orange[50],
                foregroundColor: Colors.orange,
              ),
              onPressed: _showCookingTips,
            ),
          if (selectedRoom == 'Chambre')
            ElevatedButton.icon(
              icon: Icon(Icons.nightlight_round),
              label: Text('Conseils sommeil sain'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.purple[50],
                foregroundColor: Colors.purple,
              ),
              onPressed: _showSleepTips,
            ),
        ],
      ),
    );
  }

  Widget _buildCuisineSpecific() {
    return Column(
      children: [
        Divider(),
        SizedBox(height: 8),
        Text(
          'Fonctions Cuisine',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFeatureButton('Alerte Gaz', Icons.warning, Colors.red),
            _buildFeatureButton('Cuisson', Icons.restaurant, Colors.orange),
            _buildFeatureButton('Ventilation', Icons.air, Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildChambreSpecific() {
    return Column(
      children: [
        Divider(),
        SizedBox(height: 8),
        Text(
          'Fonctions Chambre',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFeatureButton('Bébé', Icons.child_care, Colors.pink),
            _buildFeatureButton(
              'Sommeil',
              Icons.nightlight_round,
              Colors.purple,
            ),
            _buildFeatureButton('Air', Icons.air, Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildSalleDeBainSpecific() {
    return Column(
      children: [
        Divider(),
        SizedBox(height: 8),
        Text(
          'Fonctions Salle de Bain',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFeatureButton('Moisissure', Icons.clean_hands, Colors.green),
            _buildFeatureButton('Humidité', Icons.water_drop, Colors.blue),
            _buildFeatureButton('Ventilation', Icons.air, Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildGardeMangerSpecific() {
    return Column(
      children: [
        Divider(),
        SizedBox(height: 8),
        Text(
          'Fonctions Garde-Manger',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFeatureButton('Aliments', Icons.food_bank, Colors.brown),
            _buildFeatureButton('Température', Icons.thermostat, Colors.orange),
            _buildFeatureButton('Humidité', Icons.water_drop, Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildGarageSpecific() {
    return Column(
      children: [
        Divider(),
        SizedBox(height: 8),
        Text('Fonctions Garage', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFeatureButton('CO', Icons.dangerous, Colors.red),
            _buildFeatureButton('Gaz', Icons.local_gas_station, Colors.orange),
            _buildFeatureButton('Température', Icons.thermostat, Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildSalonSpecific() {
    return Column(
      children: [
        Divider(),
        SizedBox(height: 8),
        Text('Fonctions Salon', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFeatureButton('Qualité Air', Icons.air, Colors.blue),
            _buildFeatureButton('Confort', Icons.people, Colors.green),
            _buildFeatureButton('Ventilation', Icons.air, Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureButton(String label, IconData icon, Color color) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }

  void _showCookingTips() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Conseils pour une cuisson sécuritaire'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTipItem(
                    '1. Surveillez toujours la cuisson',
                    Icons.visibility,
                  ),
                  _buildTipItem(
                    '2. Éteignez le feu après utilisation',
                    Icons.fire_extinguisher,
                  ),
                  _buildTipItem('3. Aérez bien la cuisine', Icons.air),
                  _buildTipItem('4. Vérifiez les fuites de gaz', Icons.warning),
                  _buildTipItem(
                    '5. Gardez les enfants éloignés',
                    Icons.child_friendly,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Fermer'),
              ),
            ],
          ),
    );
  }

  Widget _buildTipItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showSleepTips() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Conseils pour un sommeil sain'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTipItem(
                    '1. Température idéale: 18-22°C',
                    Icons.thermostat,
                  ),
                  _buildTipItem('2. Humidité idéale: 40-60%', Icons.water_drop),
                  _buildTipItem(
                    '3. Aérez la chambre quotidiennement',
                    Icons.air,
                  ),
                  _buildTipItem(
                    '4. Évitez les appareils électroniques',
                    Icons.phone_android,
                  ),
                  _buildTipItem(
                    '5. Obscurité totale pour mieux dormir',
                    Icons.nightlight,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Fermer'),
              ),
            ],
          ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Aide - Surveillance Domestique'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cette application vous permet de surveiller les dangers domestiques en temps réel.',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Fonctionnalités:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  _buildHelpItem(
                    'Sélection de pièce',
                    'Choisissez la pièce à surveiller dans le menu déroulant',
                  ),
                  _buildHelpItem(
                    'Dashboard',
                    'Voyez l\'état global de chaque pièce',
                  ),
                  _buildHelpItem(
                    'Diagnostic',
                    'Lancez un test de 48h pour un rapport complet',
                  ),
                  _buildHelpItem(
                    'Alertes',
                    'Recevez des notifications en cas de danger',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Couleurs:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(width: 16, height: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Bon'),
                    ],
                  ),
                  Row(
                    children: [
                      Container(width: 16, height: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Dangereux'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Fermer'),
              ),
            ],
          ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(description, style: TextStyle(fontSize: 12)),
          SizedBox(height: 4),
        ],
      ),
    );
  }
}
