import 'dart:async';
import 'package:flutter/material.dart';
import '../models/item.dart';
import '../repositories/inventory_repository.dart';
import '../services/logger_service.dart';

enum SortOption { name, value, date }

class InventoryProvider with ChangeNotifier {
  final InventoryRepository _repository = InventoryRepository();

  // --- STATE ---
  List<Item> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Search Debounce
  Timer? _debounce;
  String _searchQuery = '';

  SortOption _currentSort = SortOption.name;
  int _currentPage = 0;
  static const int _pageSize = 20;
  double _totalValue = 0.0;

  // --- GETTERS ---
  List<Item> get items => _items;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String get searchQuery => _searchQuery;
  SortOption get currentSort => _currentSort;
  double get totalValue => _totalValue;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // --- INITIALIZATION ---

  Future<void> initializeData() async {
    _isLoading = true;
    notifyListeners();
    await _resetAndReload();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _resetAndReload() async {
    _currentPage = 0;
    _hasMoreData = true;
    _items.clear();
    await _performQuery();
    await _refreshStats();
  }

  Future<void> _refreshStats() async {
    _totalValue = await _repository.getTotalValue();
  }

  // --- QUERY LOGIC ---

  Future<void> loadNextPage() async {
    if (_isLoadingMore || !_hasMoreData) return;
    _isLoadingMore = true;
    notifyListeners();

    _currentPage++;
    await _performQuery(isLoadMore: true);

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> _performQuery({bool isLoadMore = false}) async {
    try {
      final newItems = await _repository.getItems(
        query: _searchQuery,
        sortOption: _currentSort,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      if (newItems.length < _pageSize) {
        _hasMoreData = false;
      }

      if (isLoadMore) {
        _items.addAll(newItems);
      } else {
        _items = newItems;
      }
    } catch (e) {
      logger.log("Provider: Query failed", error: e);
    }
  }

  // --- ACTIONS ---

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _resetAndReload().then((_) => notifyListeners());
    });
  }

  void setSort(SortOption option) {
    if (_currentSort == option) return;
    _currentSort = option;
    _resetAndReload().then((_) => notifyListeners());
  }

  Future<void> addItem(Item item) async {
    await _repository.createItem(item);
    await _resetAndReload();
    notifyListeners();
  }

  Future<void> updateItem(Item item) async {
    await _repository.updateItem(item);
    await _resetAndReload();
    notifyListeners();
  }

  Future<void> deleteItem(int id) async {
    try {
      // 1. Delegate strictly to Repository for safe deletion
      await _repository.deleteItem(id);

      // 2. Update UI State immediately (Optimistic removal)
      _items.removeWhere((i) => i.id == id);
      await _refreshStats();
      notifyListeners();

    } catch (e) {
      logger.log("Provider: Failed to delete item $id", error: e);
      // Optional: Show snackbar trigger via a stream or callback here
    }
  }

  Future<void> clearAll() async {
    await _repository.clearAllItems();
    _items.clear();
    _totalValue = 0.0;
    _currentPage = 0;
    notifyListeners();
  }
}