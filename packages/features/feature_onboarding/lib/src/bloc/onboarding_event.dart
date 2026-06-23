part of 'onboarding_bloc.dart';

sealed class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

/// The user swiped to [page].
final class OnboardingPageChanged extends OnboardingEvent {
  const OnboardingPageChanged(this.page);

  final int page;

  @override
  List<Object?> get props => [page];
}

/// The user tapped next / get-started; advances or completes onboarding.
final class OnboardingAdvanced extends OnboardingEvent {
  const OnboardingAdvanced();
}
