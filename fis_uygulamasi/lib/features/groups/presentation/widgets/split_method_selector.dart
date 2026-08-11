import 'package:flutter/material.dart';

import '../../domain/group_models.dart';

class SplitMethodSelector extends StatelessWidget {
  const SplitMethodSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final SplitType value;
  final ValueChanged<SplitType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SplitType>(
      key: const Key('split_method_selector'),
      segments: const [
        ButtonSegment(value: SplitType.equal, label: Text('Eşit böl')),
        ButtonSegment(value: SplitType.percentage, label: Text('Yüzdelik böl')),
        ButtonSegment(
          value: SplitType.fixedAmount,
          label: Text('Tutar bazlı böl'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.single),
      showSelectedIcon: false,
    );
  }
}
