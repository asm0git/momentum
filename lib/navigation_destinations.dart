enum AppDestination {
  dashboard(title: 'Dashboard', iconName: 'Home', route: '/dashboard'),
  calendar(title: 'Calendar', iconName: 'Calendar', route: '/calendar'),
  timer(title: 'Timer', iconName: 'Timer', route: '/timer'),
  insights(title: 'Insights', iconName: 'Insights', route: '/insights'),
  todo(title: 'To-Do', iconName: 'To-Do', route: '/todo');

  const AppDestination({
    required this.title,
    required this.iconName,
    required this.route,
  });

  final String title;
  final String iconName;
  final String route;
}
