import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../bloc/permissions_cubit.dart';
import '../widgets/permissions_content.dart';

class PermissionsPage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onComplete;

  const PermissionsPage({
    super.key,
    required this.onBack,
    required this.onComplete,
  });

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<PermissionsCubit>()..load(),
      child: BlocBuilder<PermissionsCubit, PermissionsState>(
        builder: (context, state) {
          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: PermissionsContent(
                  state: state,
                  onBack: widget.onBack,
                  onComplete: widget.onComplete,
                  onRetry: () => context.read<PermissionsCubit>().load(),
                  onSelectSource: (sourceId) =>
                      context.read<PermissionsCubit>().selectSource(sourceId),
                  onTogglePermission: (permissionId) => context
                      .read<PermissionsCubit>()
                      .togglePermission(permissionId),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
