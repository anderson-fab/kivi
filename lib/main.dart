import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:kivi1/firebase_options.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'visualisation.dart';
import 'conversation.dart' as conv;
import 'welcome_page.dart';
import 'social_page.dart';
import 'login_page.dart';
import 'prediction.dart';
import 'home_page.dart';
import 'agriculture_page.dart';
import 'sante_page.dart';
import 'dangers_page.dart';
import 'map_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'threshold_channel_id',
    'Seuils dépassés',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TemperatureUnitProvider()),
        ChangeNotifierProvider(
          create: (_) => ThresholdProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(create: (_) => UserProfileNotifier()),
      ],
      child: SensorApp(),
    ),
  );
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;

  if (notification != null && android != null) {
    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'threshold_channel_id',
          'Seuils dépassés',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

class TemperatureUnitProvider with ChangeNotifier {
  String _unit = 'Celsius';

  String get unit => _unit;

  void setUnit(String unit) {
    _unit = unit;
    notifyListeners();
  }
}

class ThresholdProvider with ChangeNotifier {
  double _minTemperatureThreshold = 10.0;
  double _maxTemperatureThreshold = 30.0;
  double _minHumidityThreshold = 20.0;
  double _maxHumidityThreshold = 60.0;
  double _minFlammableGasThreshold = 100.0;
  double _maxFlammableGasThreshold = 500.0;
  double _minPollutantGasThreshold = 50.0;
  double _maxPollutantGasThreshold = 200.0;

  double get minTemperatureThreshold => _minTemperatureThreshold;
  double get maxTemperatureThreshold => _maxTemperatureThreshold;
  double get minHumidityThreshold => _minHumidityThreshold;
  double get maxHumidityThreshold => _maxHumidityThreshold;
  double get minFlammableGasThreshold => _minFlammableGasThreshold;
  double get maxFlammableGasThreshold => _maxFlammableGasThreshold;
  double get minPollutantGasThreshold => _minPollutantGasThreshold;
  double get maxPollutantGasThreshold => _maxPollutantGasThreshold;

  void setMinTemperatureThreshold(double value) {
    _minTemperatureThreshold = value;
    _saveSettings();
    notifyListeners();
  }

  void setMaxTemperatureThreshold(double value) {
    _maxTemperatureThreshold = value;
    _saveSettings();
    notifyListeners();
  }

  void setMinHumidityThreshold(double value) {
    _minHumidityThreshold = value;
    _saveSettings();
    notifyListeners();
  }

  void setMaxHumidityThreshold(double value) {
    _maxHumidityThreshold = value;
    _saveSettings();
    notifyListeners();
  }

  void setMinFlammableGasThreshold(double value) {
    _minFlammableGasThreshold = value;
    _saveSettings();
    notifyListeners();
  }

  void setMaxFlammableGasThreshold(double value) {
    _maxFlammableGasThreshold = value;
    _saveSettings();
    notifyListeners();
  }

  void setMinPollutantGasThreshold(double value) {
    _minPollutantGasThreshold = value;
    _saveSettings();
    notifyListeners();
  }

  void setMaxPollutantGasThreshold(double value) {
    _maxPollutantGasThreshold = value;
    _saveSettings();
    notifyListeners();
  }

  void _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('minTemperatureThreshold', _minTemperatureThreshold);
    await prefs.setDouble('maxTemperatureThreshold', _maxTemperatureThreshold);
    await prefs.setDouble('minHumidityThreshold', _minHumidityThreshold);
    await prefs.setDouble('maxHumidityThreshold', _maxHumidityThreshold);
    await prefs.setDouble(
      'minFlammableGasThreshold',
      _minFlammableGasThreshold,
    );
    await prefs.setDouble(
      'maxFlammableGasThreshold',
      _maxFlammableGasThreshold,
    );
    await prefs.setDouble(
      'minPollutantGasThreshold',
      _minPollutantGasThreshold,
    );
    await prefs.setDouble(
      'maxPollutantGasThreshold',
      _maxPollutantGasThreshold,
    );
  }

  void loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _minTemperatureThreshold =
        prefs.getDouble('minTemperatureThreshold') ?? 10.0;
    _maxTemperatureThreshold =
        prefs.getDouble('maxTemperatureThreshold') ?? 30.0;
    _minHumidityThreshold = prefs.getDouble('minHumidityThreshold') ?? 20.0;
    _maxHumidityThreshold = prefs.getDouble('maxHumidityThreshold') ?? 60.0;
    _minFlammableGasThreshold =
        prefs.getDouble('minFlammableGasThreshold') ?? 100.0;
    _maxFlammableGasThreshold =
        prefs.getDouble('maxFlammableGasThreshold') ?? 500.0;
    _minPollutantGasThreshold =
        prefs.getDouble('minPollutantGasThreshold') ?? 50.0;
    _maxPollutantGasThreshold =
        prefs.getDouble('maxPollutantGasThreshold') ?? 200.0;
    notifyListeners();
  }
}

class SensorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kivi - Surveillance Environnementale',
      theme: themeProvider.isDarkMode ? ThemeData.dark() : ThemeData.light(),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => WelcomePage(),
        '/social': (context) => SocialPage(),
        '/login': (context) => LoginPage(),
        '/home': (context) => RealTimeDataScreen(),
        '/dashboard': (context) => HomePage(),
        '/settings': (context) => SettingsScreen(),
        '/visualisation': (context) => VisualisationPage(),
        '/conversation': (context) => conv.ConversationPage(),
        '/prediction': (context) => PredictionPage(),
        '/agriculture': (context) => AgriculturePage(),
        '/sante': (context) => SantePage(),
        '/dangers': (context) => DangersPage(),
        '/map': (context) => MapPage(),
      },
    );
  }
}

class RealTimeDataScreen extends StatefulWidget {
  @override
  _RealTimeDataScreenState createState() => _RealTimeDataScreenState();
}

class _RealTimeDataScreenState extends State<RealTimeDataScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  double _temperature = 0.0;
  double _humidity = 0.0;
  double _gasLevel = 0.0;
  double _pollutantLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _listenToRealtimeDatabase();
  }

  void _listenToRealtimeDatabase() {
    _database.child('DHT/temperature').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final double newTemp = (event.snapshot.value as num).toDouble();
        setState(() {
          _temperature = newTemp;
        });
        _checkTemperatureThresholds(newTemp);
      }
    });

    _database.child('DHT/humidity').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final double newHumidity = (event.snapshot.value as num).toDouble();
        setState(() {
          _humidity = newHumidity;
        });
        _checkHumidityThresholds(newHumidity);
      }
    });

    _database.child('MQ2/gasLevel').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final double newGasLevel = (event.snapshot.value as num).toDouble();
        setState(() {
          _gasLevel = newGasLevel;
        });
        _checkGasThresholds(newGasLevel);
      }
    });

    _database.child('MQ135/gasLevel').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final double newPollutant = (event.snapshot.value as num).toDouble();
        setState(() {
          _pollutantLevel = newPollutant;
        });
        _checkPollutantThresholds(newPollutant);
      }
    });
  }

  void _checkTemperatureThresholds(double temperature) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;

    if (!notificationsEnabled) return;

    final thresholdProvider = Provider.of<ThresholdProvider>(
      context,
      listen: false,
    );

    if (temperature <= thresholdProvider.minTemperatureThreshold) {
      await _showNotification(
        title: 'Alerte : Température minimale atteinte',
        body:
            'La température est descendue en dessous de ${thresholdProvider.minTemperatureThreshold}°C.',
      );
    } else if (temperature >= thresholdProvider.maxTemperatureThreshold) {
      await _showNotification(
        title: 'Alerte : Température maximale atteinte',
        body:
            'La température a dépassé ${thresholdProvider.maxTemperatureThreshold}°C.',
      );
    }
  }

  void _checkHumidityThresholds(double humidity) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;

    if (!notificationsEnabled) return;

    final thresholdProvider = Provider.of<ThresholdProvider>(
      context,
      listen: false,
    );

    if (humidity <= thresholdProvider.minHumidityThreshold) {
      await _showNotification(
        title: 'Alerte : Humidité minimale atteinte',
        body:
            'L\'humidité est descendue en dessous de ${thresholdProvider.minHumidityThreshold}%.',
      );
    } else if (humidity >= thresholdProvider.maxHumidityThreshold) {
      await _showNotification(
        title: 'Alerte : Humidité maximale atteinte',
        body:
            'L\'humidité a dépassé ${thresholdProvider.maxHumidityThreshold}%.',
      );
    }
  }

  void _checkGasThresholds(double gasLevel) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    final thresholdProvider = Provider.of<ThresholdProvider>(
      context,
      listen: false,
    );

    if (!notificationsEnabled) return;

    if (gasLevel <= thresholdProvider.minFlammableGasThreshold) {
      await _showNotification(
        title: 'Alerte : Gaz inflammable faible',
        body:
            'Niveau de gaz inflammable très bas : ${gasLevel.toStringAsFixed(1)} ppm (en dessous de ${thresholdProvider.minFlammableGasThreshold} ppm).',
      );
    } else if (gasLevel >= thresholdProvider.maxFlammableGasThreshold) {
      await _showNotification(
        title: 'DANGER ! Gaz inflammable élevé',
        body:
            'Haute concentration de gaz inflammable : ${gasLevel.toStringAsFixed(1)} ppm (au-dessus de ${thresholdProvider.maxFlammableGasThreshold} ppm). Aérez immédiatement !',
      );
    }
  }

  void _checkPollutantThresholds(double pollutantLevel) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    final thresholdProvider = Provider.of<ThresholdProvider>(
      context,
      listen: false,
    );

    if (!notificationsEnabled) return;

    if (pollutantLevel <= thresholdProvider.minPollutantGasThreshold) {
      await _showNotification(
        title: 'Alerte : Gaz polluants très bas',
        body:
            'Niveau de gaz polluants très bas : ${pollutantLevel.toStringAsFixed(1)} ppm (en dessous de ${thresholdProvider.minPollutantGasThreshold} ppm).',
      );
    } else if (pollutantLevel >= thresholdProvider.maxPollutantGasThreshold) {
      await _showNotification(
        title: 'Alerte : Gaz polluants élevés',
        body:
            'Concentration élevée de gaz polluants : ${pollutantLevel.toStringAsFixed(1)} ppm (au-dessus de ${thresholdProvider.maxPollutantGasThreshold} ppm). Aérez la pièce !',
      );
    }
  }

  Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'threshold_channel_id',
          'Seuils dépassés',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  @override
  Widget build(BuildContext context) {
    final temperatureUnitProvider = Provider.of<TemperatureUnitProvider>(
      context,
    );

    double displayTemperature = _temperature;
    if (temperatureUnitProvider.unit == 'Fahrenheit') {
      displayTemperature = (_temperature * 9 / 5) + 32;
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Kivi',
        actions: [
          IconButton(
            icon: Icon(
              Icons.analytics,
              color: Theme.of(context).iconTheme.color,
              size: 30,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => VisualisationPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.auto_awesome,
              color: Theme.of(context).iconTheme.color,
              size: 30,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PredictionPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.settings,
              color: Theme.of(context).iconTheme.color,
              size: 30,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
        showBackButton: true,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: ListView(
              children: [
                SensorCard(
                  label: 'Température',
                  value:
                      '${displayTemperature.toStringAsFixed(1)}°${temperatureUnitProvider.unit == 'Celsius' ? 'C' : 'F'}',
                  icon: Icons.thermostat,
                  color: const Color.fromARGB(255, 255, 165, 0),
                ),
                const SizedBox(height: 25),
                SensorCard(
                  label: 'Humidité',
                  value: '$_humidity%',
                  icon: Icons.water_drop,
                  color: const Color.fromARGB(255, 0, 0, 255),
                ),
                const SizedBox(height: 25),
                SensorCard(
                  label: 'Gaz inflammable',
                  value: '$_gasLevel ppm',
                  icon: Icons.cloud,
                  color: const Color.fromARGB(255, 255, 0, 0),
                ),
                const SizedBox(height: 25),
                SensorCard(
                  label: 'Gaz polluants',
                  value: '$_pollutantLevel ppm',
                  icon: Icons.air,
                  color: const Color.fromARGB(255, 0, 128, 0),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => conv.ConversationPage()),
          );
        },
        child: const Icon(Icons.chat),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final bool showBackButton;

  const CustomAppBar({
    required this.title,
    required this.actions,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading:
          showBackButton
              ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed:
                    () => Navigator.pushReplacementNamed(context, '/dashboard'),
              )
              : null,
      actions: actions,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 10,
      shadowColor: const Color.fromARGB(255, 0, 0, 139),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);
}

class SensorCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const SensorCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    color: Color.fromARGB(255, 119, 119, 119),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
