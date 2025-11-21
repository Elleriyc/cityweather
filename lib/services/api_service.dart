
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:cityweather/utils/logger.dart';

Future<Map<String, dynamic>> fetchData(String cityName) async {
  final urlGeoCoding = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(cityName)}');
  
  final response = await http.get(urlGeoCoding);

  if (response.statusCode != 200) {
    throw Exception('Erreur géocodage : ${response.statusCode}');
  }

  final dataGeo = jsonDecode(response.body);
  
  logger.d('Données géocodage: $dataGeo');
  
  if (dataGeo['results'] == null || (dataGeo['results'] as List).isEmpty) {
    throw Exception('Ville non trouvée');
  }
  
  final firstResult = dataGeo['results'][0];
  final latitude = firstResult['latitude'];
  final longitude = firstResult['longitude'];
  
  logger.d('Coordonnées: lat=$latitude, lon=$longitude');
  
  final urlForecast = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code');
  
  final responseForecast = await http.get(urlForecast);
  
  if (responseForecast.statusCode != 200) {
    throw Exception('Erreur météo : ${responseForecast.statusCode}');
  }
  
  final dataForecast = jsonDecode(responseForecast.body);
  
  logger.d('Données météo: $dataForecast');
  
  return {
    'geo': dataGeo,
    'forecast': dataForecast,
  };
}

Future<List<Map<String, dynamic>>> fetchCitySuggestions(String cityName) async {
  final urlGeoCoding = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(cityName)}');
  
  final response = await http.get(urlGeoCoding);

  if (response.statusCode != 200) {
    throw Exception('Erreur géocodage : ${response.statusCode}');
  }

  final dataGeo = jsonDecode(response.body);
  
  if (dataGeo['results'] == null) {
    return [];
  }
  
  return List<Map<String, dynamic>>.from(dataGeo['results']);
}

Future<Map<String, dynamic>> fetchWeatherFromCoordinates(double latitude, double longitude) async {
  final urlForecast = Uri.parse(
    'https://api.open-meteo.com/v1/forecast?'
    'latitude=$latitude&longitude=$longitude'
    '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code'
    '&hourly=temperature_2m,weathercode,relative_humidity_2m'
    '&forecast_days=1'
  );
  
  final response = await http.get(urlForecast);
  
  if (response.statusCode != 200) {
    throw Exception('Erreur météo : ${response.statusCode}');
  }
  
  final dataForecast = jsonDecode(response.body);
  
  logger.d('Données météo complètes: ${dataForecast.keys}');
  logger.d('Hourly present: ${dataForecast.containsKey('hourly')}');
  if (dataForecast.containsKey('hourly')) {
    logger.d('Hourly keys: ${(dataForecast['hourly'] as Map).keys}');
  }
  
  return dataForecast;
}

Future<void> openGoogleMaps(double lat, double lon) async {
  final webUrl = Uri.parse(
    "https://www.google.com/maps/search/?api=1&query=$lat,$lon",
  );

  try {
    await launchUrl(
      webUrl,
      mode: LaunchMode.externalApplication,
    );
  } catch (e) {
    logger.e("Erreur Google Maps: $e");
    throw Exception("Impossible d'ouvrir Maps");
  }
}
