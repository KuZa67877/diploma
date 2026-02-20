import 'package:flutter/material.dart';
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
      initial: () => const Center(
        child: CircularProgressIndicator(),
      ),
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (message) => PermissionsErrorState(
        message: message,
        onRetry: onRetry,
      ),
      loaded: (
        sources,
        permissions,
        selectedSourceId,
        selectedPermissions,
      ) {
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
