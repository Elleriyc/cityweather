---
marp: true
theme: default
paginate: true
---

# CityWeather 🌤️
## Application Météo Cross-Platform

**Flutter • SQLite • Open-Meteo API**

Présentation Technique

---

## 📋 Vue d'ensemble

Application météo mobile développée en Flutter permettant :

- ✅ Consultation météo par géolocalisation ou recherche
- ✅ Gestion de villes favorites (persistance SQLite)
- ✅ Prévisions horaires sur 24h
- ✅ Interface moderne et intuitive

---

## 🎯 Fonctionnalité 1 : Villes Favorites

### Persistance avec SQLite

```dart
// Base de données locale avec sqflite
- Stockage de 10 villes maximum
- Données : nom, pays, latitude, longitude
```

**Opérations disponibles :**
- ➕ **Ajout** : Bouton étoile sur la page météo
- 📋 **Liste** : Onglet dédié avec toutes les villes
- 🗑️ **Suppression** : Swipe ou bouton étoile

---

## 🎯 Fonctionnalité 1 : Architecture SQLite

### Schéma de base de données

```sql
CREATE TABLE favorites (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  country TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  UNIQUE(name, country)
)
```

**Validation :**
- Limite de 10 favoris avec feedback utilisateur
- Gestion des doublons (contrainte UNIQUE)
- Messages d'erreur explicites (SnackBar)

---

## 🎯 Fonctionnalité 2 : Recherche de Ville

### API Open-Meteo Geocoding

**Endpoint :** `https://geocoding-api.open-meteo.com/v1/search`

```dart
// Recherche en temps réel
- Suggestions dynamiques dès 2 caractères
- Affichage : Ville, Pays
- Sélection par tap
```

**Expérience utilisateur :**
- 🔍 Barre de recherche interactive
- 📍 Résultats instantanés
- ⚡ Performance optimisée

---

## 🎯 Fonctionnalité 3 : Affichage Météo

### API Open-Meteo Forecast

**Endpoint :** `https://api.open-meteo.com/v1/forecast`

**Données affichées :**
- 🌡️ **Température actuelle** (°C)
- 💧 **Humidité** (%)
- 💨 **Vitesse du vent** (km/h)
- ☁️ **Description météo** + icônes
- 📊 **Prévisions horaires** (24h)

---

## 🎯 Fonctionnalité 3 : Sources de Données

### Double mode d'acquisition

**1. Géolocalisation GPS**
```dart
// Package: geolocator
- Détection automatique de la position
- Météo "Ma position"
- Permissions iOS/Android
```

**2. Recherche manuelle**
```dart
// Recherche par ville
- Geocoding → Coordonnées
- Forecast → Météo complète
```

---

## 🏗️ Architecture Technique

### Stack complet

```
├── Flutter Framework (UI cross-platform)
├── sqflite (Base de données SQLite)
├── http (Requêtes API REST)
├── geolocator (Géolocalisation)
├── url_launcher (Google Maps)
└── logger (Debugging avancé)
```

**Pattern :** Séparation services/UI
- `services/` : API + Database
- `pages/` : Écrans Flutter
- `models/` : Classes de données
- `widgets/` : Composants réutilisables

---

## 📱 Structure de l'Application

### 3 écrans principaux

1. **Accueil** (HomePage)
   - Météo GPS ou recherche
   - Barre de recherche
   - Affichage météo détaillé
   - Prévisions horaires

2. **Favoris** (FavoritesPage)
   - Liste des villes sauvegardées
   - Navigation vers météo de chaque ville
   - Suppression par swipe

3. **Paramètres** (SettingsPage)
   - Configuration de l'application

---

## 🔧 Implémentation : Base de données

### Service DatabaseService

```dart
class DatabaseService {
  // Singleton pattern
  static final DatabaseService instance = DatabaseService._init();
  
  // Opérations CRUD
  Future<void> addFavorite(String name, String country, 
                           double lat, double lon);
  Future<List<Map<String, dynamic>>> getFavorites();
  Future<void> deleteFavorite(String name, String country);
  Future<bool> isFavorite(String name, String country);
  Future<int> getFavoriteCount();
}
```

---

## 🔧 Implémentation : API Service

### Service ApiService

```dart
// Geocoding
Future<List<Map<String, dynamic>>> 
  fetchCitySuggestions(String cityName);

// Météo par coordonnées
Future<Map<String, dynamic>> 
  fetchWeatherFromCoordinates(double lat, double lon);

// Météo par nom de ville
Future<Map<String, dynamic>> 
  fetchData(String cityName);

// Intégration Maps
Future<void> openGoogleMaps(double lat, double lon);
```

---

## 📊 Flux de Données : Recherche

```
1. Utilisateur tape dans la barre de recherche
   ↓
2. fetchCitySuggestions() → API Geocoding
   ↓
3. Affichage liste de suggestions
   ↓
4. Sélection d'une ville
   ↓
5. fetchWeatherFromCoordinates() → API Forecast
   ↓
6. Affichage météo complète + option favori
```

---

## 📊 Flux de Données : Favoris

```
1. Utilisateur clique sur l'étoile
   ↓
2. Vérification: getFavoriteCount() < 10 ?
   ↓
3a. OUI → addFavorite() → SQLite
3b. NON → Message d'erreur
   ↓
4. Mise à jour de l'UI (setState)
   ↓
5. SnackBar de confirmation
```

---

## 🎨 Interface Utilisateur

### Composants clés

**WeatherCard**
- Carte météo avec informations complètes
- Design Material 3
- Animations de transition

**SearchBarWidget**
- Recherche avec suggestions
- Debouncing pour performance
- Liste déroulante interactive

**HourlyForecast**
- Graphique/liste des prévisions
- Affichage sur 24h
- Icônes météo dynamiques

---

## ⚡ Optimisations

### Performance & UX

```dart
// 1. Debouncing sur la recherche
Timer? _debounce;
void _onSearchChanged(String query) {
  _debounce?.cancel();
  _debounce = Timer(Duration(milliseconds: 300), () {
    _fetchSuggestions(query);
  });
}

// 2. Logger pour debugging
logger.d('Données météo reçues');
logger.e('Erreur API: $e');

// 3. Gestion d'état avec mounted
if (!mounted) return;
```

---

## 🔐 Gestion des Permissions

### Géolocalisation

**Android** (`AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

**iOS** (`Info.plist`)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Pour afficher la météo de votre position</string>
```

---

## 🐛 Gestion d'Erreurs

### Robustesse de l'application

```dart
try {
  final weatherData = await fetchWeatherFromCoordinates(lat, lon);
  // Traitement des données
} catch (e) {
  logger.e('Erreur météo: $e');
  setState(() {
    _error = 'Impossible de récupérer la météo';
  });
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Erreur: $e')),
  );
}
```

---

## 📈 Points Forts du Projet

✅ **Architecture propre** : Séparation des responsabilités
✅ **Persistance locale** : SQLite pour données hors-ligne
✅ **API REST** : Intégration Open-Meteo complète
✅ **UX optimisée** : Feedback utilisateur constant
✅ **Code quality** : Logger, gestion d'erreurs, async/await
✅ **Cross-platform** : iOS + Android avec un seul codebase

---

## 🚀 Évolutions Possibles

### Améliorations futures

- 🌍 **Prévisions étendues** : 7 jours au lieu de 24h
- 🔔 **Notifications push** : Alertes météo
- 🎨 **Thèmes** : Mode sombre/clair
- 📍 **Cartes météo** : Visualisation sur carte
- 🌐 **Multilingue** : Internationalisation (i18n)
- ☁️ **Sync cloud** : Firebase pour sync multi-devices

---

## 💡 Défis Techniques Relevés

### Solutions implémentées

1. **Humidité à 0%** 
   - Problème : API retournait `current_weather` au lieu de `current`
   - Solution : Migration vers nouveau format API avec paramètres `current=`

2. **BuildContext async**
   - Problème : Utilisation de context après await
   - Solution : Ajout de `if (!mounted) return;`

3. **Performance recherche**
   - Problème : Trop de requêtes API
   - Solution : Debouncing + minimum 2 caractères

---

## 📝 Code Samples : API Call

```dart
Future<Map<String, dynamic>> fetchWeatherFromCoordinates(
  double latitude, 
  double longitude
) async {
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
  
  return jsonDecode(response.body);
}
```

---

## 📝 Code Samples : SQLite

```dart
Future<void> addFavorite(
  String name, 
  String country, 
  double latitude, 
  double longitude
) async {
  final db = await database;
  
  // Vérifier la limite
  final count = await getFavoriteCount();
  if (count >= 10) {
    throw Exception('Limite de 10 favoris atteinte');
  }
  
  // Insertion
  await db.insert(
    'favorites',
    {
      'name': name,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
```

---

## 🎓 Technologies Apprises

### Compétences développées

- **Flutter** : Widgets, State Management, Navigation
- **Dart** : Async/await, Futures, Streams
- **SQLite** : CRUD, Requêtes SQL, Migrations
- **API REST** : HTTP, JSON parsing, Error handling
- **Mobile** : Permissions, Geolocation, URL Launcher
- **Best Practices** : Clean Code, Logging, Testing

---

## 📞 Démo Live

### Testez l'application !

**Fonctionnalités à démontrer :**

1. 📍 Météo par géolocalisation
2. 🔍 Recherche de ville (ex: "Paris")
3. ⭐ Ajout aux favoris
4. 📋 Consultation de la liste des favoris
5. 🗑️ Suppression d'un favori
6. 🗺️ Ouverture dans Google Maps

---

## 🙏 Merci !

### Questions ?

**Projet CityWeather**
Flutter • SQLite • Open-Meteo API

---
Repository: github.com/Elleriyc/cityweather
Branch: dev

**Technologies utilisées :**
Flutter 3.x | Dart | SQLite (sqflite) | Open-Meteo API | Geolocator | Logger
