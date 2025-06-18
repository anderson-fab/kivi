import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:location/location.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final Location _locationService = Location();
  LatLng _currentPosition = LatLng(0, 0);
  List<Marker> _markers = [];
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Alertes communautaires
  List<Map<String, dynamic>> _communityAlerts = [];
  StreamSubscription? _alertsSubscription;
  double _filterRadius = 5.0;
  bool _showOnlyNearby = true;

  // Catégories
  final Map<String, Map<String, dynamic>> _alertCategories = {
    'fire': {
      'name': 'Incendie',
      'icon': '🔥',
      'color': Colors.red,
      'priority': 3,
    },
    'explosion': {
      'name': 'Explosion',
      'icon': '💥',
      'color': Colors.deepOrange,
      'priority': 3,
    },
    'gas': {
      'name': 'Fuite de gaz',
      'icon': '☢️',
      'color': Colors.orange,
      'priority': 2,
    },
    'chemical': {
      'name': 'Produit chimique',
      'icon': '🧪',
      'color': Colors.purple,
      'priority': 2,
    },
    'flood': {
      'name': 'Inondation',
      'icon': '🌊',
      'color': Colors.blue,
      'priority': 2,
    },
    'tree': {
      'name': 'Arbre dangereux',
      'icon': '🌳',
      'color': Colors.green,
      'priority': 1,
    },
    'animal': {
      'name': 'Animal dangereux',
      'icon': '🐍',
      'color': Colors.lime,
      'priority': 1,
    },
    'distress': {
      'name': 'Personne en détresse',
      'icon': '🚑',
      'color': Colors.pink,
      'priority': 2,
    },
  };
  Set<String> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    _selectedCategories = Set.from(_alertCategories.keys);
    _initLocation();
    _loadAlerts();
  }

  @override
  void dispose() {
    _alertsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) throw 'Service désactivé';
      }

      PermissionStatus permission = await _locationService.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _locationService.requestPermission();
        if (permission != PermissionStatus.granted) throw 'Permission refusée';
      }

      LocationData locationData = await _locationService.getLocation();
      setState(() {
        _currentPosition = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );
        _mapController.move(_currentPosition, 15);
      });
    } catch (e) {
      _showToast("Erreur GPS: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadAlerts() {
    _alertsSubscription = _dbRef
        .child('community_alerts')
        .orderByChild('timestamp')
        .limitToLast(100)
        .onValue
        .listen((event) {
          if (event.snapshot.value != null) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            setState(() {
              _communityAlerts =
                  data.entries
                      .map((e) {
                        return {
                          'id': e.key,
                          'userId': e.value['userId'],
                          'category': e.value['category'] ?? 'other',
                          'message': e.value['message'] ?? '',
                          'lat': e.value['lat']?.toDouble() ?? 0,
                          'lon': e.value['lon']?.toDouble() ?? 0,
                          'timestamp': e.value['timestamp'],
                          'confirmations': e.value['confirmations'] ?? 0,
                          'priority': e.value['priority'] ?? 1,
                        };
                      })
                      .where(
                        (alert) =>
                            _selectedCategories.contains(alert['category']),
                      )
                      .toList();
              _updateMarkers();
            });
          }
        });
  }

  Future<void> _deleteAlert(String alertId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final alertRef = _dbRef.child('community_alerts/$alertId');
      final snapshot = await alertRef.child('userId').get();

      if (snapshot.exists && snapshot.value == user.uid) {
        await alertRef.remove();
        _showToast("Alerte supprimée");
      } else {
        _showToast("Action non autorisée");
      }
    } catch (e) {
      _showToast("Erreur: ${e.toString()}");
    }
  }

  void _updateMarkers() {
    final markers = <Marker>[];

    _communityAlerts
        .where((alert) {
          if (!_showOnlyNearby) return true;
          final distance = Distance().as(
            LengthUnit.Kilometer,
            _currentPosition,
            LatLng(alert['lat'], alert['lon']),
          );
          return distance <= _filterRadius;
        })
        .forEach((alert) {
          final category = _alertCategories[alert['category']];
          final isConfirmed = (alert['confirmations'] ?? 0) >= 2;
          final isUrgent = alert['priority'] == 3;

          markers.add(
            Marker(
              width: 60,
              height: 60,
              point: LatLng(alert['lat'], alert['lon']),
              builder:
                  (ctx) => GestureDetector(
                    onTap: () => _showAlertDetails(alert),
                    onLongPress: () => _showActionMenu(alert),
                    child: Stack(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isUrgent ? Colors.red : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            category?['icon'] ?? '⚠️',
                            style: TextStyle(fontSize: 30),
                          ),
                        ),
                        if (isConfirmed)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${alert['confirmations']}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
            ),
          );
        });

    markers.add(
      Marker(
        width: 40,
        height: 40,
        point: _currentPosition,
        builder:
            (ctx) =>
                Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
      ),
    );

    setState(() => _markers = markers);
  }

  void _showAlertDetails(Map<String, dynamic> alert) {
    final category = _alertCategories[alert['category']];
    final isAuthor = alert['userId'] == _auth.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category?['name'] ?? 'Alerte',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: category?['color'],
                  ),
                ),
                SizedBox(height: 10),
                Text(alert['message']),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Chip(
                      label: Text(
                        'À ${_calculateDistance(alert).toStringAsFixed(1)} km',
                      ),
                    ),
                    Chip(
                      label: Text('${alert['confirmations']} confirmations'),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (isAuthor)
                  ElevatedButton.icon(
                    icon: Icon(Icons.delete),
                    label: Text('Supprimer cette alerte'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteAlert(alert['id']);
                    },
                  ),
              ],
            ),
          ),
    );
  }

  void _showActionMenu(Map<String, dynamic> alert) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.check, color: Colors.green),
                  title: Text('Confirmer cette alerte'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmAlert(alert['id']);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.close, color: Colors.red),
                  title: Text('Signaler comme faux'),
                  onTap: () {
                    Navigator.pop(context);
                    _reportFalseAlert(alert['id']);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Partager la position'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareLocation(alert);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _confirmAlert(String alertId) async {
    try {
      await _dbRef
          .child('community_alerts/$alertId/confirmations')
          .set(ServerValue.increment(1));
      _showToast("Alerte confirmée !");
    } catch (e) {
      _showToast("Erreur: ${e.toString()}");
    }
  }

  Future<void> _reportFalseAlert(String alertId) async {
    try {
      await _dbRef
          .child('community_alerts/$alertId/false_reports')
          .set(ServerValue.increment(1));
      _showToast("Signalement enregistré");
    } catch (e) {
      _showToast("Erreur: ${e.toString()}");
    }
  }

  void _shareLocation(Map<String, dynamic> alert) {
    final url = "https://maps.google.com/?q=${alert['lat']},${alert['lon']}";
    _showToast("Position copiée: $url");
  }

  double _calculateDistance(Map<String, dynamic> alert) {
    return Distance().as(
      LengthUnit.Kilometer,
      _currentPosition,
      LatLng(alert['lat'], alert['lon']),
    );
  }

  void _showNewAlertDialog() {
    String selectedCategory = 'fire';
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text('Nouvelle alerte'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<String>(
                        value: selectedCategory,
                        items:
                            _alertCategories.entries.map((e) {
                              return DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                  '${e.value['icon']} ${e.value['name']}',
                                ),
                              );
                            }).toList(),
                        onChanged:
                            (value) =>
                                setState(() => selectedCategory = value!),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Décrivez le danger...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () {
                        if (controller.text.isNotEmpty) {
                          _sendAlert(selectedCategory, controller.text);
                          Navigator.pop(context);
                        }
                      },
                      child: Text('Envoyer'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _sendAlert(String category, String message) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _dbRef.child('community_alerts').push().set({
        'userId': user.uid,
        'category': category,
        'message': message,
        'lat': _currentPosition.latitude,
        'lon': _currentPosition.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'priority': _alertCategories[category]?['priority'] ?? 1,
        'confirmations': 1,
        'false_reports': 0,
      });
      _showToast("Alerte envoyée !");
    } catch (e) {
      _showToast("Erreur: ${e.toString()}");
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text('Filtrer les alertes'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SwitchListTile(
                          title: Text('Afficher seulement à proximité'),
                          value: _showOnlyNearby,
                          onChanged: (value) {
                            setState(() => _showOnlyNearby = value);
                            _updateMarkers();
                          },
                        ),
                        if (_showOnlyNearby)
                          Slider(
                            value: _filterRadius,
                            min: 1,
                            max: 20,
                            divisions: 19,
                            label: '${_filterRadius.toInt()} km',
                            onChanged: (value) {
                              setState(() => _filterRadius = value);
                              _updateMarkers();
                            },
                          ),
                        Divider(),
                        Text('Catégories :'),
                        ..._alertCategories.entries.map((e) {
                          return CheckboxListTile(
                            title: Text(
                              '${e.value['icon']} ${e.value['name']}',
                            ),
                            value: _selectedCategories.contains(e.key),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedCategories.add(e.key);
                                } else {
                                  _selectedCategories.remove(e.key);
                                }
                              });
                              _loadAlerts();
                            },
                          );
                        }).toList(),
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
          ),
    );
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black54,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Carte des Alertes'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filtrer',
          ),
          IconButton(
            icon: Icon(Icons.warning_amber),
            onPressed: _showNewAlertDialog,
            tooltip: 'Nouvelle alerte',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _initLocation();
              _loadAlerts();
              _showToast("Actualisé");
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentPosition,
              zoom: 15.0,
              onTap: (_, __) {},
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),
          if (_isLoading) Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
