import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/air_quality_service.dart';
import '../models/air_quality_data.dart';

// Ajoutez ces constantes au début de chaque fichier
const Color primaryColor = Color(0xFF0088FF); // Bleu vif
const Color secondaryColor = Color(0xFF00D2FF); // Bleu cyan
const Color accentColor = Color(0xFF00E5FF); // Cyan lumineux
const Color darkColor = Color(0xFF121212); // Presque noir
const Color backgroundColor = Color(0xFF0A1929); // Bleu très foncé
const Color cardColor = Color(0xFF162033); // Bleu-gris foncé

final darkGradient = LinearGradient(
  colors: [darkColor, backgroundColor],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

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
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text('Historique qualité de l\'air'),
    ),
    body: Container(
      decoration: BoxDecoration(
        gradient: darkGradient,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: kToolbarHeight), // Espace pour l'AppBar
            
            // Date picker
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sélectionnez une date',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickDateTime,
                    icon: Icon(Icons.calendar_today),
                    label: Text('Choisir date et heure'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  if (_selectedDateTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: accentColor,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Date/heure : ${_selectedDateTime!.toLocal().toString().substring(0, 16)}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Contenu
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    )
                  : _error != null
                      ? _buildErrorMessage()
                      : _airQualityData != null
                          ? _buildDataCard()
                          : Center(
                              child: Text(
                                'Sélectionnez une date pour voir les données',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildErrorMessage() {
  return Center(
    child: Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade300,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchHistory,
            icon: Icon(Icons.refresh),
            label: Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildDataCard() {
  final color = _getCategoryColor(_airQualityData!.category);
  
  return SingleChildScrollView(
    child: Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Indice de qualité de l\'air',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color, width: 1),
                  ),
                  child: Text(
                    'AQI: ${_airQualityData!.aqi.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Contenu
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _getCategoryIcon(_airQualityData!.category),
                      color: color,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Catégorie : ${_airQualityData!.category}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  'Polluants :',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                ..._airQualityData!.pollutants.entries.map((entry) {
                  final pollutant = entry.value;
                  final pollutantColor = _getCategoryColor(pollutant.category);
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: darkColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: pollutantColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: pollutantColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getPollutantIcon(entry.key),
                            color: pollutantColor,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${pollutant.concentration.toStringAsFixed(1)} ${pollutant.unit}',
                                style: TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: pollutantColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            pollutant.category,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// Ajoutez ces fonctions
Color _getCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'good':
      return Color(0xFF4CAF50); // Vert
    case 'moderate':
      return Color(0xFFFFC107); // Jaune
    case 'unhealthy for sensitive groups':
      return Color(0xFFFF9800); // Orange
    case 'unhealthy':
      return Color(0xFFF44336); // Rouge
    case 'very unhealthy':
      return Color(0xFF9C27B0); // Violet
    case 'hazardous':
      return Color(0xFF795548); // Marron
    default:
      return Color(0xFF607D8B); // Gris bleuté
  }
}

IconData _getCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'good':
      return Icons.sentiment_very_satisfied;
    case 'moderate':
      return Icons.sentiment_satisfied;
    case 'unhealthy for sensitive groups':
      return Icons.sentiment_neutral;
    case 'unhealthy':
      return Icons.sentiment_dissatisfied;
    case 'very unhealthy':
      return Icons.sentiment_very_dissatisfied;
    case 'hazardous':
      return Icons.dangerous;
    default:
      return Icons.help_outline;
  }
}

IconData _getPollutantIcon(String pollutantKey) {
  switch (pollutantKey.toLowerCase()) {
    case 'pm25':
      return Icons.grain;
    case 'pm10':
      return Icons.blur_circular;
    case 'o3':
      return Icons.air;
    case 'no2':
      return Icons.cloud;
    case 'so2':
      return Icons.cloud_queue;
    case 'co':
      return Icons.local_fire_department;
    default:
      return Icons.bubble_chart;
  }
}
} 