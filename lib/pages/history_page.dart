import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/air_quality_service.dart';
import '../models/air_quality_data.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime? _selectedDateTime;
  AirQualityData? _airQualityData;
  bool _isLoading = false;
  String? _error;
  final AirQualityService _airQualityService = AirQualityService(
    apiKey: '50a4e8c254d27ff5fbf96264e7a3dcba',
  );

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _airQualityData = null;
      _error = null;
    });
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    if (_selectedDateTime == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final data = await _airQualityService.getHistory(
        position.latitude,
        position.longitude,
       
      );
      setState(() {
        _airQualityData = data.first;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique qualité de l\'air')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.calendar_today),
              label: const Text('Choisir date et heure'),
            ),
            if (_selectedDateTime != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Date/heure sélectionnée : ${_selectedDateTime!.toLocal().toString().substring(0, 16)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_airQualityData != null)
              Card(
                margin: const EdgeInsets.only(top: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AQI : ${_airQualityData!.aqi.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Catégorie : ${_airQualityData!.category}'),
                      const SizedBox(height: 16),
                      Text('Polluants :', style: Theme.of(context).textTheme.titleMedium),
                      ..._airQualityData!.pollutants.entries.map((entry) {
                        final pollutant = entry.value;
                        return ListTile(
                          title: Text(entry.key.toUpperCase()),
                          subtitle: Text('${pollutant.concentration} ${pollutant.unit}'),
                          trailing: Text(pollutant.category),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 