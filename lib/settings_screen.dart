import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'main.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  final Color _greenColor = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    });
  }

  void _saveNotificationsEnabled(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final thresholdProvider = Provider.of<ThresholdProvider>(context);
    final temperatureUnitProvider = Provider.of<TemperatureUnitProvider>(
      context,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("Paramètres"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SwitchListTile(
              title: Text('Activer les notifications'),
              value: _notificationsEnabled,
              activeColor: _greenColor,
              onChanged: (bool value) {
                setState(() {
                  _notificationsEnabled = value;
                });
                _saveNotificationsEnabled(value);
              },
            ),
            Divider(),
            ListTile(
              title: Text('Seuil de température'),
              subtitle: Text(
                'Min: ${thresholdProvider.minTemperatureThreshold}°C, Max: ${thresholdProvider.maxTemperatureThreshold}°C',
              ),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showTemperatureThresholdDialog(context, thresholdProvider);
              },
            ),
            Divider(),
            ListTile(
              title: Text('Seuil d\'humidité'),
              subtitle: Text(
                'Min: ${thresholdProvider.minHumidityThreshold}%, Max: ${thresholdProvider.maxHumidityThreshold}%',
              ),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showHumidityThresholdDialog(context, thresholdProvider);
              },
            ),
            Divider(),
            ListTile(
              title: Text('Seuil de gaz inflammable'),
              subtitle: Text(
                'Min: ${thresholdProvider.minFlammableGasThreshold} ppm, Max: ${thresholdProvider.maxFlammableGasThreshold} ppm',
              ),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showFlammableGasThresholdDialog(context, thresholdProvider);
              },
            ),
            Divider(),
            ListTile(
              title: Text('Seuil de gaz polluants'),
              subtitle: Text(
                'Min: ${thresholdProvider.minPollutantGasThreshold} ppm, Max: ${thresholdProvider.maxPollutantGasThreshold} ppm',
              ),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showPollutantGasThresholdDialog(context, thresholdProvider);
              },
            ),
            Divider(),
            SwitchListTile(
              title: Text('Mode sombre'),
              value: themeProvider.isDarkMode,
              activeColor: _greenColor,
              onChanged: (bool value) {
                themeProvider.toggleTheme();
              },
            ),
            Divider(),
            ListTile(
              title: Text('Unité de température'),
              subtitle: Text(temperatureUnitProvider.unit),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showTemperatureUnitDialog(temperatureUnitProvider);
              },
            ),
            Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _greenColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Paramètres sauvegardés')),
                  );
                },
                child: Text('Sauvegarder'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTemperatureThresholdDialog(
    BuildContext context,
    ThresholdProvider thresholdProvider,
  ) {
    TextEditingController minController = TextEditingController(
      text: thresholdProvider.minTemperatureThreshold.toString(),
    );
    TextEditingController maxController = TextEditingController(
      text: thresholdProvider.maxTemperatureThreshold.toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Définir les seuils de température'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Seuil minimal (°C)'),
              ),
              TextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Seuil maximal (°C)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                double? minValue = double.tryParse(minController.text);
                double? maxValue = double.tryParse(maxController.text);
                if (minValue != null && maxValue != null) {
                  thresholdProvider.setMinTemperatureThreshold(minValue);
                  thresholdProvider.setMaxTemperatureThreshold(maxValue);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Veuillez entrer des valeurs valides'),
                    ),
                  );
                }
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showHumidityThresholdDialog(
    BuildContext context,
    ThresholdProvider thresholdProvider,
  ) {
    TextEditingController minController = TextEditingController(
      text: thresholdProvider.minHumidityThreshold.toString(),
    );
    TextEditingController maxController = TextEditingController(
      text: thresholdProvider.maxHumidityThreshold.toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Définir les seuils d\'humidité'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Seuil minimal (%)'),
              ),
              TextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Seuil maximal (%)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                double? minValue = double.tryParse(minController.text);
                double? maxValue = double.tryParse(maxController.text);
                if (minValue != null && maxValue != null) {
                  thresholdProvider.setMinHumidityThreshold(minValue);
                  thresholdProvider.setMaxHumidityThreshold(maxValue);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Veuillez entrer des valeurs valides'),
                    ),
                  );
                }
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showFlammableGasThresholdDialog(
    BuildContext context,
    ThresholdProvider thresholdProvider,
  ) {
    TextEditingController minController = TextEditingController(
      text: thresholdProvider.minFlammableGasThreshold.toString(),
    );
    TextEditingController maxController = TextEditingController(
      text: thresholdProvider.maxFlammableGasThreshold.toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Définir les seuils de gaz inflammable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Seuil minimal (ppm)'),
              ),
              TextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Seuil maximal (ppm)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                double? minValue = double.tryParse(minController.text);
                double? maxValue = double.tryParse(maxController.text);
                if (minValue != null && maxValue != null) {
                  thresholdProvider.setMinFlammableGasThreshold(minValue);
                  thresholdProvider.setMaxFlammableGasThreshold(maxValue);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Veuillez entrer des valeurs valides'),
                    ),
                  );
                }
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showPollutantGasThresholdDialog(
    BuildContext context,
    ThresholdProvider thresholdProvider,
  ) {
    TextEditingController minController = TextEditingController(
      text: thresholdProvider.minPollutantGasThreshold.toString(),
    );
    TextEditingController maxController = TextEditingController(
      text: thresholdProvider.maxPollutantGasThreshold.toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Définir les seuils de gaz polluants'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Seuil minimal (ppm)'),
              ),
              TextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Seuil maximal (ppm)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                double? minValue = double.tryParse(minController.text);
                double? maxValue = double.tryParse(maxController.text);
                if (minValue != null && maxValue != null) {
                  thresholdProvider.setMinPollutantGasThreshold(minValue);
                  thresholdProvider.setMaxPollutantGasThreshold(maxValue);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Veuillez entrer des valeurs valides'),
                    ),
                  );
                }
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showTemperatureUnitDialog(TemperatureUnitProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Choisir l\'unité de température'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Celsius'),
                onTap: () {
                  provider.setUnit('Celsius');
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('Fahrenheit'),
                onTap: () {
                  provider.setUnit('Fahrenheit');
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
