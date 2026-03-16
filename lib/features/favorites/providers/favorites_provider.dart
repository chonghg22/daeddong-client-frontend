import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daeddong/data/models/toilet_model.dart';

class FavoritesNotifier extends StateNotifier<List<ToiletModel>> {
  static const _key = 'favorites_json';

  FavoritesNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    await loadFavorites();
  }

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    state = jsonList
        .map((e) =>
            ToiletModel.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> addFavorite(ToiletModel toilet) async {
    if (isFavorite(toilet.seq)) return;
    final updated = [...state, toilet];
    await _save(updated);
    state = updated;
  }

  Future<void> removeFavorite(int seq) async {
    final updated = state.where((t) => t.seq != seq).toList();
    await _save(updated);
    state = updated;
  }

  bool isFavorite(int? seq) {
    if (seq == null) return false;
    return state.any((t) => t.seq == seq);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = [];
  }

  Future<void> _save(List<ToiletModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      list.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<ToiletModel>>(
  (ref) => FavoritesNotifier(),
);
