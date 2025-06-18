import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

// Couleurs thématiques harmonisées
const Color primaryGreen = Color(0xFF2E7D32);
const Color lightGreen = Color(0xFFE8F5E9);
const Color darkGreen = Color(0xFF1B5E20);
const Color accentGreen = Color(0xFF81C784);
const Color dangerColor = Color(0xFFD32F2F);
const Color warningColor = Color(0xFFF57C00);
const Color safeColor = Color(0xFF388E3C);
const Color cardBackground = Color(0xFFFAFAFA);

class UserProfile {
  final String id;
  final String name;
  final String profileType;
  final IconData icon;
  final Color color;

  UserProfile({
    required this.id,
    required this.name,
    required this.profileType,
    required this.icon,
    required this.color,
  });
}

class UserProfileNotifier with ChangeNotifier {
  UserProfile? _currentProfile;

  UserProfile? get currentProfile => _currentProfile;

  void setProfile(UserProfile? profile) {
    _currentProfile = profile;
    notifyListeners();
  }
}

class SantePage extends StatefulWidget {
  @override
  _SantePageState createState() => _SantePageState();
}

class _SantePageState extends State<SantePage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  double _temperature = 0.0;
  double _humidity = 0.0;
  double _nh3 = 0.0;
  double _smoke = 0.0;

  @override
  void initState() {
    super.initState();
    _listenToSensors();
  }

  void _listenToSensors() {
    _database.child('DHT/temperature').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        setState(() {
          _temperature = (event.snapshot.value as num).toDouble();
        });
      }
    });

    _database.child('DHT/humidity').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        setState(() {
          _humidity = (event.snapshot.value as num).toDouble();
        });
      }
    });

    _database.child('MQ135/gasLevel').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        setState(() {
          _nh3 = (event.snapshot.value as num).toDouble();
        });
      }
    });

    _database.child('MQ2/gasLevel').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        setState(() {
          _smoke = (event.snapshot.value as num).toDouble();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileNotifier>(
      builder: (context, profileNotifier, child) {
        return Scaffold(
          backgroundColor: lightGreen,
          appBar: AppBar(
            title: Text(
              "Santé Environnementale",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: primaryGreen,
            iconTheme: IconThemeData(color: Colors.white),
            elevation: 0,
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  if (profileNotifier.currentProfile == null) ...[
                    _buildProfileSelection(),
                  ] else ...[
                    _buildProfileHeader(profileNotifier.currentProfile!),
                    SizedBox(height: 20),
                    _buildHealthDashboard(profileNotifier.currentProfile!),
                    SizedBox(height: 20),
                    _buildNewSensorDashboard(),
                    SizedBox(height: 20),
                    _buildHealthAlerts(profileNotifier.currentProfile!),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewSensorDashboard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Données des capteurs en temps réel",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCircularGauge(
                value: _temperature,
                max: 40,
                unit: '°C',
                color: Color(0xFF2a75cf),
                icon: Icons.thermostat,
                label: 'Température',
              ),
              _buildCircularGauge(
                value: _humidity,
                max: 100,
                unit: '%',
                color: Color(0xFFffc04c),
                icon: Icons.opacity,
                label: 'Humidité',
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildMinMaxTable(),
        ],
      ),
    );
  }

  Widget _buildCircularGauge({
    required double value,
    required double max,
    required String unit,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          child: SfRadialGauge(
            axes: <RadialAxis>[
              RadialAxis(
                minimum: 0,
                maximum: max,
                showLabels: false,
                showTicks: false,
                axisLineStyle: AxisLineStyle(
                  thickness: 0.1,
                  cornerStyle: CornerStyle.bothCurve,
                  color: Colors.grey[300],
                  thicknessUnit: GaugeSizeUnit.factor,
                ),
                pointers: <GaugePointer>[
                  RangePointer(
                    value: value,
                    cornerStyle: CornerStyle.bothCurve,
                    width: 0.1,
                    sizeUnit: GaugeSizeUnit.factor,
                    color: color,
                    gradient: SweepGradient(
                      colors: [color.withOpacity(0.5), color],
                      stops: [0.1, 1.0],
                    ),
                  ),
                ],
                annotations: <GaugeAnnotation>[
                  GaugeAnnotation(
                    positionFactor: 0.1,
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 24, color: color),
                        SizedBox(height: 4),
                        Text(
                          '$value$unit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMinMaxTable() {
    return Container(
      decoration: BoxDecoration(
        color: lightGreen.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('Min', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Moy', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Max', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('${(_temperature - 2).toStringAsFixed(1)}°C'),
              Text('${_temperature.toStringAsFixed(1)}°C'),
              Text('${(_temperature + 2).toStringAsFixed(1)}°C'),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('${(_humidity - 10).toStringAsFixed(1)}%'),
              Text('${_humidity.toStringAsFixed(1)}%'),
              Text('${(_humidity + 10).toStringAsFixed(1)}%'),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('06:14', style: TextStyle(fontSize: 12)),
              Text('13:13', style: TextStyle(fontSize: 12)),
              Text('02:40', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSelection() {
    final List<UserProfile> profiles = [
      UserProfile(
        id: '1',
        name: 'Nourrisson',
        profileType: 'Nourrissons',
        icon: Icons.child_friendly,
        color: Color(0xFFF06292),
      ),
      UserProfile(
        id: '2',
        name: 'Enfant',
        profileType: 'Enfants',
        icon: Icons.child_care,
        color: Color(0xFF4FC3F7),
      ),
      UserProfile(
        id: '3',
        name: 'Asthmatique',
        profileType: 'Asthmatiques',
        icon: Icons.air,
        color: Color(0xFFBA68C8),
      ),
      UserProfile(
        id: '4',
        name: 'Personne Âgée',
        profileType: 'Personnes Âgées',
        icon: Icons.elderly,
        color: Color(0xFFFF8A65),
      ),
      UserProfile(
        id: '5',
        name: 'Femme Enceinte',
        profileType: 'Femmes Enceintes',
        icon: Icons.pregnant_woman,
        color: Color(0xFF4DB6AC),
      ),
      UserProfile(
        id: '6',
        name: 'Sportif',
        profileType: 'Sportifs',
        icon: Icons.directions_run,
        color: Color(0xFFE57373),
      ),
      UserProfile(
        id: '7',
        name: 'Immunodéprimé',
        profileType: 'Immunodéprimés',
        icon: Icons.health_and_safety,
        color: Color(0xFFFFD54F),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            "Sélectionnez votre profil :",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
        ),
        SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: profiles.length,
          itemBuilder: (context, index) {
            return _buildModernProfileCard(profiles[index]);
          },
        ),
        SizedBox(height: 24),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "Sélectionnez votre profil pour obtenir des recommandations personnalisées basées sur les données environnementales",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildModernProfileCard(UserProfile profile) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Provider.of<UserProfileNotifier>(
            context,
            listen: false,
          ).setProfile(profile);
        },
        child: Container(
          padding: EdgeInsets.all(12),
          constraints: BoxConstraints(minHeight: 100),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: profile.color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(profile.icon, size: 24, color: profile.color),
              ),
              SizedBox(height: 8),
              Text(
                profile.profileType,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserProfile profile) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: profile.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(profile.icon, size: 28, color: profile.color),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Profil actuel",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 2),
                Text(
                  profile.profileType,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: primaryGreen, size: 24),
            onPressed: () {
              Provider.of<UserProfileNotifier>(
                context,
                listen: false,
              ).setProfile(null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHealthDashboard(UserProfile profile) {
    final healthStatus = _calculateHealthStatus(profile);
    final statusColor = healthStatus['color'] as Color;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Votre état de santé environnemental",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(healthStatus['icon'], size: 40, color: statusColor),
          ),
          SizedBox(height: 16),
          Text(
            healthStatus['status'],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              healthStatus['message'],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateHealthStatus(UserProfile profile) {
    final risks = _detectHealthRisks(profile);

    if (risks.isEmpty) {
      return {
        'status': 'ENVIRONNEMENT SAIN',
        'message': 'Les conditions actuelles sont optimales pour votre profil',
        'icon': Icons.check_circle,
        'color': safeColor,
      };
    } else {
      return {
        'status': 'ATTENTION REQUISE',
        'message': 'Votre environnement présente des risques pour votre santé',
        'icon': Icons.warning,
        'color':
            risks.any((r) => r['severity'] == 'high')
                ? dangerColor
                : warningColor,
      };
    }
  }

  List<Map<String, dynamic>> _detectHealthRisks(UserProfile profile) {
    final List<Map<String, dynamic>> risks = [];

    if (_temperature > 30) {
      risks.add(_getHeatRisk(profile));
    } else if (_temperature < 18) {
      risks.add(_getColdRisk(profile));
    }

    if (_humidity > 70) {
      risks.add(_getHighHumidityRisk(profile));
    } else if (_humidity < 30) {
      risks.add(_getLowHumidityRisk(profile));
    }

    switch (profile.name) {
      case 'Nourrisson':
        if (_temperature > 22) {
          risks.add({
            'type': 'RISQUE POUR NOURRISSON',
            'message':
                'Température trop élevée (idéal: 18-20°C). Peut causer inconfort et déshydratation.',
            'solution':
                'Maintenez la chambre entre 18-20°C, habillez légèrement le bébé, hydratez régulièrement',
            'icon': Icons.child_friendly,
            'severity': 'high',
          });
        }
        if (_humidity < 40 || _humidity > 60) {
          risks.add({
            'type': 'HUMIDITÉ INADAPTÉE',
            'message':
                'L\'humidité idéale pour un nourrisson est entre 40-60% pour éviter problèmes respiratoires',
            'solution':
                'Utilisez un humidificateur ou déshumidificateur selon besoin, aérez régulièrement',
            'icon': Icons.opacity,
            'severity': 'medium',
          });
        }
        break;

      case 'Enfant':
        if (_temperature > 26) {
          risks.add({
            'type': 'RISQUE POUR ENFANT',
            'message':
                'Température élevée peut causer déshydratation et fatigue rapide',
            'solution':
                'Faites boire régulièrement, évitez les activités intenses aux heures chaudes',
            'icon': Icons.child_care,
            'severity': 'medium',
          });
        }
        break;

      case 'Asthmatique':
        if (_humidity > 70) {
          risks.add({
            'type': 'RISQUE D\'ASTHME',
            'message':
                'Humidité élevée (>70%) favorise acariens et moisissures, déclencheurs courants de crises',
            'solution':
                'Utilisez un déshumidificateur, lavez draps à 60°C, évitez tapis et moquettes',
            'icon': Icons.air,
            'severity': 'high',
          });
        }
        if (_temperature < 16 || _temperature > 24) {
          risks.add({
            'type': 'TEMPERATURE INADAPTEE',
            'message':
                'Les asthmatiques sont sensibles aux variations brutales de température',
            'solution':
                'Maintenez une température stable entre 18-22°C, évitez les chocs thermiques',
            'icon': Icons.thermostat,
            'severity': 'medium',
          });
        }
        break;

      case 'Personne Âgée':
        if (_temperature > 26) {
          risks.add({
            'type': 'RISQUE DE COUP DE CHALEUR',
            'message':
                'Les seniors sont vulnérables aux fortes chaleurs (risque de déshydratation sévère)',
            'solution':
                'Restez au frais, hydratez-vous même sans soif, évitez sorties entre 11h-16h',
            'icon': Icons.elderly,
            'severity': 'high',
          });
        }
        if (_temperature < 20) {
          risks.add({
            'type': 'RISQUE D\'HYPOTHERMIE',
            'message':
                'Les personnes âgées régulent mal leur température corporelle par temps froid',
            'solution':
                'Maintenez un chauffage à 21-23°C, portez plusieurs couches de vêtements',
            'icon': Icons.ac_unit,
            'severity': 'high',
          });
        }
        break;

      case 'Femme Enceinte':
        if (_temperature > 28) {
          risks.add({
            'type': 'RISQUE POUR GROSSESSE',
            'message':
                'Température élevée peut causer malaise, déshydratation et fatigue accrue',
            'solution':
                'Reposez-vous dans un endroit frais, buvez 2L d\'eau/jour, évitez efforts inutiles',
            'icon': Icons.pregnant_woman,
            'severity': 'medium',
          });
        }
        if (_humidity > 70) {
          risks.add({
            'type': 'RISQUE DE MYCOSE',
            'message':
                'Humidité élevée favorise les infections fongiques (plus fréquentes pendant la grossesse)',
            'solution':
                'Portez des vêtements amples en coton, séchez bien la peau après la douche',
            'icon': Icons.opacity,
            'severity': 'medium',
          });
        }
        break;

      case 'Sportif':
        if (_temperature > 25) {
          risks.add({
            'type': 'RISQUE À L\'EFFORT',
            'message':
                'Exercice intense par chaleur peut causer coup de chaleur et déshydratation sévère',
            'solution':
                'Hydratez-vous (500ml/h), évitez 11h-15h, portez tenue légère et claire',
            'icon': Icons.directions_run,
            'severity': 'high',
          });
        }
        break;

      case 'Immunodéprimé':
        if (_humidity > 75) {
          risks.add({
            'type': 'RISQUE INFECTIEUX',
            'message':
                'Humidité élevée favorise bactéries et moisissures pathogènes (risque accru d\'infection)',
            'solution':
                'Utilisez un purificateur d\'air HEPA, nettoyez surfaces humides, évitez plantes d\'intérieur',
            'icon': Icons.health_and_safety,
            'severity': 'high',
          });
        }
        if (_temperature < 20 || _temperature > 24) {
          risks.add({
            'type': 'TEMPERATURE A RISQUE',
            'message':
                'Système immunitaire affaibli par les températures extrêmes',
            'solution':
                'Maintenez une température stable entre 20-24°C, évitez les variations brutales',
            'icon': Icons.thermostat,
            'severity': 'medium',
          });
        }
        break;
    }

    return risks;
  }

  Map<String, dynamic> _getHeatRisk(UserProfile profile) {
    return {
      'type': 'TEMPÉRATURE ÉLEVÉE',
      'message': 'Température actuelle: ${_temperature.toStringAsFixed(1)}°C',
      'solution':
          'Buvez de l\'eau régulièrement, évitez le soleil direct, utilisez des ventilateurs',
      'icon': Icons.whatshot,
      'severity': _temperature > 35 ? 'high' : 'medium',
    };
  }

  Map<String, dynamic> _getColdRisk(UserProfile profile) {
    return {
      'type': 'TEMPÉRATURE BASSE',
      'message': 'Température actuelle: ${_temperature.toStringAsFixed(1)}°C',
      'solution':
          'Portez des vêtements chauds, chauffez la pièce, vérifiez l\'isolation',
      'icon': Icons.ac_unit,
      'severity': _temperature < 10 ? 'high' : 'medium',
    };
  }

  Map<String, dynamic> _getHighHumidityRisk(UserProfile profile) {
    return {
      'type': 'HUMIDITÉ ÉLEVÉE',
      'message': 'Humidité actuelle: ${_humidity.toStringAsFixed(1)}%',
      'solution':
          'Aérez la pièce, utilisez un déshumidificateur, vérifiez les fuites d\'eau',
      'icon': Icons.opacity,
      'severity': _humidity > 80 ? 'high' : 'medium',
    };
  }

  Map<String, dynamic> _getLowHumidityRisk(UserProfile profile) {
    return {
      'type': 'HUMIDITÉ BASSE',
      'message': 'Humidité actuelle: ${_humidity.toStringAsFixed(1)}%',
      'solution':
          'Utilisez un humidificateur, placez des plantes vertes, évitez chauffage excessif',
      'icon': Icons.opacity,
      'severity': _humidity < 20 ? 'high' : 'medium',
    };
  }

  Widget _buildHealthAlerts(UserProfile profile) {
    final risks = _detectHealthRisks(profile);

    if (risks.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: safeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: safeColor.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: safeColor, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Aucun risque détecté pour votre profil actuel",
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            "Recommandations de santé :",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
        ),
        ...risks.map((risk) => _buildModernRiskCard(risk)).toList(),
      ],
    );
  }

  Widget _buildModernRiskCard(Map<String, dynamic> risk) {
    final severity = risk['severity'] ?? 'medium';
    final color = severity == 'high' ? dangerColor : warningColor;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(risk['icon'] ?? Icons.warning, color: color, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    risk['type'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  risk['message'],
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: primaryGreen,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          risk['solution'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: darkGreen,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
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
