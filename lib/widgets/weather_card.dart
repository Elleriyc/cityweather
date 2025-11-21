import 'package:flutter/material.dart';
import 'package:cityweather/theme/app_theme.dart';

class WeatherCard extends StatelessWidget {
  final String city;
  final double temperature;
  final String description;
  final int weatherCode;
  final double? humidity;
  final double? windSpeed;
  final double latitude;
  final double longitude;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const WeatherCard({
    super.key,
    required this.city,
    required this.temperature,
    required this.description,
    required this.weatherCode,
    this.humidity,
    this.windSpeed,
    required this.latitude,
    required this.longitude,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: AppTheme.primaryBlue.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.getWeatherColor(weatherCode).withOpacity(0.8),
              AppTheme.getWeatherColor(weatherCode),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec ville et favoris
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          city,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onFavoriteToggle != null)
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.star : Icons.star_border,
                        color: isFavorite ? AppTheme.sunnyYellow : Colors.white,
                        size: 32,
                      ),
                      onPressed: onFavoriteToggle,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Température et icône
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${temperature.round()}',
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '°C',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w300,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    AppTheme.getWeatherIcon(weatherCode),
                    size: 80,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Informations supplémentaires
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (humidity != null)
                      _buildInfoColumn(
                        Icons.water_drop,
                        '${humidity!.round()}%',
                        'Humidité',
                      ),
                    if (windSpeed != null)
                      _buildInfoColumn(
                        Icons.air,
                        '${windSpeed!.toStringAsFixed(1)} km/h',
                        'Vent',
                      ),
                    _buildInfoColumn(
                      Icons.location_on,
                      '${latitude.toStringAsFixed(2)}°',
                      'Latitude',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
