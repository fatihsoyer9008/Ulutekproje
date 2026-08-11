import 'package:flutter/material.dart';

import '../../domain/group_models.dart';

class MemberCard extends StatelessWidget {
  const MemberCard({required this.member, super.key});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final role = switch (member.role) {
      GroupRole.owner => 'Sahip',
      GroupRole.admin => 'Yönetici',
      GroupRole.member => 'Üye',
    };
    final active = member.leftAt == null;
    return Semantics(
      label: '${member.displayName}, $role, ${active ? 'aktif' : 'ayrılmış'}',
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            child: Text(
              member.displayName.trim().substring(0, 1).toUpperCase(),
            ),
          ),
          title: Text(member.displayName),
          subtitle: Text(active ? 'Aktif üye' : 'Gruptan ayrıldı'),
          trailing: Chip(label: Text(role)),
        ),
      ),
    );
  }
}
