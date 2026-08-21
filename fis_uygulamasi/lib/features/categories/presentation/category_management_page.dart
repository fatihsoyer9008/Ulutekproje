import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';

const categoryColors = <Color>[
  Color(0xFF2E7D32),
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFFEF6C00),
  Color(0xFFC62828),
  Color(0xFFAD1457),
  Color(0xFF00838F),
  Color(0xFF546E7A),
];

const categoryIcons = <IconData>[
  Icons.shopping_cart_outlined,
  Icons.directions_bus_outlined,
  Icons.receipt_long_outlined,
  Icons.celebration_outlined,
  Icons.health_and_safety_outlined,
  Icons.checkroom_outlined,
  Icons.restaurant_outlined,
  Icons.category_outlined,
  Icons.school_outlined,
  Icons.pets_outlined,
  Icons.home_outlined,
  Icons.flight_outlined,
];

IconData categoryIconFromCodePoint(int codePoint) {
  return categoryIcons.firstWhere(
    (icon) => icon.codePoint == codePoint,
    orElse: () => Icons.category_outlined,
  );
}

class CategoryManagementPage extends ConsumerStatefulWidget {
  const CategoryManagementPage({super.key, this.categories, this.addCategory});

  final AsyncValue<List<CategoryEntity>>? categories;
  final Future<void> Function({
    required String name,
    required int colorValue,
    required int iconCodePoint,
  })?
  addCategory;

  @override
  ConsumerState<CategoryManagementPage> createState() =>
      _CategoryManagementPageState();
}

class _CategoryManagementPageState
    extends ConsumerState<CategoryManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  Color _selectedColor = categoryColors.first;
  IconData _selectedIcon = categoryIcons.first;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final addCategory =
          widget.addCategory ??
          ref.read(categoryRepositoryProvider).addCategory;
      await addCategory(
        name: _nameController.text,
        colorValue: _selectedColor.toARGB32(),
        iconCodePoint: _selectedIcon.codePoint,
      );
      _nameController.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kategori eklendi.')));
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CategoryEntity>> categories =
        widget.categories ?? ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kategoriler')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yeni kategori',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('new_category_name_field'),
                    controller: _nameController,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Kategori Adı',
                      prefixIcon: Icon(Icons.edit_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Kategori adı zorunludur.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text('Renk', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final color in categoryColors)
                        _ColorChoice(
                          color: color,
                          selected: color == _selectedColor,
                          onSelected: () =>
                              setState(() => _selectedColor = color),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('İkon', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final icon in categoryIcons)
                        _IconChoice(
                          icon: icon,
                          color: _selectedColor,
                          selected: icon == _selectedIcon,
                          onSelected: () =>
                              setState(() => _selectedIcon = icon),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('save_category_button'),
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Kategori Ekle'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Kayıtlı kategoriler',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          categories.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Text('Kategoriler şu anda görüntülenemiyor.'),
            data: (items) => Column(
              children: [
                for (final category in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Color(
                              category.colorValue,
                            ).withValues(alpha: .14),
                            child: Icon(
                              categoryIconFromCodePoint(category.iconCodePoint),
                              color: Color(category.colorValue),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(category.name)),
                          if (category.isDefault)
                            const Text(
                              'Varsayılan',
                              style: TextStyle(color: AppColors.muted),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final Color color;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Kategori rengi',
    child: InkWell(
      key: Key('category_color_${color.toARGB32()}'),
      onTap: onSelected,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Colors.black, width: 3) : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    ),
  );
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => IconButton(
    key: Key('category_icon_${icon.codePoint}'),
    tooltip: 'Kategori ikonu',
    onPressed: onSelected,
    color: selected ? Colors.white : color,
    style: IconButton.styleFrom(
      backgroundColor: selected ? color : color.withValues(alpha: .12),
      side: selected ? BorderSide(color: color, width: 2) : null,
    ),
    icon: Icon(icon),
  );
}
