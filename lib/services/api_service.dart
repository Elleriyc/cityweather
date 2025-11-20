
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<Map<String, dynamic>> fetchData(String cityName) async {
  // 1. Récupérer les coordonnées de la ville
  final urlGeoCoding = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(cityName)}');
  
  final response = await http.get(urlGeoCoding);

  if (response.statusCode != 200) {
    throw Exception('Erreur géocodage : ${response.statusCode}');
  }

  final dataGeo = jsonDecode(response.body);
  
  // Afficher les données de géocodage
  print('Données géocodage: $dataGeo');
  
  // Vérifier qu'on a des résultats
  if (dataGeo['results'] == null || (dataGeo['results'] as List).isEmpty) {
    throw Exception('Ville non trouvée');
  }
  
  // Extraire latitude et longitude du premier résultat
  final firstResult = dataGeo['results'][0];
  final latitude = firstResult['latitude'];
  final longitude = firstResult['longitude'];
  
  print('Coordonnées: lat=$latitude, lon=$longitude');
  
  // 2. Récupérer les données météo avec les coordonnées
  final urlForecast = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true');
  
  final responseForecast = await http.get(urlForecast);
  
  if (responseForecast.statusCode != 200) {
    throw Exception('Erreur météo : ${responseForecast.statusCode}');
  }
  
  final dataForecast = jsonDecode(responseForecast.body);
  
  // Afficher les données météo
  print('Données météo: $dataForecast');
  
  // Retourner les deux ensembles de données combinés
  return {
    'geo': dataGeo,
    'forecast': dataForecast,
  };
}

// Récupérer uniquement les suggestions de villes (sans météo)
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

// Récupérer la météo à partir de coordonnées
Future<Map<String, dynamic>> fetchWeatherFromCoordinates(double latitude, double longitude) async {
  final urlForecast = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true');
  
  final response = await http.get(urlForecast);
  
  if (response.statusCode != 200) {
    throw Exception('Erreur météo : ${response.statusCode}');
  }
  
  final dataForecast = jsonDecode(response.body);
  
  print('Données météo: $dataForecast');
  
  return dataForecast;
}