import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/goal_widgets.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  static const _filters = [
    (null, 'All'),
    ('active', 'Active'),
    ('paused', 'Paused'),
    ('completed', 'Completed'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(goalsProvider);
    final filter = ref.watch(goalsFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [
          IconButton(
            onPressed: () => context.push('/goals/new'),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              children: _filters.map((f) {
                final selected = filter == f.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: Gap.sm),
                  child: ChoiceChip(
                    label: Text(f.$2),
                    selected: selected,
                    onSelected: (_) =>
                        ref.read(goalsFilterProvider.notifier).state = f.$1,
                    showCheckmark: false,
                    selectedColor:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(Gap.page),
                child: LoadingList(count: 4, height: 112),
              ),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(goalsProvider),
              ),
              data: (goals) {
                if (goals.isEmpty) {
                  return EmptyState(
                    icon: Icons.flag_outlined,
                    title: filter == null ? 'No goals yet' : 'Nothing here',
                    message: filter == null
                        ? 'Start with one thing you actually want to change. We will break it down for you.'
                        : 'No goals match this filter.',
                    actionLabel: filter == null ? 'Create a goal' : null,
                    onAction: () => context.push('/goals/new'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(goalsProvider),
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xxl),
                    itemCount: goals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
                    itemBuilder: (_, i) => GoalCard(
                      goal: goals[i],
                      onTap: () => context.push('/goals/${goals[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
