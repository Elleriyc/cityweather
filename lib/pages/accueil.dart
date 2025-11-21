import 'package:cityweather/services/api_service.dart';
import 'package:cityweather/services/database_service.dart';
import 'package:cityweather/pages/favorites_page.dart';
import 'package:cityweather/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
  WeatherData? _weather;
  WeatherData? _locationWeather;
  Map<String, dynamic>? _currentCityData;
  bool _isFavorite = false;
  bool _isLoadingLocation = false;
  List<Map<String, dynamic>> _hourlyData = [];
  List<Map<String, dynamic>> _suggestions = [];
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

  Future<void> _loadFavorites() async {
    try {
      final favorites = await DatabaseService.instance.getFavorites();
      setState(() {
        _favorites = favorites;
      });
    } catch (e) {
      logger.e('Erreur chargement favoris: $e');
    }
  }

  void _onSearchChanged() async {
    final query = _cityController.text.trim();
    logger.d('_onSearchChanged appelé avec: "$query"');
    
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    if (query.length < 2) {
      logger.d('Query trop courte: ${query.length} caractères');
      return;
    }

    try {
      logger.d('Appel fetchCitySuggestions pour: $query');
      final results = await fetchCitySuggestions(query);
      logger.d('Résultats reçus: ${results.length} villes');
      logger.d('Premiers résultats: $results');
      
      setState(() {
        _suggestions = results;
      });
      logger.d('setState terminé, _suggestions.length = ${_suggestions.length}');
    } catch (e) {
      logger.e('Erreur recherche: $e');
    }
  }

    Future<void> _fetchWeatherFromLocation(double latitude, double longitude) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      logger.d('Récupération météo pour lat: $latitude, lon: $longitude');
      
      final weatherData = await fetchWeatherFromCoordinates(latitude, longitude);
      logger.d('Données météo reçues: $weatherData');

      if (weatherData['current'] != null) {
        final current = weatherData['current'];
        final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
        
        List<Map<String, dynamic>> hourlyData = [];
        if (weatherData['hourly'] != null) {
          logger.d('Données horaires trouvées!');
          final hourly = weatherData['hourly'];
          logger.d('Contenu hourly: $hourly');
          final times = hourly['time'] as List<dynamic>? ?? [];
          final temps = hourly['temperature_2m'] as List<dynamic>? ?? [];
          final codes = hourly['weathercode'] as List<dynamic>? ?? [];
          
          logger.d('Nombre d\'heures: ${times.length}');
          logger.d('Nombre de températures: ${temps.length}');
          logger.d('Nombre de codes: ${codes.length}');
          
          for (int i = 0; i < 24 && i < times.length; i++) {
            hourlyData.add({
              'time': times[i],
              'temperature': (temps[i] as num?)?.toDouble() ?? 0.0,
              'weathercode': (codes[i] as num?)?.toInt() ?? 0,
            });
          }
          logger.d('Données horaires extraites: ${hourlyData.length} heures');
          logger.d('Premier élément: ${hourlyData.isNotEmpty ? hourlyData[0] : "aucun"}');
        } else {
          logger.d('Pas de données horaires dans la réponse API');
        }
        
        final weather = WeatherData(
          city: 'Ma position',
          temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
          description: _getWeatherDescription(weatherCode),
          weatherCode: weatherCode,
          iconUrl: '',
          humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
          windKph: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
          latitude: latitude,
          longitude: longitude,
        );

        logger.d('Avant setState - hourlyData.length: ${hourlyData.length}');
        setState(() {
          _locationWeather = weather;
          _hourlyData = hourlyData;
          _isLoading = false;
          _isLoadingLocation = false;
        });
        logger.d('Après setState - _hourlyData.length: ${_hourlyData.length}');
      }
    } catch (e) {
      logger.e('Erreur récupération météo position: $e');
      setState(() {
        _isLoading = false;
        _isLoadingLocation = false;
        _error = 'Impossible de récupérer la météo pour cette position';
      });
    }
  }

  void selectCity(Map<String, dynamic> cityData) async {
    logger.d('=== selectCity appelée ===');
    logger.d('cityData: $cityData');
    
    setState(() {
      _cityController.clear();
      _suggestions = [];
    });
    
    await fetchWeatherForCity(cityData);
    
    await _loadFavorites();
    await _loadFavorites();
  }

  Future<void> getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _error = null;
      _weather = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _error = "GPS désactivé";
        _isLoadingLocation = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _error = "Permission GPS bloquée";
        _isLoadingLocation = false;
      });
      return;
    }

    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final latitude = pos.latitude;
    final longitude = pos.longitude;

      await _fetchWeatherFromLocation(latitude, longitude);

    } catch (e) {
      logger.e('Erreur récupération position: $e');
      setState(() {
        _error = "Impossible de récupérer la position: $e";
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> fetchWeather(String city) async {
    logger.d('=== Début fetchWeather pour: $city ===');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      logger.d('Appel de fetchData...');
      final data = await fetchData(city);
      
      logger.d('Résultat API: $data');
      
      final geoData = data['geo'];
      final forecastData = data['forecast'];
      
      if (geoData['results'] != null && (geoData['results'] as List).isNotEmpty) {
        final cityInfo = geoData['results'][0];
        _processWeatherData(cityInfo, forecastData);
      } else {
        setState(() {
          _error = "Aucune ville trouvée";
        });
      }
    } catch (e) {
      logger.e('Erreur: $e');
      setState(() {
        _error = "Impossible de récupérer la météo: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> fetchWeatherForCity(Map<String, dynamic> cityInfo) async {
    logger.d('=== fetchWeatherForCity appelée ===');
    logger.d('cityInfo: $cityInfo');
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final latitude = (cityInfo['latitude'] as num).toDouble();
      final longitude = (cityInfo['longitude'] as num).toDouble();
      
      logger.d('Coordonnées: lat=$latitude, lon=$longitude');
      
      final forecastData = await fetchWeatherFromCoordinates(latitude, longitude);
      logger.d('forecastData reçu: $forecastData');
      
      _processWeatherData(cityInfo, forecastData);
    } catch (e) {
      logger.e('Erreur dans fetchWeatherForCity: $e');
      setState(() {
        _error = "Impossible de récupérer la météo: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _processWeatherData(Map<String, dynamic> cityInfo, Map<String, dynamic> forecastData) async {
    logger.d('=== _processWeatherData appelée ===');
    logger.d('forecastData: $forecastData');
    
    try {
      final current = forecastData['current'];
      logger.d('current: $current');
      
      final geoLat = (cityInfo['latitude'] as num).toDouble();
      final geoLon = (cityInfo['longitude'] as num).toDouble();
      
      final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
      
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
        temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
        description: _getWeatherDescription(weatherCode),
        weatherCode: weatherCode,
        iconUrl: null,
        humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
        windKph: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
        latitude: geoLat,
        longitude: geoLon,
      );

      logger.d('weatherData créé: ${weatherData.city}, ${weatherData.temperatureC}°C');

      _currentCityData = cityInfo;
      
      bool isFav = false;
      try {
        isFav = await DatabaseService.instance.isFavorite(
          cityInfo['name'],
          cityInfo['country'] ?? '',
        );
        logger.d('isFavorite: $isFav');
      } catch (e) {
        logger.e('Erreur vérification favoris: $e');
      }

      logger.d('Appel setState...');

      setState(() {
        _weather = weatherData;
        _hourlyData = hourlyData;
        _isFavorite = isFav;
        _locationWeather = null;
      });
      
      logger.d('setState terminé, _weather=${_weather != null}');
    } catch (e) {
      logger.e('ERREUR dans _processWeatherData: $e');
      setState(() {
        _error = "Erreur traitement données: $e";
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentCityData == null) return;

    try {
      if (_isFavorite) {
        final favorites = await DatabaseService.instance.getFavorites();
        final favorite = favorites.firstWhere(
          (f) => f.name == _currentCityData!['name'] && 
                 f.country == (_currentCityData!['country'] ?? ''),
        );
        await DatabaseService.instance.deleteFavorite(favorite.id!);
        
        setState(() => _isFavorite = false);
        await _loadFavorites();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retiré des favoris')),
        );
      } else {
        final favoriteCity = FavoriteCity.fromApiData(_currentCityData!);
        await DatabaseService.instance.addFavorite(favoriteCity);
        
        setState(() => _isFavorite = true);
        await _loadFavorites();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajouté aux favoris')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

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

  void _openMapFromWeather(WeatherData w) async {
    try {
      await openGoogleMaps(w.latitude, w.longitude);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible d'ouvrir Maps")),
      );
    }
  }

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
    logger.d('_buildBody: _isLoading=$_isLoading, _error=$_error, _locationWeather=${_locationWeather != null}');
    
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
                color: Colors.white.withValues(alpha:0.9),
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
              color: Colors.white.withValues(alpha:0.7),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.9),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final w = _weather ?? _locationWeather;
    if (w != null) {
      return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _locationWeather != null && _weather == null ? Icons.location_on : Icons.location_city,
                  color: Colors.white.withValues(alpha:0.9),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  w.city,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha:0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_weather != null) ...[  
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _toggleFavorite,
                    child: Icon(
                      _isFavorite ? Icons.star : Icons.star_border,
                      color: _isFavorite ? Colors.amber : Colors.white.withValues(alpha:0.7),
                      size: 24,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
            Icon(
              _getWeatherIcon(w.weatherCode),
              size: 120,
              color: Colors.white.withValues(alpha:0.95),
            ),
            const SizedBox(height: 32),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${w.temperatureC.round()}',
                  style: const TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    '°C',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Text(
              w.description,
              style: TextStyle(
                fontSize: 24,
                color: Colors.white.withValues(alpha:0.9),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 48),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildWeatherInfo(
                    Icons.air,
                    '${w.windKph.toStringAsFixed(1)} km/h',
                    'Vent',
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.white.withValues(alpha:0.3),
                  ),
                  _buildWeatherInfo(
                    Icons.water_drop_outlined,
                    '${w.humidity}%',
                    'Humidité',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _openMapFromWeather(w),
              icon: const Icon(Icons.map),
              label: const Text("Ouvrir dans Google Maps"),
            ),
            
            const SizedBox(height: 40),
            _buildHourlyForecast(),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_searching,
            size: 80,
            color: Colors.white.withValues(alpha:0.7),
          ),
          const SizedBox(height: 24),
          Text(
            'Bienvenue',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w300,
              color: Colors.white.withValues(alpha:0.95),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Appuyez sur le bouton ci-dessous\npour obtenir la météo de votre position',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha:0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _isLoadingLocation ? null : getCurrentLocation,
            icon: _isLoadingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                : const Icon(Icons.gps_fixed, size: 24),
            label: Text(
              _isLoadingLocation ? 'Localisation...' : 'Me localiser',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4A90E2),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _cityController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Rechercher une ville...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.6)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha:0.8)),
              suffixIcon: _cityController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.white.withValues(alpha:0.8)),
                      onPressed: () {
                        _cityController.clear();
                        setState(() {
                          _suggestions = [];
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha:0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.95),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final city = _suggestions[index];
                  return ListTile(
                    leading: const Icon(Icons.location_city, color: Color(0xFF4A90E2)),
                    title: Text(
                      city['name'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${city['country'] ?? ''} ${city['admin1'] ?? ''}'),
                    onTap: () => selectCity(city),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFavoritesBar() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _favorites.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: getCurrentLocation,
              child: Container(
                width: 70,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _locationWeather != null 
                      ? Colors.white.withValues(alpha:0.3)
                      : Colors.white.withValues(alpha:0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha:0.5),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.gps_fixed,
                      color: Colors.white.withValues(alpha:0.9),
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GPS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha:0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          final favorite = _favorites[index - 1];
          final isSelected = _weather != null && 
                            _weather!.city.contains(favorite.name);
          
          return GestureDetector(
            onTap: () {
              final cityData = {
                'name': favorite.name,
                'country': favorite.country,
                'latitude': favorite.latitude,
                'longitude': favorite.longitude,
              };
              selectCity(cityData);
            },
            child: Container(
              width: 70,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Colors.white.withValues(alpha:0.3)
                    : Colors.white.withValues(alpha:0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha:0.5),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_city,
                    color: Colors.white.withValues(alpha:0.9),
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    favorite.name.length > 8 
                        ? '${favorite.name.substring(0, 7)}.'
                        : favorite.name,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha:0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  IconData _getWeatherIcon(int code) {
    switch (code) {
      case 0:
        return Icons.wb_sunny;
      case 1:
      case 2:
      case 3:
        return Icons.wb_cloudy;
      case 45:
      case 48:
        return Icons.foggy;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
        return Icons.water_drop;
      case 71:
      case 73:
      case 75:
        return Icons.ac_unit;
      case 95:
        return Icons.thunderstorm;
      default:
        return Icons.cloud;
    }
  }
  
  Widget _buildWeatherInfo(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withValues(alpha:0.9),
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
            color: Colors.white.withValues(alpha:0.7),
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
                color: Colors.white.withValues(alpha:0.9),
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
                        color: Colors.white.withValues(alpha:0.7),
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
                      
                      final DateTime dateTime = DateTime.parse(timeStr);
                      final hourStr = '${dateTime.hour}h';
                      
                      return Container(
                        width: 70,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha:0.2),
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
                                color: Colors.white.withValues(alpha:0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              _getWeatherIcon(code),
                              color: Colors.white.withValues(alpha:0.9),
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
              color: Colors.white.withValues(alpha:0.9),
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
              color: Colors.white.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.star,
                color: Colors.white.withValues(alpha:0.9),
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(child: _buildBody()),
              if (_favorites.isNotEmpty || _locationWeather != null) 
                _buildFavoritesBar(),
            ],
          ),
        ),
      ),
    );
  }
  
  List<Color> _getGradientColors(int weatherCode) {
    switch (weatherCode) {
      case 0:
        return [const Color(0xFF4A90E2), const Color(0xFF87CEEB)];
      
      case 1:
        return [const Color(0xFF64B5F6), const Color(0xFF90CAF9)];
      
      case 2:
        return [const Color(0xFF78909C), const Color(0xFF90A4AE)];
      
      case 3:
        return [const Color(0xFF607D8B), const Color(0xFF90A4AE)];
      
      case 45:
      case 48:
        return [const Color(0xFF90A4AE), const Color(0xFFCFD8DC)];
      
      case 51:
      case 53:
      case 55:
        return [const Color(0xFF78909C), const Color(0xFF90A4AE)];
      
      case 61:
      case 63:
      case 65:
        return [const Color(0xFF546E7A), const Color(0xFF78909C)];
      
      case 66:
      case 67:
        return [const Color(0xFF607D8B), const Color(0xFF90A4AE)];
      
      case 71:
      case 73:
      case 75:
        return [const Color(0xFF90CAF9), const Color(0xFFBBDEFB)];
      
      case 77:
        return [const Color(0xFFB0BEC5), const Color(0xFFCFD8DC)];
      
      case 80:
      case 81:
      case 82:
        return [const Color(0xFF546E7A), const Color(0xFF607D8B)];
      
      case 85:
      case 86:
        return [const Color(0xFF90A4AE), const Color(0xFFB0BEC5)];
      
      case 95:
      case 96:
      case 99:
        return [const Color(0xFF37474F), const Color(0xFF546E7A)];
      
      default:
        return [const Color(0xFF4A90E2), const Color(0xFF87CEEB)];
    }
  }
}