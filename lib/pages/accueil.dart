import 'package:cityweather/services/api_service.dart';
import 'package:cityweather/services/database_service.dart';
import 'package:cityweather/pages/favorites_page.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Page d'accueil "cityweather"
class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class WeatherData {
  final String city;
  final double temperatureC;
  final String description;
  final int weatherCode;
  final String? iconUrl;
  final int humidity;
  final double windKph;
  final double latitude;
  final double longitude;

  WeatherData({
    required this.city,
    required this.temperatureC,
    required this.description,
    required this.weatherCode,
    this.iconUrl,
    required this.humidity,
    required this.windKph,
    required this.latitude,
    required this.longitude,
  });
}

class _AccueilPageState extends State<AccueilPage> {
  final TextEditingController _cityController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  WeatherData? _weather; // Météo affichée actuellement
  WeatherData? _locationWeather; // Météo de la position GPS
  Map<String, dynamic>? _currentCityData; // Pour stocker les données de la ville actuelle
  bool _isFavorite = false;
  double? _currentLatitude;
  double? _currentLongitude;
  bool _isLoadingLocation = false;
  List<Map<String, dynamic>> _hourlyData = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  List<FavoriteCity> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _cityController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _cityController.removeListener(_onSearchChanged);
    _cityController.dispose();
    super.dispose();
  }

  Future<void> getCurrentLocation() async {
    setState(() {
      _isSearching = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _error = "GPS désactivé");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _error = "Permission GPS bloquée");
      return;
    }

    // 👉 Récupération de la position
    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final latitude = pos.latitude;
    final longitude = pos.longitude;

      // Appeler l'API météo avec ces coordonnées
      await _fetchWeatherFromLocation(latitude, longitude);
      
    } catch (e) {
      print('Erreur recherche: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

    Future<void> _fetchWeatherFromLocation(double latitude, double longitude) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Récupération météo pour lat: $latitude, lon: $longitude');
      
      final weatherData = await fetchWeatherFromCoordinates(latitude, longitude);
      print('Données météo reçues: $weatherData');

      if (weatherData['current_weather'] != null) {
        final current = weatherData['current_weather'];
        final weatherCode = (current['weathercode'] as num?)?.toInt() ?? 0;
        
        // Extraire les données horaires
        List<Map<String, dynamic>> hourlyData = [];
        if (weatherData['hourly'] != null) {
          print('Données horaires trouvées!');
          final hourly = weatherData['hourly'];
          print('Contenu hourly: $hourly');
          final times = hourly['time'] as List<dynamic>? ?? [];
          final temps = hourly['temperature_2m'] as List<dynamic>? ?? [];
          final codes = hourly['weathercode'] as List<dynamic>? ?? [];
          
          print('Nombre d\'heures: ${times.length}');
          print('Nombre de températures: ${temps.length}');
          print('Nombre de codes: ${codes.length}');
          
          // Prendre les 24 prochaines heures
          for (int i = 0; i < 24 && i < times.length; i++) {
            hourlyData.add({
              'time': times[i],
              'temperature': (temps[i] as num?)?.toDouble() ?? 0.0,
              'weathercode': (codes[i] as num?)?.toInt() ?? 0,
            });
          }
          print('Données horaires extraites: ${hourlyData.length} heures');
          print('Premier élément: ${hourlyData.isNotEmpty ? hourlyData[0] : "aucun"}');
        } else {
          print('Pas de données horaires dans la réponse API');
        }
        
        final weather = WeatherData(
          city: 'Ma position',
          temperatureC: (current['temperature'] as num?)?.toDouble() ?? 0.0,
          description: _getWeatherDescription(weatherCode),
          weatherCode: weatherCode,
          iconUrl: '',
          humidity: 0,
          windKph: (current['windspeed'] as num?)?.toDouble() ?? 0.0,
          latitude: latitude,
          longitude: longitude,
        );

        print('Avant setState - hourlyData.length: ${hourlyData.length}');
        setState(() {
          _locationWeather = weather;
          _hourlyData = hourlyData;
          _isLoading = false;
        });
        print('Après setState - _hourlyData.length: ${_hourlyData.length}');
      }
    } catch (e) {
      print('Erreur récupération météo position: $e');
      setState(() {
        _isLoading = false;
        _error = 'Impossible de récupérer la météo pour cette position';
      });
    }
  }

  // Sélectionner une ville depuis les suggestions
  void selectCity(Map<String, dynamic> cityData) async {
    print('=== selectCity appelée ===');
    print('cityData: $cityData');
    
    setState(() {
      _cityController.clear();
      _suggestions = [];
    });
    
    // Lancer la recherche météo avec les coordonnées directes
    await fetchWeatherForCity(cityData);
    
    // Vérifier si c'est un favori et recharger la liste
    await _loadFavorites();
  }

  // Récupérer la position GPS actuelle
  // TODO: Implémenter la géolocalisation avec le package geolocator
  Future<void> getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // TODO: Remplacer par la vraie géolocalisation
      // Exemple pour Paris en attendant :
      await Future.delayed(const Duration(seconds: 1));
      
      final latitude = 48.8566; // TODO: utiliser la vraie latitude
      final longitude = 2.3522; // TODO: utiliser la vraie longitude
      
      setState(() {
        _currentLatitude = latitude;
        _currentLongitude = longitude;
      });
      
      // Appeler l'API météo avec ces coordonnées
      await _fetchWeatherFromLocation(latitude, longitude);
      
    } catch (e) {
      print('Erreur récupération position: $e');
      setState(() {
        _error = "Impossible de récupérer la position: $e";
      });
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  // Récupérer la météo depuis les coordonnées GPS


  // Remplacez le contenu de cette fonction par votre appel API.
  Future<void> fetchWeather(String city) async {
    print('=== Début fetchWeather pour: $city ===');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Appel de fetchData...');
      final data = await fetchData(city);
      
      // Afficher le résultat dans la console
      print('Résultat API: $data');
      
      // Extraire les données de géocodage et météo
      final geoData = data['geo'];
      final forecastData = data['forecast'];
      
      // Vérifier si des résultats ont été trouvés
      if (geoData['results'] != null && (geoData['results'] as List).isNotEmpty) {
        final cityInfo = geoData['results'][0];
        _processWeatherData(cityInfo, forecastData);
      } else {
        setState(() {
          _error = "Aucune ville trouvée";
        });
      }
    } catch (e) {
      print('Erreur: $e');
      setState(() {
        _error = "Impossible de récupérer la météo: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Récupérer la météo à partir des coordonnées déjà connues
  Future<void> fetchWeatherForCity(Map<String, dynamic> cityInfo) async {
    print('=== fetchWeatherForCity appelée ===');
    print('cityInfo: $cityInfo');
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final latitude = (cityInfo['latitude'] as num).toDouble();
      final longitude = (cityInfo['longitude'] as num).toDouble();
      
      print('Coordonnées: lat=$latitude, lon=$longitude');
      
      // Appeler l'API météo via api_service
      final forecastData = await fetchWeatherFromCoordinates(latitude, longitude);
      print('forecastData reçu: $forecastData');
      
      _processWeatherData(cityInfo, forecastData);
    } catch (e) {
      print('Erreur dans fetchWeatherForCity: $e');
      setState(() {
        _error = "Impossible de récupérer la météo: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Traiter les données météo (fonction commune)
  void _processWeatherData(Map<String, dynamic> cityInfo, Map<String, dynamic> forecastData) async {
    print('=== _processWeatherData appelée ===');
    print('forecastData: $forecastData');
    
    try {
      final currentWeather = forecastData['current_weather'];
      print('currentWeather: $currentWeather');
      
      // Extraire les coordonnées
      final geoLat = (cityInfo['latitude'] as num).toDouble();
      final geoLon = (cityInfo['longitude'] as num).toDouble();
      
      // Créer WeatherData avec les vraies données de l'API
      final weatherCode = (currentWeather['weathercode'] as num?)?.toInt() ?? 0;
      
      // Extraire les données horaires
      List<Map<String, dynamic>> hourlyData = [];
      if (forecastData['hourly'] != null) {
        final hourly = forecastData['hourly'];
        final times = hourly['time'] as List<dynamic>? ?? [];
        final temps = hourly['temperature_2m'] as List<dynamic>? ?? [];
        final codes = hourly['weathercode'] as List<dynamic>? ?? [];
        
        for (int i = 0; i < 24 && i < times.length; i++) {
          hourlyData.add({
            'time': times[i],
            'temperature': (temps[i] as num?)?.toDouble() ?? 0.0,
            'weathercode': (codes[i] as num?)?.toInt() ?? 0,
          });
        }
      }
      
      final weatherData = WeatherData(
        city: '${cityInfo['name']}${cityInfo['country'] != null ? ", ${cityInfo['country']}" : ""}',
        temperatureC: (currentWeather['temperature'] as num?)?.toDouble() ?? 0.0,
        description: _getWeatherDescription(weatherCode),
        weatherCode: weatherCode,
        iconUrl: null,
        humidity: (forecastData['current_weather']['humidity'] as num?)?.toInt() ?? 0,
        windKph: (currentWeather['windspeed'] as num?)?.toDouble() ?? 0.0,
        latitude: geoLat,
        longitude: geoLon,
      );

      print('weatherData créé: ${weatherData.city}, ${weatherData.temperatureC}°C');

      // Stocker les données de la ville actuelle
      _currentCityData = cityInfo;
      
      // Vérifier si la ville est en favoris
      bool isFav = false;
      try {
        isFav = await DatabaseService.instance.isFavorite(
          cityInfo['name'],
          cityInfo['country'] ?? '',
        );
        print('isFavorite: $isFav');
      } catch (e) {
        print('Erreur vérification favoris: $e');
      }

      print('Appel setState...');

      setState(() {
        _weather = weatherData;
        _hourlyData = hourlyData;
        _isFavorite = isFav;
        _locationWeather = null; // Désactiver l'affichage GPS
      });
      print('setState terminé, _weather=${_weather != null}');
    } catch (e) {
      print('ERREUR dans _processWeatherData: $e');
      setState(() {
        _error = "Erreur traitement données: $e";
      });
    }
  }
//   void _openMapWithCurrentPosition() {
//   if (_locationWeather == null) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text("Aucune position GPS disponible.")),
//     );
//     return;
//   }

//   openGoogleMaps(
//     _locationWeather!.latitude,
//     _locationWeather!.longitude,
//   );
// }
void _openMapWithCurrentPosition() {
  if (_locationWeather == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Localise-toi d'abord.")),
    );
    return;
  }

  openGoogleMaps(
    _locationWeather!.latitude,
    _locationWeather!.longitude,
  );
}


  // Ajouter/retirer des favoris
  Future<void> _toggleFavorite() async {
    if (_currentCityData == null) return;

    try {
      if (_isFavorite) {
        // Trouver et supprimer le favori
        final favorites = await DatabaseService.instance.getFavorites();
        final favorite = favorites.firstWhere(
          (f) => f.name == _currentCityData!['name'] && 
                 f.country == (_currentCityData!['country'] ?? ''),
        );
        await DatabaseService.instance.deleteFavorite(favorite.id!);
        
        setState(() => _isFavorite = false);
        await _loadFavorites();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retiré des favoris')),
        );
      } else {
        // Ajouter aux favoris
        final favoriteCity = FavoriteCity.fromApiData(_currentCityData!);
        await DatabaseService.instance.addFavorite(favoriteCity);
        
        setState(() => _isFavorite = true);
        await _loadFavorites();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajouté aux favoris')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
  void _openMapFromWeather(WeatherData w) {
  openGoogleMaps(w.latitude, w.longitude);
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
    print("Erreur Google Maps: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Impossible d’ouvrir Maps")),
    );
  }
}

  

  // Ouvrir la page des favoris
  void _openFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FavoritesPage(
          onCitySelected: (cityData) {
            fetchWeatherForCity(cityData);
          },
        ),
      ),
    );
  }

  // Convertir le code météo en description
  String _getWeatherDescription(int? code) {
    if (code == null) return 'Conditions inconnues';
    
    switch (code) {
      case 0:
        return 'Ciel dégagé';
      case 1:
      case 2:
      case 3:
        return 'Partiellement nuageux';
      case 45:
      case 48:
        return 'Brouillard';
      case 51:
      case 53:
      case 55:
        return 'Bruine';
      case 61:
      case 63:
      case 65:
        return 'Pluie';
      case 71:
      case 73:
      case 75:
        return 'Neige';
      case 95:
        return 'Orage';
      default:
        return 'Conditions variables';
    }
  }

  Widget _buildBody() {
    print('_buildBody: _isLoading=$_isLoading, _error=$_error, _locationWeather=${_locationWeather != null}');
    
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              'Chargement de la météo...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white.withOpacity(0.7),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        if (_showSuggestions && _citySuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _citySuggestions.length,
              itemBuilder: (context, index) {
                final city = _citySuggestions[index];
                final cityName = city['name'] ?? '';
                final country = city['country'] ?? '';
                final admin1 = city['admin1'] ?? ''; // Région/État
                
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on, size: 20),
                  title: Text(cityName),
                  subtitle: Text(
                    [admin1, country].where((s) => s.isNotEmpty).join(', '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => selectCity(city),
                );
              },
            ),
          ),
      ],
    );
  }
  Widget _buildWeatherCard(WeatherData w, {required bool isLocation}) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  w.city,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (!isLocation)
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.star : Icons.star_border,
                    color: _isFavorite ? Colors.amber : Colors.grey,
                  ),
                  onPressed: _toggleFavorite,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.wb_cloudy, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${w.temperatureC.round()} °C',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(w.description),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('Humidité: ${w.humidity}%')),
              Expanded(
                child: Text(
                  'Vent: ${w.windKph.toStringAsFixed(1)} kph',
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Coordonnées: ${w.latitude.toStringAsFixed(4)}°, ${w.longitude.toStringAsFixed(4)}°',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),

          // 👉 BOUTON GOOGLE MAPS ICI
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openMapFromWeather(w),
            icon: const Icon(Icons.map),
            label: const Text("Ouvrir dans Google Maps"),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildBody() {
    print('_buildBody: _isLoading=$_isLoading, _error=$_error, _weather=${_weather != null}, _locationWeather=${_locationWeather != null}');
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    // Afficher les cartes disponibles
    List<Widget> weatherCards = [];
    
    // Toujours afficher la carte de position si disponible
    if (_locationWeather != null) {
      weatherCards.add(_buildWeatherCard(_locationWeather!, isLocation: true));
    }
    
    // Ajouter la carte de recherche si disponible
    if (_weather != null) {
      weatherCards.add(_buildWeatherCard(_weather!, isLocation: false));
    }
    
    // Si aucune météo n'est disponible
    if (weatherCards.isEmpty) {
      return const Center(child: Text('Saisissez une ville ou utilisez votre position pour voir la météo.'));
    }
  }
  
  Widget _buildWeatherInfo(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
  
  Widget _buildHourlyForecast() {
    return SizedBox(
      height: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Prochaines 24h',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _hourlyData.isEmpty
                ? Center(
                    child: Text(
                      'Chargement...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _hourlyData.length,
                    itemBuilder: (context, index) {
                      final hour = _hourlyData[index];
                      final timeStr = hour['time'] as String;
                      final temp = hour['temperature'] as double;
                      final code = hour['weathercode'] as int;
                      
                      // Extraire l'heure depuis le format ISO 8601
                      final DateTime dateTime = DateTime.parse(timeStr);
                      final hourStr = '${dateTime.hour}h';
                      
                      return Container(
                        width: 70,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              hourStr,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              _getWeatherIcon(code),
                              color: Colors.white.withOpacity(0.9),
                              size: 28,
                            ),
                            Text(
                              '${temp.round()}°',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _weather ?? _locationWeather;
    final gradientColors = w != null
        ? _getGradientColors(w.weatherCode)
        : [const Color(0xFF4A90E2), const Color(0xFF87CEEB)];
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wb_sunny,
              color: Colors.white.withOpacity(0.9),
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              'CityWeather',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.star,
                color: Colors.white.withOpacity(0.9),
              ),
              onPressed: _openFavorites,
              tooltip: 'Mes favoris',
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchBar(),

            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
  
  List<Color> _getGradientColors(int weatherCode) {
    switch (weatherCode) {
      case 0: // Ciel dégagé - Bleu ciel lumineux
        return [const Color(0xFF4A90E2), const Color(0xFF87CEEB)];
      
      case 1: // Principalement dégagé - Bleu clair
        return [const Color(0xFF64B5F6), const Color(0xFF90CAF9)];
      
      case 2: // Partiellement nuageux - Gris-bleu
        return [const Color(0xFF78909C), const Color(0xFF90A4AE)];
      
      case 3: // Nuageux - Gris
        return [const Color(0xFF607D8B), const Color(0xFF90A4AE)];
      
      case 45:
      case 48: // Brouillard - Gris pâle
        return [const Color(0xFF90A4AE), const Color(0xFFCFD8DC)];
      
      case 51:
      case 53:
      case 55: // Bruine - Gris bleuté
        return [const Color(0xFF78909C), const Color(0xFF90A4AE)];
      
      case 61:
      case 63:
      case 65: // Pluie - Gris foncé bleuté
        return [const Color(0xFF546E7A), const Color(0xFF78909C)];
      
      case 66:
      case 67: // Pluie verglaçante - Gris glacé
        return [const Color(0xFF607D8B), const Color(0xFF90A4AE)];
      
      case 71:
      case 73:
      case 75: // Neige - Blanc-bleu glacé
        return [const Color(0xFF90CAF9), const Color(0xFFBBDEFB)];
      
      case 77: // Grains de neige - Blanc glacé
        return [const Color(0xFFB0BEC5), const Color(0xFFCFD8DC)];
      
      case 80:
      case 81:
      case 82: // Averses de pluie - Gris orageux
        return [const Color(0xFF546E7A), const Color(0xFF607D8B)];
      
      case 85:
      case 86: // Averses de neige - Gris-blanc
        return [const Color(0xFF90A4AE), const Color(0xFFB0BEC5)];
      
      case 95:
      case 96:
      case 99: // Orage - Gris très foncé
        return [const Color(0xFF37474F), const Color(0xFF546E7A)];
      
      default: // Par défaut - Bleu ciel
        return [const Color(0xFF4A90E2), const Color(0xFF87CEEB)];
    }
  }
}