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
  List<Map<String, dynamic>> _userHouses = [];
  StreamSubscription? _housesSubscription;
  Map<String, dynamic> _sensorData = {};
  StreamSubscription? _sensorSubscription;

  // Mode communautaire
  bool _communityMode = false;
  List<Map<String, dynamic>> _communityAlerts = [];
  StreamSubscription? _communityAlertsSubscription;

  // Seuils pour le DHT11
  final double _tempWarningThreshold = 30.0;
  final double _tempDangerThreshold = 40.0;
  final double _humidityWarningThreshold = 70.0;
  final double _humidityDangerThreshold = 85.0;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadUserData();
    _listenToSensors();
  }

  @override
  void dispose() {
    _housesSubscription?.cancel();
    _sensorSubscription?.cancel();
    _communityAlertsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) throw 'Service de localisation désactivé';
      }

      PermissionStatus permission = await _locationService.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _locationService.requestPermission();
        if (permission != PermissionStatus.granted) {
          throw 'Permission de localisation refusée';
        }
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
      _showToast("Erreur de localisation: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadUserData() {
    final user = _auth.currentUser;
    if (user == null) {
      _showToast("Utilisateur non connecté");
      return;
    }

    _housesSubscription = _dbRef
        .child('users/${user.uid}/houses')
        .onValue
        .listen(
          (event) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data != null) {
              setState(() {
                _userHouses =
                    data.entries.map((e) {
                      return {
                        'id': e.key,
                        'name': e.value['name'] ?? 'Sans nom',
                        'address': e.value['address'] ?? 'Adresse inconnue',
                        'lat':
                            e.value['lat']?.toDouble() ??
                            _currentPosition.latitude,
                        'lon':
                            e.value['lon']?.toDouble() ??
                            _currentPosition.longitude,
                      };
                    }).toList();
                _updateMarkers();
              });
            } else {
              setState(() {
                _userHouses = [];
                _updateMarkers();
              });
            }
          },
          onError: (error) {
            _showToast("Erreur de chargement: $error");
          },
        );
  }

  void _listenToSensors() {
    _sensorSubscription = _dbRef.child('DHT').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _sensorData = {
            'temperature': (data['temperature'] ?? 0.0).toDouble(),
            'humidity': (data['humidity'] ?? 0.0).toDouble(),
          };
          _updateMarkers();
        });
      }
    });
  }

  void _toggleCommunityMode() {
    setState(() {
      _communityMode = !_communityMode;
      if (_communityMode) {
        _loadCommunityAlerts();
      } else {
        _communityAlertsSubscription?.cancel();
        _communityAlerts.clear();
        _updateMarkers();
      }
    });
  }

  void _loadCommunityAlerts() {
    _communityAlertsSubscription = _dbRef
        .child('community_alerts')
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue
        .listen((event) {
          if (event.snapshot.value != null) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            setState(() {
              _communityAlerts =
                  data.entries.map((e) {
                    return {
                      'id': e.key,
                      'message': e.value['message'],
                      'lat': e.value['lat'],
                      'lon': e.value['lon'],
                      'timestamp': e.value['timestamp'],
                    };
                  }).toList();
              _updateMarkers();
            });
          }
        });
  }

  void _addCommunityAlert() {
    final alertController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Signaler un danger'),
            content: TextField(
              controller: alertController,
              decoration: InputDecoration(
                hintText: 'Décrivez le danger (ex: Fuite de gaz, incendie...)',
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler'),
              ),
              TextButton(
                onPressed: () {
                  if (alertController.text.isNotEmpty) {
                    _sendCommunityAlert(alertController.text);
                    Navigator.pop(context);
                  } else {
                    _showToast("Veuillez décrire le danger");
                  }
                },
                child: Text('Envoyer'),
              ),
            ],
          ),
    );
  }

  Future<void> _sendCommunityAlert(String message) async {
    try {
      await _dbRef.child('community_alerts').push().set({
        'userId': _auth.currentUser?.uid,
        'message': message,
        'lat': _currentPosition.latitude,
        'lon': _currentPosition.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _showToast("Alerte communautaire envoyée");
    } catch (e) {
      _showToast("Erreur: ${e.toString()}");
    }
  }

  void _showAlertDetails(Map<String, dynamic> alert) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Alerte Communautaire',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(alert['message'], style: TextStyle(fontSize: 16)),
                SizedBox(height: 16),
                Text(
                  'Signalé le ${DateFormat('dd/MM à HH:mm').format(DateTime.parse(alert['timestamp']))}',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
    );
  }

  Color _getHouseColor() {
    final temp = _sensorData['temperature'] ?? 0.0;
    final humidity = _sensorData['humidity'] ?? 0.0;

    if (temp >= _tempDangerThreshold || humidity >= _humidityDangerThreshold) {
      return Colors.red;
    } else if (temp >= _tempWarningThreshold ||
        humidity >= _humidityWarningThreshold) {
      return Colors.orange;
    }
    return Colors.green;
  }

  Widget? _getAlertIcon() {
    final temp = _sensorData['temperature'] ?? 0.0;
    final humidity = _sensorData['humidity'] ?? 0.0;

    if (temp >= _tempDangerThreshold || humidity >= _humidityDangerThreshold) {
      return Positioned(
        right: 0,
        top: 0,
        child: Icon(Icons.warning, color: Colors.red, size: 20),
      );
    }
    return null;
  }

  void _updateMarkers() {
    final markers = <Marker>[];

    // 1. Maisons utilisateur
    markers.addAll(
      _userHouses.map((house) {
        return Marker(
          width: 80,
          height: 80,
          point: LatLng(house['lat'], house['lon']),
          builder:
              (ctx) => GestureDetector(
                onTap: () => _showHouseDetails(house),
                child: Stack(
                  children: [
                    Icon(Icons.home, color: _getHouseColor(), size: 40),
                    if (_getAlertIcon() != null) _getAlertIcon()!,
                  ],
                ),
              ),
        );
      }),
    );

    // 2. Alertes communautaires
    if (_communityMode) {
      markers.addAll(
        _communityAlerts.map((alert) {
          return Marker(
            width: 60,
            height: 60,
            point: LatLng(alert['lat'], alert['lon']),
            builder:
                (ctx) => GestureDetector(
                  onTap: () => _showAlertDetails(alert),
                  child: Icon(Icons.warning, color: Colors.orange, size: 40),
                ),
          );
        }),
      );
    }

    // 3. Position actuelle (unique)
    markers.add(
      Marker(
        width: 40,
        height: 40,
        point: _currentPosition,
        builder:
            (ctx) => Icon(Icons.person_pin_circle, color: Colors.red, size: 40),
      ),
    );

    setState(() {
      _markers = markers;
    });
  }

  void _showHouseDetails(Map<String, dynamic> house) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                house['name'],
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(house['address']),
              SizedBox(height: 16),
              if (_sensorData.isNotEmpty) ...[
                _buildSensorInfo(),
                SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.edit),
                    label: Text('Modifier'),
                    onPressed: () => _editHouse(house),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.delete),
                    label: Text('Supprimer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => _deleteHouse(house['id']),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSensorInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              'DONNÉES DES CAPTEURS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('Température', style: TextStyle(fontSize: 12)),
                    Text(
                      '${_sensorData['temperature']?.toStringAsFixed(1) ?? '--'}°C',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('Humidité', style: TextStyle(fontSize: 12)),
                    Text(
                      '${_sensorData['humidity']?.toStringAsFixed(1) ?? '--'}%',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addNewHouse() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Ajouter une maison'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Nom'),
                ),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(labelText: 'Adresse'),
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
                  if (nameController.text.isNotEmpty) {
                    _saveNewHouse(nameController.text, addressController.text);
                    Navigator.pop(context);
                  } else {
                    _showToast("Le nom est obligatoire");
                  }
                },
                child: Text('Enregistrer'),
              ),
            ],
          ),
    );
  }

  Future<void> _saveNewHouse(String name, String address) async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _dbRef.child('users/${user.uid}/houses').push().set({
        'name': name,
        'address': address,
        'lat': _currentPosition.latitude,
        'lon': _currentPosition.longitude,
        'createdAt': DateTime.now().toIso8601String(),
      });
      _showToast("Maison ajoutée avec succès");
    } catch (e) {
      _showToast("Erreur: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editHouse(Map<String, dynamic> house) async {
    final nameController = TextEditingController(text: house['name']);
    final addressController = TextEditingController(text: house['address']);

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Modifier la maison'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Nom'),
                ),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(labelText: 'Adresse'),
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
                  if (nameController.text.isNotEmpty) {
                    _updateHouse(
                      house['id'],
                      nameController.text,
                      addressController.text,
                    );
                    Navigator.pop(context);
                  } else {
                    _showToast("Le nom est obligatoire");
                  }
                },
                child: Text('Enregistrer'),
              ),
            ],
          ),
    );
  }

  Future<void> _updateHouse(String houseId, String name, String address) async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _dbRef.child('users/${user.uid}/houses/$houseId').update({
        'name': name,
        'address': address,
      });
      _showToast("Maison modifiée avec succès");
    } catch (e) {
      _showToast("Erreur: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteHouse(String houseId) async {
    final confirmed = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirmer la suppression'),
            content: Text('Voulez-vous vraiment supprimer cette maison ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Non'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Oui', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final user = _auth.currentUser;
        if (user == null) return;

        await _dbRef.child('users/${user.uid}/houses/$houseId').remove();
        _showToast("Maison supprimée avec succès");
      } catch (e) {
        _showToast("Erreur: ${e.toString()}");
      } finally {
        setState(() => _isLoading = false);
      }
    }
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
        title: Text('MAP'),
        actions: [
          IconButton(
            icon: Icon(_communityMode ? Icons.group : Icons.group_off),
            onPressed: _toggleCommunityMode,
            tooltip: 'Mode Communautaire',
          ),
          IconButton(
            icon: Icon(Icons.warning),
            onPressed: _addCommunityAlert,
            tooltip: 'Signaler un danger',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _loadUserData();
              _listenToSensors();
              if (_communityMode) _loadCommunityAlerts();
              _showToast("Actualisation...");
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(center: _currentPosition, zoom: 15.0),
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
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: _addNewHouse,
      ),
    );
  }
}
