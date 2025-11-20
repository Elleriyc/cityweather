import 'package:flutter/material.dart';
import '../services/database_service.dart';

class FavoritesPage extends StatefulWidget {
  final Function(Map<String, dynamic>) onCitySelected;

  const FavoritesPage({super.key, required this.onCitySelected});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<FavoriteCity> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final favorites = await DatabaseService.instance.getFavorites();
      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement favoris: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFavorite(FavoriteCity city) async {
    try {
      await DatabaseService.instance.deleteFavorite(city.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${city.name} supprimé des favoris')),
      );
      _loadFavorites();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _selectCity(FavoriteCity city) {
    // Convertir en format API
    final cityData = {
      'name': city.name,
      'country': city.country,
      'latitude': city.latitude,
      'longitude': city.longitude,
      'admin1': city.admin1,
    };
    
    widget.onCitySelected(cityData);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Villes favorites'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_border, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Aucune ville favorite',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ajoutez une ville en favoris depuis la recherche',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '${_favorites.length}/10 villes favorites',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _favorites.length,
                        itemBuilder: (context, index) {
                          final city = _favorites[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.star,
                                color: Colors.amber,
                              ),
                              title: Text(city.name),
                              subtitle: Text(
                                [city.admin1, city.country]
                                    .where((s) => s != null && s.isNotEmpty)
                                    .join(', '),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteFavorite(city),
                              ),
                              onTap: () => _selectCity(city),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
