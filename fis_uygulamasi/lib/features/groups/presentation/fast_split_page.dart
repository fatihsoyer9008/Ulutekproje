import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../transaction_draft/model/turkish_money.dart';
import '../application/fast_split_calculator.dart';
import '../data/group_api_failure.dart';
import '../domain/group_models.dart';
import 'itemized_split_page.dart';

typedef FastSplitSubmit = Future<void> Function(FastSplitFormValue value);

class FastSplitFormValue {
  const FastSplitFormValue({
    required this.title,
    required this.payerUserId,
    required this.calculation,
    required this.percentageBasisPoints,
  });

  final String title;
  final String payerUserId;
  final FastSplitCalculation calculation;
  final Map<String, int> percentageBasisPoints;
}

class FastSplitPage extends StatefulWidget {
  const FastSplitPage({
    required this.group,
    required this.currentUserId,
    required this.onSubmit,
    this.itemizedReceipt,
    this.onItemizedSubmit,
    super.key,
  });

  final GroupDetail group;
  final String currentUserId;
  final FastSplitSubmit onSubmit;
  final ItemizedSplitReceipt? itemizedReceipt;
  final ItemizedSplitSubmit? onItemizedSubmit;

  @override
  State<FastSplitPage> createState() => _FastSplitPageState();
}

class _FastSplitPageState extends State<FastSplitPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _totalController = TextEditingController();
  final Map<String, TextEditingController> _percentageControllers = {};
  final Map<String, TextEditingController> _fixedAmountControllers = {};
  late final Set<String> _selectedMemberIds;
  String? _payerUserId;
  SplitType _splitType = SplitType.equal;
  bool _submitting = false;

  List<GroupMember> get _activeMembers => widget.group.members
      .where((member) => member.leftAt == null)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _selectedMemberIds = _activeMembers.map((member) => member.userId).toSet();
    _payerUserId = _activeMembers.any((m) => m.userId == widget.currentUserId)
        ? widget.currentUserId
        : (_activeMembers.isEmpty ? null : _activeMembers.first.userId);
    for (final member in _activeMembers) {
      _percentageControllers[member.userId] = TextEditingController();
      _fixedAmountControllers[member.userId] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    for (final controller in [
      ..._percentageControllers.values,
      ..._fixedAmountControllers.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hızlı Bölüştürme')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.group.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('fast_split_title'),
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Harcama adı',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Harcama adı girin.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('fast_split_total'),
                controller: _totalController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Toplam tutar',
                  prefixText: '₺ ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final amount = parseTurkishLiraToMinor(value);
                  return amount == null || amount <= 0
                      ? 'Geçerli bir tutar girin.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('fast_split_payer'),
                initialValue: _payerUserId,
                decoration: const InputDecoration(
                  labelText: 'Kim ödedi?',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final member in _activeMembers)
                    DropdownMenuItem(
                      value: member.userId,
                      child: Text(member.displayName),
                    ),
                ],
                onChanged: (value) => setState(() => _payerUserId = value),
              ),
              const SizedBox(height: 20),
              SegmentedButton<SplitType>(
                segments: const [
                  ButtonSegment(value: SplitType.equal, label: Text('Eşit')),
                  ButtonSegment(
                    value: SplitType.percentage,
                    label: Text('Yüzde'),
                  ),
                  ButtonSegment(
                    value: SplitType.fixedAmount,
                    label: Text('Tutar'),
                  ),
                ],
                selected: {_splitType},
                onSelectionChanged: (selection) => setState(() {
                  _splitType = selection.single;
                  _seedPercentageValues();
                }),
              ),
              const SizedBox(height: 20),
              Text(
                'Katılımcılar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              for (final member in _activeMembers) _memberRow(member),
              if (_calculation case final calculation?) ...[
                const SizedBox(height: 12),
                _BalanceCard(calculation: calculation),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('fast_split_submit'),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Harcamayı Kaydet'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('open_itemized_split'),
                onPressed: _openItemizedSplit,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Kalem Bazlı Bölüştür'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberRow(GroupMember member) {
    final selected = _selectedMemberIds.contains(member.userId);
    return Card(
      child: Row(
        children: [
          Checkbox(
            key: Key('participant_${member.userId}'),
            value: selected,
            onChanged: (value) => setState(() {
              if (value ?? false) {
                _selectedMemberIds.add(member.userId);
              } else {
                _selectedMemberIds.remove(member.userId);
              }
              _seedPercentageValues(force: true);
            }),
          ),
          Expanded(child: Text(member.displayName)),
          if (selected && _splitType != SplitType.equal)
            SizedBox(
              width: 112,
              child: TextFormField(
                key: Key('share_${member.userId}'),
                controller: _controllerFor(member.userId),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                textAlign: TextAlign.end,
                decoration: InputDecoration(
                  suffixText: _splitType == SplitType.percentage ? '%' : '₺',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  List<String> get _orderedSelectedIds => [
    for (final member in _activeMembers)
      if (_selectedMemberIds.contains(member.userId)) member.userId,
  ];

  FastSplitCalculation? get _calculation {
    final total = parseTurkishLiraToMinor(_totalController.text);
    if (total == null || total <= 0 || _orderedSelectedIds.isEmpty) return null;
    try {
      return switch (_splitType) {
        SplitType.equal => FastSplitCalculator.equal(
          totalAmountInMinor: total,
          memberIds: _orderedSelectedIds,
        ),
        SplitType.percentage => FastSplitCalculator.percentage(
          totalAmountInMinor: total,
          memberIds: _orderedSelectedIds,
          percentageBasisPoints: _percentageBasisPoints,
        ),
        SplitType.fixedAmount => FastSplitCalculator.fixedAmount(
          totalAmountInMinor: total,
          memberIds: _orderedSelectedIds,
          amountsInMinor: _fixedAmounts,
        ),
        SplitType.itemized => throw const FormatException(),
      };
    } on FormatException {
      if (_splitType == SplitType.percentage) {
        return FastSplitCalculation(
          type: _splitType,
          totalAmountInMinor: total,
          shares: const [],
        );
      }
      return null;
    }
  }

  Map<String, int> get _percentageBasisPoints => {
    for (final id in _orderedSelectedIds)
      id: _parseDecimalToHundredths(_percentageControllers[id]!.text) ?? 0,
  };

  Map<String, int> get _fixedAmounts => {
    for (final id in _orderedSelectedIds)
      id: parseTurkishLiraToMinor(_fixedAmountControllers[id]!.text) ?? 0,
  };

  TextEditingController _controllerFor(String userId) =>
      _splitType == SplitType.percentage
      ? _percentageControllers[userId]!
      : _fixedAmountControllers[userId]!;

  int? _parseDecimalToHundredths(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
    if (match == null) return null;
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    return int.parse(match.group(1)!) * 100 +
        (fraction.isEmpty ? 0 : int.parse(fraction));
  }

  void _seedPercentageValues({bool force = false}) {
    if (_splitType != SplitType.percentage || _orderedSelectedIds.isEmpty) {
      return;
    }
    if (!force &&
        _orderedSelectedIds.any(
          (id) => _percentageControllers[id]!.text.isNotEmpty,
        )) {
      return;
    }
    final base = 10000 ~/ _orderedSelectedIds.length;
    var remainder = 10000.remainder(_orderedSelectedIds.length);
    for (final id in _orderedSelectedIds) {
      final points = base + (remainder-- > 0 ? 1 : 0);
      _percentageControllers[id]!.text = points % 100 == 0
          ? '${points ~/ 100}'
          : (points / 100).toStringAsFixed(2);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_orderedSelectedIds.isEmpty) {
      _showError('En az bir katılımcı seçin.');
      return;
    }
    if (_payerUserId == null) {
      _showError('Ödeyen bir grup üyesi seçin.');
      return;
    }
    final calculation = _calculation;
    if (calculation == null || !calculation.isBalanced) {
      _showError(
        _splitType == SplitType.percentage
            ? 'Yüzdelerin toplamı %100 olmalıdır.'
            : 'Pay toplamı ana tutarla eşleşmelidir.',
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        FastSplitFormValue(
          title: _titleController.text.trim(),
          payerUserId: _payerUserId!,
          calculation: calculation,
          percentageBasisPoints: _percentageBasisPoints,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        _showError(
          groupUserMessage(
            error,
            fallbackMessage: 'Harcama kaydedilemedi. Lütfen tekrar deneyin.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openItemizedSplit() async {
    final receipt = widget.itemizedReceipt;
    if (receipt == null || receipt.lineItems.isEmpty) {
      _showError(
        'Kalem bazlı bölüşüm için ürünleri buluta eşitlenmiş bir fiş gerekir. '
        'Eşit, yüzde veya tutar bölüşümünü kullanabilirsiniz.',
      );
      return;
    }
    if (!receipt.isCloudSynced || widget.onItemizedSubmit == null) {
      _showError(
        'Fiş veya ürünler henüz buluta eşitlenmedi. '
        'Eşit, yüzde veya tutar bölüşümünü kullanabilirsiniz.',
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ItemizedSplitPage(
          group: widget.group,
          currentUserId: widget.currentUserId,
          receipt: receipt,
          initialTitle: _titleController.text.trim(),
          onSubmit: widget.onItemizedSubmit!,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.calculation});

  final FastSplitCalculation calculation;

  @override
  Widget build(BuildContext context) {
    final difference = calculation.differenceInMinor;
    final balanced = calculation.isBalanced;
    return Card(
      color: balanced
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              balanced
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_rounded,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                balanced
                    ? 'Pay toplamı ana tutarla eşleşiyor.'
                    : '${difference.abs().toTLDisplay} ${difference > 0 ? 'eksik' : 'fazla'} paylaştırıldı.',
                key: const Key('fast_split_balance_message'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
