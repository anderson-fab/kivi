import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

class AgriculturePage extends StatefulWidget {
  @override
  _AgriculturePageState createState() => _AgriculturePageState();
}

class _AgriculturePageState extends State<AgriculturePage> {
  // Firebase
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Données
  double _temperature = 0.0;
  double _humidity = 0.0;
  double _nh3 = 0.0;
  double _smoke = 0.0;
  Map<String, dynamic> _weatherData = {};
  Map<String, dynamic> _currentSeuils = {};
  String _currentLocation = "Brazzaville"; // Valeur par défaut
  Position? _currentPosition;

  // Listes
  final List<String> _cultures = [
    'Manioc',
    'Maïs',
    'Arachide',
    'Banane plantain',
    'Patate douce',
    'Tomate',
    'Oignon',
    'Choux',
    'Gombo',
    'Épinards',
    'Aubergine',
    'Piment',
    'Concombre',
  ];

  final List<String> _capteursDisponibles = ['DHT11', 'MQ2', 'MQ135'];
  List<Map<String, dynamic>> _parcelles = [];
  List<String> _selectedCapteurs = [];

  // Formulaires
  final _parcelleFormKey = GlobalKey<FormState>();
  final _capteurFormKey = GlobalKey<FormState>();
  final _seuilFormKey = GlobalKey<FormState>();

  String _nomParcelle = '';
  String _selectedCulture = 'Manioc';
  String _typeEnvironnement = 'Plein air';
  String _selectedParcelle = '';

  // Seuils par défaut pour chaque culture
  final Map<String, Map<String, dynamic>> _seuilsCulture = {
    'Manioc': {
      'tempMin': 25,
      'tempMax': 35,
      'humMin': 60,
      'humMax': 80,
      'airPollutionMax': 200,
      'flammableGasMax': 100,
    },
    'Maïs': {
      'tempMin': 18,
      'tempMax': 30,
      'humMin': 50,
      'humMax': 70,
      'airPollutionMax': 200,
      'flammableGasMax': 100,
    },
    'Tomate': {
      'tempMin': 20,
      'tempMax': 28,
      'humMin': 60,
      'humMax': 85,
      'airPollutionMax': 200,
      'flammableGasMax': 100,
    },
    'Arachide': {
      'tempMin': 20,
      'tempMax': 30,
      'humMin': 50,
      'humMax': 70,
      'airPollutionMax': 200,
      'flammableGasMax': 100,
    },
    'Banane plantain': {
      'tempMin': 22,
      'tempMax': 32,
      'humMin': 70,
      'humMax': 85,
      'airPollutionMax': 200,
      'flammableGasMax': 100,
    },
    'Patate douce': {
      'tempMin': 18,
      'tempMax': 28,
      'humMin': 60,
      'humMax': 80,
      'airPollutionMax': 200,
      'flammableGasMax': 100,
    },
    'Oignon': {
      'tempMin': 15,
      'tempMax': 25,
      'humMin': 50,
      'humMax': 70,
      'airPollutionMax': 200,
      'flammableGasMax': 100,
    },
    'Choux': {
      'tempMin': 15,
      'tempMax': 22,
      'humMin': 60,
      'humMax': 80,
      'airPollutionMax': 200,
      'flammableGasMax': 100,
    },
    'Gombo': {
      'tempMin': 22,
      'tempMax': 32,
      'humMin': 60,
      'humMax': 80,
      'airPollutionMax': 200,
      'flammableGasMax': 100,
    },
    'Épinards': {
      'tempMin': 15,
      'tempMax': 22,
      'humMin': 70,
      'humMax': 85,
      'airPollutionMax': 200,
      'flammableGasMax': 100,
    },
    'Aubergine': {
      'tempMin': 20,
      'tempMax': 30,
      'humMin': 60,
      'humMax': 80,
      'airPollutionMax': 200,
      'flammableGasMax': 100,
    },
    'Piment': {
      'tempMin': 20,
      'tempMax': 30,
      'humMin': 50,
      'humMax': 70,
      'airPollutionMax': 200,
      'flammableGasMax': 100,
    },
    'Concombre': {
      'tempMin': 20,
      'tempMax': 28,
      'humMin': 70,
      'humMax': 85,
      'airPollutionMax': 200,
      'flammableGasMax': 100,
    },
  };

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _initFirebase();
    _determinePosition().then((_) {
      _fetchWeatherData();
    });
    _loadParcelles();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Les services de localisation sont désactivés.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Les permissions de localisation sont refusées');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Les permissions de localisation sont définitivement refusées, nous ne pouvons pas les demander.',
      );
    }

    _currentPosition = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation =
          "${_currentPosition?.latitude.toStringAsFixed(4)},${_currentPosition?.longitude.toStringAsFixed(4)}";
    });
  }

  void _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'agriculture_channel',
          'Alertes Agricoles',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }

  void _initFirebase() {
    _database.child('DHT/temperature').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final newTemp = (event.snapshot.value as num).toDouble();
        setState(() => _temperature = newTemp);
        _checkAlerts(newTemp, null, null, null);
      }
    });

    _database.child('DHT/humidity').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final newHumidity = (event.snapshot.value as num).toDouble();
        setState(() => _humidity = newHumidity);
        _checkAlerts(null, newHumidity, null, null);
      }
    });

    _database.child('MQ135/gasLevel').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final newNh3 = (event.snapshot.value as num).toDouble();
        setState(() => _nh3 = newNh3);
        _checkAlerts(null, null, newNh3, null);
      }
    });

    _database.child('MQ2/gasLevel').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final newSmoke = (event.snapshot.value as num).toDouble();
        setState(() => _smoke = newSmoke);
        _checkAlerts(null, null, null, newSmoke);
      }
    });
  }

  void _checkAlerts(
    double? temp,
    double? humidity,
    double? nh3,
    double? smoke,
  ) {
    for (var parcelle in _parcelles) {
      final seuils = parcelle['seuils'] ?? {};
      final parcelleNom = parcelle['nom'] ?? 'Parcelle';
      final culture = parcelle['culture'] ?? 'Culture';

      if (temp != null) {
        if (temp < (seuils['tempMin'] ?? 0)) {
          _showNotification(
            'Alerte Température',
            '$parcelleNom ($culture): Température trop basse!',
          );
        } else if (temp > (seuils['tempMax'] ?? 50)) {
          _showNotification(
            'Alerte Température',
            '$parcelleNom ($culture): Température trop élevée!',
          );
        }
      }

      if (humidity != null) {
        if (humidity < (seuils['humMin'] ?? 0)) {
          _showNotification(
            'Alerte Humidité',
            '$parcelleNom ($culture): Humidité trop basse!',
          );
        } else if (humidity > (seuils['humMax'] ?? 100)) {
          _showNotification(
            'Alerte Humidité',
            '$parcelleNom ($culture): Humidité trop élevée!',
          );
        }
      }

      if (nh3 != null && nh3 > (seuils['airPollutionMax'] ?? 200)) {
        _showNotification(
          'Alerte Pollution',
          '$parcelleNom ($culture): Niveau de pollution de l\'air élevé!',
        );
      }

      if (smoke != null && smoke > (seuils['flammableGasMax'] ?? 100)) {
        _showNotification(
          'Alerte Gaz',
          '$parcelleNom ($culture): Niveau de gaz inflammable élevé!',
        );
      }
    }

    // Vérifier les alertes météo
    _checkWeatherAlerts();
  }

  void _checkWeatherAlerts() {
    if (_weatherData.isEmpty) return;

    final alerts = _weatherData['alerts']?['alert'] ?? [];
    for (var alert in alerts) {
      _showNotification(
        'Alerte Météo: ${alert['event']}',
        alert['description'],
      );
    }

    // Vérifier les conditions météo critiques
    final current = _weatherData['current'];
    final forecast = _weatherData['forecast']['forecastday'][0]['day'];

    // Alerte gelée
    if (forecast['mintemp_c'] < 5) {
      _showNotification(
        'Alerte Gel',
        'Températures minimales très basses prévues! Protégez vos cultures sensibles.',
      );
    }

    // Alerte sécheresse
    if (forecast['daily_will_it_rain'] == 0 && forecast['avghumidity'] < 40) {
      _showNotification(
        'Alerte Sécheresse',
        'Conditions sèches prévues. Augmentez l\'irrigation.',
      );
    }

    // Alerte UV intense
    if (current['uv'] > 8) {
      _showNotification(
        'Alerte UV Intense',
        'Indice UV très élevé. Protégez les cultures sensibles avec des filets d\'ombrage.',
      );
    }
  }

  Future<void> _fetchWeatherData() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.weatherapi.com/v1/forecast.json?key=5643ba96fb5d40d5895224116250205&q=$_currentLocation&days=7&aqi=yes&alerts=yes&lang=fr',
        ),
      );

      if (response.statusCode == 200) {
        setState(() => _weatherData = json.decode(response.body));
        _checkWeatherAlerts();
      }
    } catch (e) {
      print('Erreur météo: $e');
    }
  }

  void _loadParcelles() {
    setState(() {
      _parcelles = [
        {
          'id': '1',
          'nom': 'Champ Nord',
          'culture': 'Manioc',
          'environnement': 'Plein air',
          'capteurs': ['DHT11'],
          'seuils': _seuilsCulture['Manioc'],
        },
      ];
      if (_parcelles.isNotEmpty) {
        _selectedParcelle = _parcelles[0]['id']?.toString() ?? '';
      }
    });
  }

  Widget _buildWeatherCard() {
    if (_weatherData.isEmpty) return SizedBox();

    final current = _weatherData['current'];
    final forecast = _weatherData['forecast']['forecastday'][0]['day'];
    final alerts = _weatherData['alerts']?['alert'] ?? [];

    // Nettoyer la description météo
    String weatherCondition = current['condition']['text'] ?? '';
    weatherCondition = weatherCondition.replaceAll(RegExp(r'[^\w\s]+'), '');

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Météo actuelle - $_currentLocation",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _fetchWeatherData,
                  tooltip: "Actualiser",
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${current['temp_c']}°C",
                      style: TextStyle(fontSize: 24),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.5,
                      child: Text(
                        weatherCondition,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    Text("Ressenti: ${current['feelslike_c']}°C"),
                  ],
                ),
                Image.network(
                  "https:${current['condition']['icon']}",
                  width: 64,
                  height: 64,
                ),
              ],
            ),
            SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildWeatherInfo("💧 Humidité", "${current['humidity']}%"),
                  _buildWeatherInfo(
                    "🌧 Pluie",
                    "${forecast['totalprecip_mm']}mm",
                  ),
                  _buildWeatherInfo("💨 Vent", "${current['wind_kph']}km/h"),
                  _buildWeatherInfo("☀️ UV", "${current['uv']}"),
                ],
              ),
            ),
            SizedBox(height: 10),
            if (alerts.isNotEmpty) ...[
              Text(
                "Alertes Météo:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 5),
              ...alerts
                  .map<Widget>(
                    (alert) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        "⚠️ ${alert['event']}: ${alert['description']}",
                        style: TextStyle(color: Colors.red),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  )
                  .toList(),
              SizedBox(height: 10),
            ],
            Text(
              "Prévisions sur 7 jours:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    _weatherData['forecast']['forecastday'].map<Widget>((day) {
                      final date = DateFormat(
                        'EEE d',
                      ).format(DateTime.parse(day['date']));
                      return Container(
                        margin: EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            Text(date),
                            Image.network(
                              "https:${day['day']['condition']['icon']}",
                              width: 40,
                              height: 40,
                            ),
                            Text("${day['day']['avgtemp_c']}°C"),
                            Text("💧 ${day['day']['avghumidity']}%"),
                            Text("🌧 ${day['day']['totalprecip_mm']}mm"),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherInfo(String label, String value) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildParcelleCard(Map<String, dynamic> parcelle) {
    final seuils = parcelle['seuils'] ?? {};
    bool tempOK =
        _temperature >= (seuils['tempMin'] ?? 0) &&
        _temperature <= (seuils['tempMax'] ?? 50);
    bool humOK =
        _humidity >= (seuils['humMin'] ?? 0) &&
        _humidity <= (seuils['humMax'] ?? 100);
    bool airPollutionOK = _nh3 <= (seuils['airPollutionMax'] ?? 200);
    bool flammableGasOK = _smoke <= (seuils['flammableGasMax'] ?? 100);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showParcelleDetails(parcelle),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    parcelle['nom'] ?? 'Parcelle sans nom',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _supprimerParcelle(parcelle['id'] ?? ''),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.eco, size: 16, color: Colors.green),
                  SizedBox(width: 5),
                  Text(parcelle['culture'] ?? 'Culture non spécifiée'),
                ],
              ),
              SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.landscape, size: 16, color: Colors.green),
                  SizedBox(width: 5),
                  Text(
                    parcelle['environnement'] ?? 'Environnement non spécifié',
                  ),
                ],
              ),
              SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.sensors, size: 16, color: Colors.green),
                  SizedBox(width: 5),
                  Text(
                    "${(parcelle['capteurs'] as List?)?.length ?? 0} capteurs",
                  ),
                ],
              ),
              SizedBox(height: 15),
              if ((parcelle['capteurs'] as List?)?.contains('DHT11') ??
                  false) ...[
                _buildStatusIndicator(
                  "Température",
                  _temperature,
                  "°C",
                  tempOK,
                  seuils['tempMin'],
                  seuils['tempMax'],
                ),
                _buildStatusIndicator(
                  "Humidité",
                  _humidity,
                  "%",
                  humOK,
                  seuils['humMin'],
                  seuils['humMax'],
                ),
              ],
              if ((parcelle['capteurs'] as List?)?.contains('MQ135') ?? false)
                _buildStatusIndicator(
                  "Pollution air",
                  _nh3,
                  "ppm",
                  airPollutionOK,
                  null,
                  seuils['airPollutionMax'],
                ),
              if ((parcelle['capteurs'] as List?)?.contains('MQ2') ?? false)
                _buildStatusIndicator(
                  "Gaz inflammable",
                  _smoke,
                  "ppm",
                  flammableGasOK,
                  null,
                  seuils['flammableGasMax'],
                ),
              _buildRecommendations(parcelle, tempOK, humOK),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(
    String label,
    double value,
    String unit,
    bool isOK,
    dynamic min,
    dynamic max,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isOK ? Icons.check_circle : Icons.warning,
            color: isOK ? Colors.green : Colors.orange,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                LinearProgressIndicator(
                  value: _calculateProgress(value, min, max),
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOK ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text("${value.toStringAsFixed(1)}$unit"),
        ],
      ),
    );
  }

  double _calculateProgress(double value, dynamic min, dynamic max) {
    final minVal = min is num ? min.toDouble() : 0.0;
    final maxVal = max is num ? max.toDouble() : 100.0;
    if (min == null) return (value / maxVal).clamp(0.0, 1.0);
    return ((value - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
  }

  Widget _buildRecommendations(
    Map<String, dynamic> parcelle,
    bool tempOK,
    bool humOK,
  ) {
    final culture = parcelle['culture'] ?? 'cette culture';
    final seuils = parcelle['seuils'] ?? {};
    List<String> recommendations = [];

    // Recommendations spécifiques pour chaque culture
    if (!tempOK) {
      if (_temperature < (seuils['tempMin'] ?? 0)) {
        switch (culture) {
          case 'Manioc':
            recommendations.add(
              "🌡 Température trop basse pour le manioc. Couvrez les plants avec des bâches ou paillis.",
            );
            break;
          case 'Maïs':
            recommendations.add(
              "🌡 Température trop basse pour le maïs. Utilisez des tunnels de protection.",
            );
            break;
          case 'Tomate':
            recommendations.add(
              "🌡 Température trop basse pour les tomates. Rentrez les plants en serre.",
            );
            break;
          case 'Banane plantain':
            recommendations.add(
              "🌡 Température trop basse pour les bananes plantains. Protégez les plants avec des sacs en plastique.",
            );
            break;
          case 'Patate douce':
            recommendations.add(
              "🌡 Température trop basse pour les patates douces. Couvrez avec un paillis épais.",
            );
            break;
          default:
            recommendations.add(
              "🌡 Température trop basse pour $culture. Protégez les plants du froid.",
            );
        }
      } else {
        switch (culture) {
          case 'Manioc':
            recommendations.add(
              "🌡 Température trop élevée pour le manioc. Augmentez l'arrosage le matin.",
            );
            break;
          case 'Maïs':
            recommendations.add(
              "🌡 Température trop élevée pour le maïs. Arrosez abondamment en soirée.",
            );
            break;
          case 'Tomate':
            recommendations.add(
              "🌡 Température trop élevée pour les tomates. Ombrez les plants l'après-midi.",
            );
            break;
          case 'Arachide':
            recommendations.add(
              "🌡 Température trop élevée pour les arachides. Arrosez légèrement mais fréquemment.",
            );
            break;
          default:
            recommendations.add(
              "🌡 Température trop élevée pour $culture. Augmentez l'arrosage.",
            );
        }
      }
    }

    if (!humOK) {
      if (_humidity < (seuils['humMin'] ?? 0)) {
        switch (culture) {
          case 'Manioc':
            recommendations.add(
              "💧 Humidité trop basse pour le manioc. Arrosez tous les 2 jours.",
            );
            break;
          case 'Maïs':
            recommendations.add(
              "💧 Humidité trop basse pour le maïs. Irriguez abondamment.",
            );
            break;
          case 'Tomate':
            recommendations.add(
              "💧 Humidité trop basse pour les tomates. Vaporisez les plants matin et soir.",
            );
            break;
          case 'Épinards':
            recommendations.add(
              "💧 Humidité trop basse pour les épinards. Arrosez quotidiennement.",
            );
            break;
          default:
            recommendations.add(
              "💧 Humidité trop basse pour $culture. Augmentez la fréquence d'arrosage.",
            );
        }
      } else {
        switch (culture) {
          case 'Manioc':
            recommendations.add(
              "💧 Humidité trop élevée pour le manioc. Aérez la parcelle pour éviter la pourriture.",
            );
            break;
          case 'Maïs':
            recommendations.add(
              "💧 Humidité trop élevée pour le maïs. Espacez les plants pour améliorer la circulation d'air.",
            );
            break;
          case 'Tomate':
            recommendations.add(
              "💧 Humidité trop élevée pour les tomates. Réduisez l'arrosage et traitez préventivement contre le mildiou.",
            );
            break;
          case 'Oignon':
            recommendations.add(
              "💧 Humidité trop élevée pour les oignons. Réduisez l'arrosage pour éviter le pourrissement.",
            );
            break;
          default:
            recommendations.add(
              "💧 Humidité trop élevée pour $culture. Réduisez l'arrosage et aérez.",
            );
        }
      }
    }

    // Ajout des recommandations météo spécifiques
    if (_weatherData.isNotEmpty) {
      final forecast = _weatherData['forecast']['forecastday'][0]['day'];

      // Recommandations basées sur les prévisions de pluie
      if (forecast['daily_will_it_rain'] == 1) {
        recommendations.add(
          "🌧 Pluie prévue (${forecast['totalprecip_mm']}mm): Évitez les traitements foliaires aujourd'hui.",
        );
      } else if (forecast['avghumidity'] < 40) {
        recommendations.add(
          "☀️ Temps sec prévu: Augmentez l'arrosage pour maintenir l'humidité du sol.",
        );
      }

      // Recommandations basées sur l'UV
      final uv = _weatherData['current']['uv'];
      if (uv > 8) {
        recommendations.add(
          "☀️ UV très élevés ($uv): Protégez les cultures sensibles avec des filets d'ombrage.",
        );
      } else if (uv < 3) {
        recommendations.add(
          "⛅ UV faibles: Profitez-en pour effectuer les travaux de maintenance.",
        );
      }
    }

    // Ajout des recommandations générales si tout est OK
    if (tempOK && humOK) {
      switch (culture) {
        case 'Manioc':
          recommendations.add(
            "✅ Conditions idéales pour le manioc. Continuez l'entretien habituel.",
          );
          break;
        case 'Maïs':
          recommendations.add(
            "✅ Conditions parfaites pour le maïs. Surveillez l'apparition de parasites.",
          );
          break;
        case 'Tomate':
          recommendations.add(
            "✅ Environnement optimal pour les tomates. Pensez à tailler les gourmands.",
          );
          break;
        case 'Arachide':
          recommendations.add(
            "✅ Conditions excellentes pour les arachides. Buttez les plants si nécessaire.",
          );
          break;
        default:
          recommendations.add(
            "✅ Conditions excellentes pour $culture. Tout va bien!",
          );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10),
        Text(
          "Recommandations:",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color:
                recommendations.any(
                      (r) =>
                          r.contains("🌡") ||
                          r.contains("💧") ||
                          r.contains("🌧") ||
                          r.contains("☀️"),
                    )
                    ? Colors.orange[800]
                    : Colors.green[800],
          ),
        ),
        ...recommendations
            .map(
              (r) => Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  "- $r",
                  style: TextStyle(
                    color:
                        r.startsWith("✅") ? Colors.green : Colors.orange[800],
                  ),
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  void _showParcelleDetails(Map<String, dynamic> parcelle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        parcelle['nom'] ?? 'Parcelle sans nom',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.settings),
                        onPressed: () {
                          Navigator.pop(context);
                          _showConfigurerSeuilsDialog(parcelle);
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildDetailRow(
                    "Culture",
                    parcelle['culture'] ?? 'Non spécifiée',
                    Icons.eco,
                  ),
                  _buildDetailRow(
                    "Environnement",
                    parcelle['environnement'] ?? 'Non spécifié',
                    Icons.landscape,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Capteurs associés:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...((parcelle['capteurs'] as List?) ?? [])
                      .map<Widget>(
                        (capteur) => _buildDetailRow(
                          capteur.toString(),
                          "Connecté",
                          Icons.sensors,
                        ),
                      )
                      .toList(),
                  SizedBox(height: 16),
                  Text(
                    "Seuils configurés:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if ((parcelle['capteurs'] as List?)?.contains('DHT11') ??
                      false) ...[
                    _buildDetailRow(
                      "Température",
                      "${parcelle['seuils']?['tempMin'] ?? 'N/A'}°C - ${parcelle['seuils']?['tempMax'] ?? 'N/A'}°C",
                      Icons.thermostat,
                    ),
                    _buildDetailRow(
                      "Humidité",
                      "${parcelle['seuils']?['humMin'] ?? 'N/A'}% - ${parcelle['seuils']?['humMax'] ?? 'N/A'}%",
                      Icons.opacity,
                    ),
                  ],
                  if ((parcelle['capteurs'] as List?)?.contains('MQ135') ??
                      false)
                    _buildDetailRow(
                      "Pollution air",
                      "Max: ${parcelle['seuils']?['airPollutionMax'] ?? 'N/A'}ppm",
                      Icons.air,
                    ),
                  if ((parcelle['capteurs'] as List?)?.contains('MQ2') ?? false)
                    _buildDetailRow(
                      "Gaz inflammable",
                      "Max: ${parcelle['seuils']?['flammableGasMax'] ?? 'N/A'}ppm",
                      Icons.local_fire_department,
                    ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showConfigurerSeuilsDialog(parcelle);
                    },
                    child: Text("Modifier les seuils"),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green[800]),
          SizedBox(width: 10),
          Text("$label: ", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  void _showConfigurerSeuilsDialog(Map<String, dynamic> parcelle) {
    _currentSeuils = Map.from(parcelle['seuils'] ?? {});

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              "Configurer les seuils",
              style: TextStyle(color: Colors.green[800]),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: _seuilFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((parcelle['capteurs'] as List?)?.contains('DHT11') ??
                        false) ...[
                      Text(
                        "Température (°C)",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue:
                                  (parcelle['seuils']?['tempMin'] ?? 0)
                                      .toString(),
                              decoration: InputDecoration(labelText: "Min"),
                              keyboardType: TextInputType.number,
                              onSaved:
                                  (value) =>
                                      _currentSeuils['tempMin'] =
                                          double.tryParse(value ?? '0') ?? 0,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue:
                                  (parcelle['seuils']?['tempMax'] ?? 30)
                                      .toString(),
                              decoration: InputDecoration(labelText: "Max"),
                              keyboardType: TextInputType.number,
                              onSaved:
                                  (value) =>
                                      _currentSeuils['tempMax'] =
                                          double.tryParse(value ?? '30') ?? 30,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Humidité (%)",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue:
                                  (parcelle['seuils']?['humMin'] ?? 0)
                                      .toString(),
                              decoration: InputDecoration(labelText: "Min"),
                              keyboardType: TextInputType.number,
                              onSaved:
                                  (value) =>
                                      _currentSeuils['humMin'] =
                                          double.tryParse(value ?? '0') ?? 0,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue:
                                  (parcelle['seuils']?['humMax'] ?? 100)
                                      .toString(),
                              decoration: InputDecoration(labelText: "Max"),
                              keyboardType: TextInputType.number,
                              onSaved:
                                  (value) =>
                                      _currentSeuils['humMax'] =
                                          double.tryParse(value ?? '100') ??
                                          100,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                    ],
                    if ((parcelle['capteurs'] as List?)?.contains('MQ135') ??
                        false) ...[
                      Text(
                        "Pollution air (ppm)",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue:
                                  (parcelle['seuils']?['airPollutionMin'] ?? 0)
                                      .toString(),
                              decoration: InputDecoration(labelText: "Min"),
                              keyboardType: TextInputType.number,
                              onSaved:
                                  (value) =>
                                      _currentSeuils['airPollutionMin'] =
                                          double.tryParse(value ?? '0') ?? 0,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue:
                                  (parcelle['seuils']?['airPollutionMax'] ??
                                          200)
                                      .toString(),
                              decoration: InputDecoration(labelText: "Max"),
                              keyboardType: TextInputType.number,
                              onSaved:
                                  (value) =>
                                      _currentSeuils['airPollutionMax'] =
                                          double.tryParse(value ?? '200') ??
                                          200,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                    ],
                    if ((parcelle['capteurs'] as List?)?.contains('MQ2') ??
                        false) ...[
                      Text(
                        "Gaz inflammable (ppm)",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue:
                                  (parcelle['seuils']?['flammableGasMin'] ?? 0)
                                      .toString(),
                              decoration: InputDecoration(labelText: "Min"),
                              keyboardType: TextInputType.number,
                              onSaved:
                                  (value) =>
                                      _currentSeuils['flammableGasMin'] =
                                          double.tryParse(value ?? '0') ?? 0,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue:
                                  (parcelle['seuils']?['flammableGasMax'] ??
                                          100)
                                      .toString(),
                              decoration: InputDecoration(labelText: "Max"),
                              keyboardType: TextInputType.number,
                              onSaved:
                                  (value) =>
                                      _currentSeuils['flammableGasMax'] =
                                          double.tryParse(value ?? '100') ??
                                          100,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Annuler"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _sauvegarderSeuils(parcelle['id'] ?? ''),
                child: Text("Enregistrer"),
              ),
            ],
          ),
    );
  }

  void _sauvegarderSeuils(String parcelleId) {
    if (_seuilFormKey.currentState?.validate() ?? false) {
      _seuilFormKey.currentState?.save();

      final parcelleIndex = _parcelles.indexWhere((p) => p['id'] == parcelleId);
      if (parcelleIndex != -1) {
        setState(() {
          _parcelles[parcelleIndex]['seuils'] = Map.from(_currentSeuils);
        });
        Navigator.pop(context);
      }
    }
  }

  void _supprimerParcelle(String id) {
    setState(() {
      _parcelles.removeWhere((parcelle) => parcelle['id'] == id);
    });
  }

  void _showAddParcelleDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              "Nouvelle parcelle",
              style: TextStyle(color: Colors.green[800]),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: _parcelleFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: "Nom de la parcelle",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.grass),
                      ),
                      validator:
                          (value) =>
                              value?.isEmpty ?? true ? "Obligatoire" : null,
                      onSaved: (value) => _nomParcelle = value ?? '',
                    ),
                    SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _selectedCulture,
                      decoration: InputDecoration(
                        labelText: "Culture",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.eco),
                      ),
                      items:
                          _cultures
                              .map(
                                (culture) => DropdownMenuItem(
                                  value: culture,
                                  child: Text(culture),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) => setState(
                            () => _selectedCulture = value ?? 'Manioc',
                          ),
                    ),
                    SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _typeEnvironnement,
                      decoration: InputDecoration(
                        labelText: "Environnement",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.landscape),
                      ),
                      items:
                          ['Plein air', 'Serre', 'Irrigué']
                              .map(
                                (env) => DropdownMenuItem(
                                  value: env,
                                  child: Text(env),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) => setState(
                            () => _typeEnvironnement = value ?? 'Plein air',
                          ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Annuler"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  foregroundColor: Colors.white,
                ),
                onPressed: _ajouterParcelle,
                child: Text("Enregistrer"),
              ),
            ],
          ),
    );
  }

  void _ajouterParcelle() {
    if (_parcelleFormKey.currentState?.validate() ?? false) {
      _parcelleFormKey.currentState?.save();

      final String nouvelleParcelleId =
          DateTime.now().millisecondsSinceEpoch.toString();
      final Map<String, dynamic> nouvelleParcelle = {
        'id': nouvelleParcelleId,
        'nom': _nomParcelle,
        'culture': _selectedCulture,
        'environnement': _typeEnvironnement,
        'capteurs': [],
        'seuils': _seuilsCulture[_selectedCulture] ?? _seuilsCulture['Manioc'],
      };

      setState(() {
        _parcelles.add(nouvelleParcelle);
        _selectedParcelle = nouvelleParcelleId;
      });
      Navigator.pop(context);
    }
  }

  void _showAddCapteurDialog() {
    if (_parcelles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Créez d'abord une parcelle")));
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(
                  "Associer des capteurs",
                  style: TextStyle(color: Colors.green[800]),
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: _capteurFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value:
                              _selectedParcelle.isNotEmpty
                                  ? _selectedParcelle
                                  : null,
                          decoration: InputDecoration(
                            labelText: "Parcelle",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.map),
                          ),
                          items:
                              _parcelles
                                  .map(
                                    (parcelle) => DropdownMenuItem<String>(
                                      value: parcelle['id']?.toString(),
                                      child: Text(
                                        parcelle['nom']?.toString() ??
                                            'Parcelle sans nom',
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (value) => setState(
                                () => _selectedParcelle = value ?? '',
                              ),
                          validator:
                              (value) =>
                                  value == null || value.isEmpty
                                      ? "Sélection requise"
                                      : null,
                        ),
                        SizedBox(height: 20),
                        Text(
                          "Sélectionnez les capteurs:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ..._capteursDisponibles
                            .map(
                              (capteur) => CheckboxListTile(
                                title: Text(capteur),
                                value: _selectedCapteurs.contains(capteur),
                                onChanged: (selected) {
                                  setState(() {
                                    if (selected == true) {
                                      _selectedCapteurs.add(capteur);
                                    } else {
                                      _selectedCapteurs.remove(capteur);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Annuler"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _associerCapteurs(),
                    child: Text("Associer"),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _associerCapteurs() {
    if (_selectedParcelle.isNotEmpty && _selectedCapteurs.isNotEmpty) {
      final parcelleIndex = _parcelles.indexWhere(
        (p) => p['id'] == _selectedParcelle,
      );
      if (parcelleIndex != -1) {
        setState(() {
          _parcelles[parcelleIndex]['capteurs'] = List.from(_selectedCapteurs);

          // Initialiser les seuils pour les nouveaux capteurs
          final culture = _parcelles[parcelleIndex]['culture'] ?? 'Manioc';
          final defaultSeuils =
              _seuilsCulture[culture] ?? _seuilsCulture['Manioc']!;

          _parcelles[parcelleIndex]['seuils'] = {
            'tempMin': defaultSeuils['tempMin'],
            'tempMax': defaultSeuils['tempMax'],
            'humMin': defaultSeuils['humMin'],
            'humMax': defaultSeuils['humMax'],
            if (_selectedCapteurs.contains('MQ135')) ...{
              'airPollutionMin': defaultSeuils['airPollutionMin'] ?? 0,
              'airPollutionMax': defaultSeuils['airPollutionMax'] ?? 200,
            },
            if (_selectedCapteurs.contains('MQ2')) ...{
              'flammableGasMin': defaultSeuils['flammableGasMin'] ?? 0,
              'flammableGasMax': defaultSeuils['flammableGasMax'] ?? 100,
            },
          };

          _selectedCapteurs.clear();
        });
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Agriculture Intelligente",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green[800],
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddParcelleDialog,
            tooltip: "Ajouter une parcelle",
          ),
          IconButton(
            icon: Icon(Icons.sensors),
            onPressed: _showAddCapteurDialog,
            tooltip: "Associer des capteurs",
          ),
          IconButton(
            icon: Icon(Icons.location_on),
            onPressed: () {
              _determinePosition().then((_) {
                _fetchWeatherData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Localisation actualisée: $_currentLocation"),
                  ),
                );
              });
            },
            tooltip: "Actualiser la localisation",
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[50]!, Colors.white],
          ),
        ),
        child: Column(
          children: [
            _buildWeatherCard(),
            Expanded(
              child:
                  _parcelles.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grass, size: 50, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              "Aucune parcelle configurée",
                              style: TextStyle(fontSize: 18),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Commencez par ajouter une parcelle",
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[800],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _showAddParcelleDialog,
                              child: Text("Ajouter une parcelle"),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _parcelles.length,
                        itemBuilder:
                            (context, index) => Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: _buildParcelleCard(_parcelles[index]),
                            ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
