import 'package:cityweather/services/api_service.dart';
import 'package:cityweather/services/database_service.dart';
import 'package:cityweather/pages/favorites_page.dart';
import 'package:cityweather/widgets/weather_card.dart';
import 'package:cityweather/widgets/location_card.dart';
import 'package:cityweather/widgets/search_bar_widget.dart';
import 'package:flutter/material.dart';

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
  WeatherData? _weather; // Météo de la recherche
  WeatherData? _locationWeather; // Météo de la position GPS
  List<Map<String, dynamic>> _citySuggestions = [];
  bool _showSuggestions = false;
  Map<String, dynamic>? _currentCityData; // Pour stocker les données de la ville actuelle
  bool _isFavorite = false;
  double? _currentLatitude;
  double? _currentLongitude;
  bool _isLoadingLocation = false;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
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

        setState(() {
          _locationWeather = weather;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur récupération météo position: $e');
      setState(() {
        _isLoading = false;
        _error = 'Impossible de récupérer la météo pour cette position';
      });
    }
  }

  // Rechercher les suggestions de villes
  Future<void> searchCities(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _citySuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      print('Recherche de suggestions pour: $query');
      final suggestions = await fetchCitySuggestions(query);
      print('Suggestions reçues: ${suggestions.length}');
      
      setState(() {
        _citySuggestions = suggestions;
        _showSuggestions = suggestions.isNotEmpty;
      });
    } catch (e) {
      print('Erreur recherche suggestions: $e');
      setState(() {
        _citySuggestions = [];
        _showSuggestions = false;
      });
    }
  }

  // Sélectionner une ville depuis les suggestions
  void selectCity(Map<String, dynamic> cityData) {
    print('=== selectCity appelée ===');
    print('cityData: $cityData');
    
    final cityName = cityData['name'];
    final country = cityData['country'] ?? '';
    
    setState(() {
      _cityController.text = '$cityName, $country';
      _showSuggestions = false;
    });
    
    // Lancer la recherche météo avec les coordonnées directes
    fetchWeatherForCity(cityData);
  }

  // Remplacez le contenu de cette fonction par votre appel API.
  Future<void> fetchWeather(String city) async {
    print('=== Début fetchWeather pour: $city ===');
    setState(() {
      _isLoading = true;
      _error = null;
      _showSuggestions = false;
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
        _isFavorite = isFav;
      });
      
      print('setState terminé, _weather=${_weather != null}');
    } catch (e) {
      print('ERREUR dans _processWeatherData: $e');
      setState(() {
        _error = "Erreur traitement données: $e";
      });
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retiré des favoris')),
        );
      } else {
        // Ajouter aux favoris
        final favoriteCity = FavoriteCity.fromApiData(_currentCityData!);
        await DatabaseService.instance.addFavorite(favoriteCity);
        
        setState(() => _isFavorite = true);
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

  Widget _buildSearchBar() {
    return Column(
      children: [
        // Nouvelle carte de localisation
        LocationCard(
          latitude: _currentLatitude,
          longitude: _currentLongitude,
          isLoading: _isLoadingLocation,
          onLocate: getCurrentLocation,
        ),
        const SizedBox(height: 16),
        
        // Nouveau widget de recherche
        SearchBarWidget(
          controller: _cityController,
          isLoading: _isLoading,
          showSuggestions: _showSuggestions,
          suggestions: _citySuggestions,
          onChanged: (value) {
            if (value.length >= 1) {
              searchCities(value);
            } else {
              setState(() {
                _showSuggestions = false;
                _citySuggestions = [];
              });
            }
          },
          onSearch: () {
            final city = _cityController.text.trim();
            if (city.isNotEmpty) fetchWeather(city);
          },
          onSuggestionTap: selectCity,
        ),
      ],
    );
  }

  Widget _buildWeatherCard(WeatherData w, {required bool isLocation}) {
    return WeatherCard(
      city: w.city,
      temperature: w.temperatureC,
      description: w.description,
      weatherCode: w.weatherCode,
      humidity: w.humidity.toDouble(),
      windSpeed: w.windKph,
      latitude: w.latitude,
      longitude: w.longitude,
      isFavorite: isLocation ? false : _isFavorite,
      onFavoriteToggle: isLocation ? null : _toggleFavorite,
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

    return SingleChildScrollView(
      child: Column(
        children: weatherCards,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wb_sunny,
              color: Colors.orange.shade400,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              'CityWeather',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
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
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onPressed: _openFavorites,
              tooltip: 'Mes favoris',
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50.withOpacity(0.3),
              const Color(0xFFF8F9FA),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildSearchBar(),
                const SizedBox(height: 16),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}