import 'package:cityweather/services/api_service.dart';
import 'package:cityweather/services/database_service.dart';
import 'package:cityweather/pages/favorites_page.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Page d'accueil "cityweather"
/// Structure seulement — insérez vos appels API dans fetchWeather()
class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class WeatherData {
  final String city;
  final double temperatureC;
  final String description;
  final String? iconUrl;
  final int humidity;
  final double windKph;
  final double latitude;
  final double longitude;

  WeatherData({
    required this.city,
    required this.temperatureC,
    required this.description,
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

  Future<void> getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
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
        
        final weather = WeatherData(
          city: 'Ma position',
          temperatureC: current['temperature'].toDouble(),
          description: _getWeatherDescription(current['weathercode']),
          iconUrl: '',
          humidity: 0,
          windKph: current['windspeed'].toDouble(),
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
      final weatherData = WeatherData(
        city: '${cityInfo['name']}${cityInfo['country'] != null ? ", ${cityInfo['country']}" : ""}',
        temperatureC: (currentWeather['temperature'] as num).toDouble(),
        description: _getWeatherDescription(currentWeather['weathercode']),
        iconUrl: null,
        humidity: forecastData['current_weather']['humidity'] ?? 0,
        windKph: (currentWeather['windspeed'] as num).toDouble(),
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
  String _getWeatherDescription(int code) {
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
        // Bouton de géolocalisation avec affichage des coordonnées
        Card(
          elevation: 2,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ma position',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (_currentLatitude != null && _currentLongitude != null)
                            Text(
                              'Lat: ${_currentLatitude!.toStringAsFixed(4)}°, Lon: ${_currentLongitude!.toStringAsFixed(4)}°',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            )
                          else
                            const Text(
                              'Coordonnées non disponibles',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoadingLocation ? null : getCurrentLocation,
                      icon: _isLoadingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 20),
                      label: Text(_isLoadingLocation ? 'Chargement...' : 'Localiser'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Barre de recherche existante
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cityController,
                decoration: const InputDecoration(
                  hintText: 'Entrez une ville',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  // Rechercher les suggestions à chaque lettre tapée
                  if (value.length >= 2) {
                    searchCities(value);
                  } else {
                    setState(() {
                      _showSuggestions = false;
                      _citySuggestions = [];
                    });
                  }
                },
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) fetchWeather(value.trim());
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      final city = _cityController.text.trim();
                      if (city.isNotEmpty) fetchWeather(city);
                    },
              child: const Text('Rechercher'),
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

    return SingleChildScrollView(
      child: Column(
        children: weatherCards,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('cityweather'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: _openFavorites,
            tooltip: 'Villes favorites',
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
}