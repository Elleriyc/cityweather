# cityweather

Application météo Flutter avec recherche de villes et gestion de favoris.

## Fonctionnalités

### 🔍 Recherche de villes
- Suggestions en temps réel dès la première lettre tapée
- Affichage du nom de la ville, région et pays
- Sélection rapide depuis les suggestions

### 🌤️ Affichage météo
- Température actuelle (arrondie à l'entier le plus proche)
- Description des conditions météo
- Vitesse du vent
- Humidité (si disponible)
- Coordonnées GPS de la ville

### ⭐ Villes favorites (SQLite)
- **Ajouter** jusqu'à 10 villes en favoris
- **Afficher** la liste des villes favorites
- **Supprimer** un favori
- **Accès rapide** à la météo d'une ville favorite
- Persistance des données avec SQLite

## APIs utilisées

- **Geocoding API** : `https://geocoding-api.open-meteo.com/v1/search`
- **Weather API** : `https://api.open-meteo.com/v1/forecast`

## Installation

```bash
flutter pub get
flutter run
```

## Structure du projet

```
lib/
├── main.dart                      # Point d'entrée
├── pages/
│   ├── accueil.dart              # Page principale
│   └── favorites_page.dart       # Page des favoris
└── services/
    ├── api_service.dart          # Appels API météo
    └── database_service.dart     # Gestion SQLite
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
