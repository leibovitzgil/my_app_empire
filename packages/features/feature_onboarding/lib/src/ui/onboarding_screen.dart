import 'package:core_ui/core_ui.dart';
import 'package:feature_onboarding/src/bloc/onboarding_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A single onboarding page's content.
class OnboardingPage {
  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

/// A swipeable onboarding flow driven by [OnboardingBloc]. Calls [onCompleted]
/// when the user finishes the last page.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.pages, this.onCompleted, super.key});

  final List<OnboardingPage> pages;
  final VoidCallback? onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<OnboardingBloc, OnboardingState>(
          listener: (context, state) {
            if (state.completed) {
              widget.onCompleted?.call();
              return;
            }
            if (_controller.hasClients &&
                _controller.page?.round() != state.page) {
              _controller.animateToPage(
                state.page,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: widget.pages.length,
                    onPageChanged: (page) => context
                        .read<OnboardingBloc>()
                        .add(OnboardingPageChanged(page)),
                    itemBuilder: (context, index) =>
                        _Page(page: widget.pages[index]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: PrimaryButton(
                    label: state.isLastPage ? 'Get started' : 'Next',
                    onPressed: () => context
                        .read<OnboardingBloc>()
                        .add(const OnboardingAdvanced()),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.page});

  final OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(page.icon, size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 32),
          Text(page.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(page.description, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
