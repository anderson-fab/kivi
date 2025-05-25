import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PredictionPage extends StatefulWidget {
  @override
  _PredictionPageState createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _hourController = TextEditingController();
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();

  bool _isLoading = false;
  Map<String, dynamic>? _predictionResult;

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _predictionResult = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://26ae-102-129-75-181.ngrok-free.app/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'Hour': int.parse(_hourController.text),
          'Day': int.parse(_dayController.text),
          'Month': int.parse(_monthController.text),
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _predictionResult = jsonDecode(response.body);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${response.statusCode}'),
            backgroundColor: const Color.fromARGB(
              255,
              244,
              67,
              54,
            ), // Colors.red[500]
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de connexion: $e'),
          backgroundColor: const Color.fromARGB(
            255,
            244,
            67,
            54,
          ), // Colors.red[500]
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prédiction Météo'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text(
                        'Entrez les paramètres',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildInputField(
                        controller: _hourController,
                        label: 'Heure (0-23)',
                        icon: Icons.access_time,
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Champ requis';
                          final hour = int.tryParse(value);
                          if (hour == null || hour < 0 || hour > 23) {
                            return 'Heure invalide (0-23)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      _buildInputField(
                        controller: _dayController,
                        label: 'Jour (1-31)',
                        icon: Icons.calendar_today,
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Champ requis';
                          final day = int.tryParse(value);
                          if (day == null || day < 1 || day > 31) {
                            return 'Jour invalide (1-31)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      _buildInputField(
                        controller: _monthController,
                        label: 'Mois (1-12)',
                        icon: Icons.date_range,
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Champ requis';
                          final month = int.tryParse(value);
                          if (month == null || month < 1 || month > 12) {
                            return 'Mois invalide (1-12)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _predict,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                          backgroundColor: const Color.fromARGB(
                            255,
                            33,
                            150,
                            243,
                          ), // Colors.blue
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child:
                            _isLoading
                                ? CircularProgressIndicator(
                                  color: const Color.fromARGB(
                                    255,
                                    255,
                                    255,
                                    255,
                                  ),
                                ) // Colors.white
                                : Text(
                                  'Prédire',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: const Color.fromARGB(
                                      255,
                                      255,
                                      255,
                                      255,
                                    ),
                                  ),
                                ), // Colors.white
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_predictionResult != null) ...[
              const SizedBox(height: 30),
              _buildPredictionResult(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
          color: const Color.fromARGB(255, 189, 189, 189), // Colors.grey[400]
        ),
      ),
      keyboardType: TextInputType.number,
      validator: validator,
    );
  }

  Widget _buildPredictionResult() {
    final temp = _predictionResult!['temperature'];
    final humidity = _predictionResult!['humidity'];
    final recommendations = _predictionResult!['recommendations'] as List;

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Résultats de la prédiction',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildWeatherInfo(
                  icon: Icons.thermostat,
                  value: '$temp°C',
                  label: 'Température',
                  color: const Color.fromARGB(255, 255, 165, 0),
                ), // Colors.orange
                _buildWeatherInfo(
                  icon: Icons.water_drop,
                  value: '$humidity%',
                  label: 'Humidité',
                  color: const Color.fromARGB(255, 0, 0, 255),
                ), // Colors.blue
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Recommandations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 10),
            ...recommendations
                .map((rec) => _buildRecommendationCard(rec))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherInfo({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 40, color: color),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color.fromARGB(255, 119, 119, 119),
          ),
        ), // Colors.grey[600]
      ],
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> recommendation) {
    Color urgencyColor;
    switch (recommendation['urgence']) {
      case 'high':
        urgencyColor = const Color.fromARGB(
          255,
          244,
          67,
          54,
        ); // Colors.red[500]
        break;
      case 'medium':
        urgencyColor = const Color.fromARGB(255, 255, 165, 0); // Colors.orange
        break;
      default:
        urgencyColor = const Color.fromARGB(
          255,
          76,
          175,
          80,
        ); // Colors.green[500]
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: urgencyColor.withOpacity(0.1),
      child: ListTile(
        leading: Icon(_getRecommendationIcon(recommendation['type'])),
        title: Text(
          recommendation['message'],
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        subtitle: Text(
          'Priorité: ${recommendation['urgence']}',
          style: const TextStyle(color: Color.fromARGB(255, 119, 119, 119)),
        ), // Colors.grey[600]
      ),
    );
  }

  IconData _getRecommendationIcon(String type) {
    switch (type) {
      case 'climatisation':
        return Icons.ac_unit;
      case 'chauffage':
        return Icons.heat_pump;
      case 'ventilation':
        return Icons.air;
      default:
        return Icons.info;
    }
  }
}
