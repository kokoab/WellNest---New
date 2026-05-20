import 'package:flutter/material.dart';

typedef DiscoverRankBadge = ({
  Color bgColor,
  Color fgColor,
  IconData icon,
  String label,
});

DiscoverRankBadge discoverRankBadgeStyle(int rank) {
  if (rank == 1) {
    return (
      bgColor: const Color(0xFFB8860B),
      fgColor: Colors.white,
      icon: Icons.emoji_events,
      label: 'Gold',
    );
  }
  if (rank == 2) {
    return (
      bgColor: const Color(0xFF607D8B),
      fgColor: Colors.white,
      icon: Icons.emoji_events,
      label: 'Silver',
    );
  }
  if (rank == 3) {
    return (
      bgColor: const Color(0xFF8D5524),
      fgColor: Colors.white,
      icon: Icons.emoji_events,
      label: 'Bronze',
    );
  }
  return (
    bgColor: const Color(0xFF455A64),
    fgColor: Colors.white,
    icon: Icons.workspace_premium,
    label: 'Top 10',
  );
}
