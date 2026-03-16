import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daeddong/data/models/toilet_model.dart';
import 'package:daeddong/data/repositories/toilet_repository.dart';

// ────────────────────── FilterState ────────────────────────────────

class FilterState {
  final bool isAlwaysOpen;
  final bool hasBaby;
  final bool hasDisabled;
  final bool hasCctv;
  final bool hasAlarm;
  final String? toiletType; // null = 전체, '공중화장실', '개방화장실'
  final bool isOperatingNow;

  const FilterState({
    this.isAlwaysOpen = false,
    this.hasBaby = false,
    this.hasDisabled = false,
    this.hasCctv = false,
    this.hasAlarm = false,
    this.toiletType,
    this.isOperatingNow = false,
  });

  bool get hasAnyFilter =>
      isAlwaysOpen ||
      hasBaby ||
      hasDisabled ||
      hasCctv ||
      hasAlarm ||
      toiletType != null ||
      isOperatingNow;

  FilterState copyWith({
    bool? isAlwaysOpen,
    bool? hasBaby,
    bool? hasDisabled,
    bool? hasCctv,
    bool? hasAlarm,
    String? toiletType,
    bool? isOperatingNow,
    bool clearToiletType = false,
  }) {
    return FilterState(
      isAlwaysOpen: isAlwaysOpen ?? this.isAlwaysOpen,
      hasBaby: hasBaby ?? this.hasBaby,
      hasDisabled: hasDisabled ?? this.hasDisabled,
      hasCctv: hasCctv ?? this.hasCctv,
      hasAlarm: hasAlarm ?? this.hasAlarm,
      toiletType: clearToiletType ? null : (toiletType ?? this.toiletType),
      isOperatingNow: isOperatingNow ?? this.isOperatingNow,
    );
  }
}

// ────────────────────── MapState ───────────────────────────────────

class MapState {
  final List<ToiletModel> toiletList;
  final List<ToiletModel> filteredToiletList;
  final bool isLoading;
  final String? error;
  final ToiletModel? selectedToilet;
  final FilterState filterState;

  const MapState({
    this.toiletList = const [],
    this.filteredToiletList = const [],
    this.isLoading = false,
    this.error,
    this.selectedToilet,
    this.filterState = const FilterState(),
  });

  MapState copyWith({
    List<ToiletModel>? toiletList,
    List<ToiletModel>? filteredToiletList,
    bool? isLoading,
    String? error,
    ToiletModel? selectedToilet,
    FilterState? filterState,
    bool clearError = false,
    bool clearSelectedToilet = false,
  }) {
    return MapState(
      toiletList: toiletList ?? this.toiletList,
      filteredToiletList: filteredToiletList ?? this.filteredToiletList,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedToilet:
          clearSelectedToilet ? null : (selectedToilet ?? this.selectedToilet),
      filterState: filterState ?? this.filterState,
    );
  }
}

// ────────────────────── MapNotifier ────────────────────────────────

class MapNotifier extends StateNotifier<MapState> {
  final ToiletRepository _repository;

  MapNotifier(this._repository) : super(const MapState());

  Future<void> loadToilets(double lat, double lng, double distance) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _repository.getToiletList(
        latitude: lat,
        longitude: lng,
        distance: distance,
      );
      final filtered = _applyFilterToList(list, state.filterState);
      state = state.copyWith(
        toiletList: list,
        filteredToiletList: filtered,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[MapProvider] loadToilets 오류: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void applyFilter(FilterState filterState) {
    final filtered = _applyFilterToList(state.toiletList, filterState);
    state = state.copyWith(
      filterState: filterState,
      filteredToiletList: filtered,
    );
  }

  void selectToilet(ToiletModel toilet) {
    state = state.copyWith(selectedToilet: toilet);
  }

  void clearSelection() {
    state = state.copyWith(clearSelectedToilet: true);
  }

  // ──────────────── 필터 적용 로직 ────────────────────────────────

  List<ToiletModel> _applyFilterToList(
      List<ToiletModel> list, FilterState filter) {
    if (!filter.hasAnyFilter) return list;
    return list.where((t) {
      if (filter.isAlwaysOpen && !_isAlwaysOpen(t)) return false;
      if (filter.hasBaby && t.babyYn != 'Y') return false;
      if (filter.hasDisabled && t.unusualYn != 'Y') return false;
      if (filter.hasCctv && t.cctvYn != 'Y') return false;
      if (filter.hasAlarm && t.alarmYn != 'Y') return false;
      if (filter.toiletType != null && t.toiletType != filter.toiletType) {
        return false;
      }
      if (filter.isOperatingNow && !_isOperatingNow(t)) return false;
      return true;
    }).toList();
  }

  bool _isAlwaysOpen(ToiletModel t) {
    if (t.openTime == '상시') return true;
    if (t.openTime == '00:00' &&
        (t.closeTime == '00:00' || t.closeTime == '24:00')) {
      return true;
    }
    return false;
  }

  bool _isOperatingNow(ToiletModel t) {
    if (t.openYn == 'Y') return true;
    if (t.openTime == '상시') return true;

    final open = _parseMinutes(t.openTime);
    final close = _parseMinutes(t.closeTime);
    if (open == null || close == null) return false;

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;

    if (open == 0 && close == 0) return true; // 00:00~00:00 = 24시간

    if (close > open) {
      return nowMin >= open && nowMin < close;
    } else {
      return nowMin >= open || nowMin < close;
    }
  }

  int? _parseMinutes(String? timeStr) {
    if (timeStr == null) return null;
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (hour == 24) return 0;
      return hour * 60 + minute;
    } catch (_) {
      return null;
    }
  }
}

// ──────────────────── Providers ────────────────────────────────────

final toiletRepositoryProvider = Provider((ref) => ToiletRepository());

final mapProvider = StateNotifierProvider<MapNotifier, MapState>(
  (ref) => MapNotifier(ref.watch(toiletRepositoryProvider)),
);
