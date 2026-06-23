import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_text_field.dart';
import '../widgets/cards/note_card.dart';

/// Écran « Notes spirituelles » : recherche, liste et ajout (FAB).
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes notes')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const SizedBox(height: AppSpacing.md),
            const AppSearchField(hint: 'Rechercher une note...'),
            const SizedBox(height: AppSpacing.lg),
            for (final n in SampleData.notes) ...[
              NoteCard(note: n, onTap: () {}),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
