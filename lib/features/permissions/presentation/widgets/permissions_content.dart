import 'package:flutter/material.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../bloc/permissions_cubit.dart';
import 'permissions_error_state.dart';
import 'permissions_loaded_content.dart';

class PermissionsContent extends StatelessWidget {
  final PermissionsState state;
  final VoidCallback onBack;
  final VoidCallback onComplete;
  final VoidCallback onRetry;
  final ValueChanged<String> onSelectSource;
  final ValueChanged<String> onTogglePermission;

  const PermissionsContent({
    super.key,
    required this.state,
    required this.onBack,
    required this.onComplete,
    required this.onRetry,
    required this.onSelectSource,
    required this.onTogglePermission,
  });

  @override
  Widget build(BuildContext context) {
    return state.when(
      initial: _PermissionsLoadingShimmer.new,
      loading: _PermissionsLoadingShimmer.new,
      error: (message) =>
          PermissionsErrorState(message: message, onRetry: onRetry),
      loaded: (sources, permissions, selectedSourceId, selectedPermissions) {
        return PermissionsLoadedContent(
          sources: sources,
          permissions: permissions,
          selectedSourceId: selectedSourceId,
          selectedPermissions: selectedPermissions,
          onBack: onBack,
          onComplete: onComplete,
          onSelectSource: onSelectSource,
          onTogglePermission: onTogglePermission,
        );
      },
    );
  }
}

class _PermissionsLoadingShimmer extends StatelessWidget {
  const _PermissionsLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Row(
              children: [
                AppShimmerBox(width: 36, height: 36, shape: BoxShape.circle),
                SizedBox(width: 12),
                Expanded(child: AppShimmerBox(height: 18)),
              ],
            ),
            SizedBox(height: 18),
            AppShimmerBox(height: 18, width: 220),
            SizedBox(height: 8),
            AppShimmerBox(height: 14),
            SizedBox(height: 14),
            AppShimmerBox(
              height: 230,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            Spacer(),
            AppShimmerBox(
              height: 52,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ],
        ),
      ),
    );
  }
}
