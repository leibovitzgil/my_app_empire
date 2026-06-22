part of 'onboarding_bloc.dart';

final class OnboardingState extends Equatable {
  const OnboardingState({
    required this.pageCount,
    this.page = 0,
    this.completed = false,
  });

  /// The current page index.
  final int page;

  /// Total number of onboarding pages.
  final int pageCount;

  /// Whether onboarding has been completed.
  final bool completed;

  /// Whether [page] is the final page.
  bool get isLastPage => page >= pageCount - 1;

  OnboardingState copyWith({int? page, bool? completed}) {
    return OnboardingState(
      pageCount: pageCount,
      page: page ?? this.page,
      completed: completed ?? this.completed,
    );
  }

  @override
  List<Object?> get props => [page, pageCount, completed];
}
