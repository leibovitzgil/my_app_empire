# Known Issues

The workspace is fully green:
`melos bootstrap && melos run lint && melos run test && melos run format-check`
all pass across every package, under uniform strict `very_good_analysis`.

There are no known outstanding issues. Historical items (duplicate packages,
broken bootstrap, compile/lint failures, two template apps, inconsistent lint
baselines) have all been resolved — see the git history for details.

When you hit something worth tracking, add it here with a short reproduction and
the package it affects.
