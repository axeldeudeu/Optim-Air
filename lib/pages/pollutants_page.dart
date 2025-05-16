import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/air_quality_service.dart';
import '../models/air_quality_data.dart';

class PollutantsPage extends StatefulWidget {
  const PollutantsPage({Key? key}) : super(key: key);

  @override
  State<PollutantsPage> createState() => _PollutantsPageState();
}

class _PollutantsPageState extends State<PollutantsPage> {
  AirQualityData? _airQualityData;
  bool _isLoading = true;
  final AirQualityService _airQualityService = AirQualityService(
    apiKey: '50a4e8c254d27ff5fbf96264e7a3dcba',
  );

  @override
  void initState() {
    super.initState();
    _fetchAirQualityData();
  }

  Future<void> _fetchAirQualityData() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final data = await _airQualityService.getCurrentAirQuality(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _airQualityData = data;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching air quality data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'good':
        return Colors.green;
      case 'moderate':
        return Colors.yellow;
      case 'unhealthy for sensitive groups':
        return Colors.orange;
      case 'unhealthy':
        return Colors.red;
      case 'very unhealthy':
        return Colors.purple;
      case 'hazardous':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_airQualityData == null) {
      return const Center(child: Text('Impossible de charger les données'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails des polluants'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAirQualityData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Indice de qualité de l\'air',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AQI: ${_airQualityData!.aqi.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(_airQualityData!.category),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _airQualityData!.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Polluants',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ..._airQualityData!.pollutants.entries.map((entry) {
              final pollutant = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(entry.key.toUpperCase()),
                  subtitle: Text(
                    '${pollutant.concentration} ${pollutant.unit}',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(pollutant.category),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      pollutant.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
} 