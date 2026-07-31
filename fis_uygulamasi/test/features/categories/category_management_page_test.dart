import 'package:app_main/features/categories/presentation/category_management_page.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('kategori adı, renk ve ikon seçerek yeni kayıt oluşturur', (
    tester,
  ) async {
    String? savedName;
    int? savedColor;
    int? savedIcon;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CategoryManagementPage(
            categories: AsyncValue.data(createDefaultCategoryEntities()),
            addCategory:
                ({
                  required name,
                  required colorValue,
                  required iconCodePoint,
                }) async {
                  savedName = name.trim();
                  savedColor = colorValue;
                  savedIcon = iconCodePoint;
                },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Market'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('new_category_name_field')),
      'Evcil Hayvan',
    );
    await tester.tap(
      find.byKey(Key('category_color_${const Color(0xFF1565C0).toARGB32()}')),
    );
    await tester.tap(
      find.byKey(Key('category_icon_${Icons.pets_outlined.codePoint}')),
    );
    await tester.tap(find.byKey(const Key('save_category_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(savedName, 'Evcil Hayvan');
    expect(savedColor, const Color(0xFF1565C0).toARGB32());
    expect(savedIcon, Icons.pets_outlined.codePoint);
    expect(find.text('Kategori eklendi.'), findsOneWidget);
  });
}
