import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/inventory_provider.dart';
import '../providers/settings_provider.dart';
import '../models/item.dart';
import '../services/pdf_service.dart';
import '../services/zip_service.dart';
import '../services/export_service.dart';

import 'add_item_screen.dart';
import 'item_detail_screen.dart';
import 'settings_screen.dart';
import 'fast_add_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  bool _showActions = true;

  // --- SELECTION STATE ---
  final Set<int> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (_showActions) setState(() => _showActions = false);
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_showActions) setState(() => _showActions = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- SELECTION HELPERS ---

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  Future<void> _confirmBatchDelete() async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final count = _selectedIds.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete $count items?"),
        content: const Text("This will permanently remove these items and all associated photos."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (var id in _selectedIds) {
        await provider.deleteItem(id);
      }
      _clearSelection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully deleted $count items")),
        );
      }
    }
  }

  // --- SMART SEARCH HIGHLIGHTER ---

  Widget _buildHighlightedText(String fullText, String query, TextStyle baseStyle) {
    if (query.isEmpty || !fullText.toLowerCase().contains(query.toLowerCase())) {
      return Text(fullText, style: baseStyle, overflow: TextOverflow.ellipsis);
    }

    final String searchLower = query.toLowerCase();
    final String textLower = fullText.toLowerCase();
    final List<TextSpan> spans = [];

    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = textLower.indexOf(searchLower, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: fullText.substring(start, indexOfMatch)));
      }

      spans.add(TextSpan(
        text: fullText.substring(indexOfMatch, indexOfMatch + query.length),
        style: TextStyle(
          backgroundColor: Colors.yellow.withOpacity(0.5),
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = indexOfMatch + query.length;
    }

    if (start < fullText.length) {
      spans.add(TextSpan(text: fullText.substring(start)));
    }

    return RichText(
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  // --- UI COMPONENTS ---

  void _showExportMenu(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Export Inventory", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildExportTile(ctx, "Insurance PDF Report", Icons.picture_as_pdf, const Color(0xFFB71C1C),
                      () => PdfService.generateInventoryReport(provider.items, settings)),
              _buildExportTile(ctx, "CSV Spreadsheet", Icons.table_chart, const Color(0xFF2E7D32),
                      () => ExportService.shareAsCsv(provider.items)),
              _buildExportTile(ctx, "Full ZIP Backup", Icons.folder_zip, const Color(0xFF455A64), () {
                final allImages = provider.items.expand((item) => item.imagePaths).toList();
                ZipService.createFullBackup(allImages);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportTile(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  PreferredSizeWidget _buildAppBar(InventoryProvider provider, ThemeData theme) {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        ),
        title: Text("${_selectedIds.length} Selected",
            style: TextStyle(color: theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmBatchDelete,
          ),
        ],
      );
    }

    return AppBar(
      elevation: 0,
      title: _isSearching
          ? TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Search items, brands, rooms...', border: InputBorder.none),
        onChanged: (val) => provider.setSearchQuery(val),
      )
          : const Text('My Inventory', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                provider.setSearchQuery('');
              }
            });
          },
        ),
        if (!_isSearching)
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (option) => provider.setSort(option),
            itemBuilder: (context) => [
              const PopupMenuItem(value: SortOption.name, child: Text("Sort by Name")),
              const PopupMenuItem(value: SortOption.value, child: Text("Sort by Value")),
              const PopupMenuItem(value: SortOption.date, child: Text("Sort by Date")),
            ],
          ),
        if (!_isSearching)
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => _showExportMenu(context),
          ),
        if (!_isSearching)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen())),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _buildAppBar(provider, theme),
      body: Stack(
        children: [
          Column(
            children: [
              if (!_isSearching && provider.items.isNotEmpty && !_isSelectionMode)
                _buildTotalValueBanner(theme, provider.totalValue),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildItemList(provider, theme),
              ),
            ],
          ),
          if (!_isSelectionMode) _buildActionDock(theme),
        ],
      ),
    );
  }

  Widget _buildTotalValueBanner(ThemeData theme, double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("ESTIMATED TOTAL ASSETS",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 0.5)),
          Text(
            NumberFormat.simpleCurrency().format(total),
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(InventoryProvider provider, ThemeData theme) {
    final displayItems = provider.filteredItems;
    final query = provider.searchQuery.toLowerCase();

    if (displayItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(_isSearching ? 'No matches found.' : 'Inventory is empty.', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: displayItems.length + 1, // +1 for the sort label
      padding: EdgeInsets.fromLTRB(0, 8, 0, _isSelectionMode ? 20 : 120),
      itemBuilder: (context, index) {
        // --- 1. SORT LABEL (First Item) ---
        if (index == 0) {
          String sortText = "Sorted by Name";
          if (provider.currentSort == SortOption.value) sortText = "Sorted by Highest Value";
          if (provider.currentSort == SortOption.date) sortText = "Sorted by Newest First";

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(sortText.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.0)),
          );
        }

        final item = displayItems[index - 1];
        final bool incomplete = item.value == 0 || item.room == null;
        final isSelected = _selectedIds.contains(item.id);

        String subtitleText = "${item.room ?? 'Unassigned'} • ${item.category ?? 'General'}";

        if (query.isNotEmpty) {
          if (item.brand?.toLowerCase().contains(query) ?? false) {
            subtitleText = "Brand: ${item.brand} • $subtitleText";
          } else if (item.model?.toLowerCase().contains(query) ?? false) {
            subtitleText = "Model: ${item.model} • $subtitleText";
          } else if (item.serialNumber?.toLowerCase().contains(query) ?? false) {
            subtitleText = "S/N: ${item.serialNumber} • $subtitleText";
          }
        }

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.3) : Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                onLongPress: () => _toggleSelection(item.id!),
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleSelection(item.id!);
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => ItemDetailScreen(itemId: item.id!)));
                  }
                },
                leading: Stack(
                  children: [
                    Container(
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.surfaceVariant,
                        image: item.imagePaths.isNotEmpty
                            ? DecorationImage(image: FileImage(File(item.imagePaths[0])), fit: BoxFit.cover)
                            : null,
                      ),
                      child: item.imagePaths.isEmpty ? const Icon(Icons.image_outlined, color: Colors.grey) : null,
                    ),
                    if (isSelected)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.primary.withOpacity(0.4),
                          ),
                          child: const Icon(Icons.check, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                title: _buildHighlightedText(
                    item.name,
                    provider.searchQuery,
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: theme.colorScheme.onSurface)
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildHighlightedText(
                          subtitleText,
                          provider.searchQuery,
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                      if (incomplete) _buildIncompleteBadge(),
                    ],
                  ),
                ),
                trailing: _isSelectionMode
                    ? Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(item.id!),
                  shape: const CircleBorder(),
                )
                    : Text(
                  NumberFormat.simpleCurrency(decimalDigits: 0).format(item.value),
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
              ),
            ),
            const Divider(height: 1, indent: 86),
          ],
        );
      },
    );
  }

  Widget _buildActionDock(ThemeData theme) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      bottom: _showActions ? 0 : -140,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FastAddScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text("FAST ADD", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddItemScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text("FULL ENTRY", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncompleteBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: const Text("!", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}