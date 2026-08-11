import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/group_list_controller.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _currency = 'TRY';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final controller = ref.read(groupListControllerProvider.notifier);
    try {
      final group = await controller.createGroup(
        name: _nameController.text,
        description: _descriptionController.text,
        currency: _currency,
      );
      if (mounted && group != null) context.pop();
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grup oluşturulamadı. Tekrar deneyin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(
      groupListControllerProvider.select((state) => state.isSubmitting),
    );
    return Scaffold(
      key: const Key('create_group_page'),
      appBar: AppBar(title: const Text('Yeni Grup Oluştur')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                key: const Key('group_name_field'),
                controller: _nameController,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Grup adı',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Grup adı boş bırakılamaz.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('group_description_field'),
                controller: _descriptionController,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('group_currency_field'),
                initialValue: _currency,
                decoration: const InputDecoration(
                  labelText: 'Para birimi',
                  prefixIcon: Icon(Icons.currency_lira_rounded),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'TRY',
                    child: Text('TRY - Türk Lirası'),
                  ),
                ],
                onChanged: submitting
                    ? null
                    : (value) => setState(() => _currency = value ?? 'TRY'),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: submitting ? null : context.pop,
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('submit_group_button'),
                      onPressed: submitting ? null : _submit,
                      child: submitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Grup oluştur'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
