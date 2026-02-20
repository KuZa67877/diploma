import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../bloc/profile_cubit.dart';
import '../widgets/profile_content.dart';
import '../widgets/profile_error_state.dart';

class ProfilePage extends StatelessWidget {
  final VoidCallback onLogout;

  const ProfilePage({
    super.key,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProfileCubit>()..load(),
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          final viewData = state.whenOrNull(loaded: (data) => data);
          final errorMessage = state.whenOrNull(error: (message) => message);

          if (errorMessage != null) {
            return Scaffold(
              body: GradientBackground(
                child: SafeArea(
                  child: ProfileErrorState(
                    message: errorMessage,
                    onRetry: () => context.read<ProfileCubit>().load(),
                  ),
                ),
              ),
            );
          }

          if (viewData == null) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: ProfileContent(
                  viewData: viewData,
                  onLogout: onLogout,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}
