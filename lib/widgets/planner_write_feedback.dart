/// The user-visible operation that failed at the planner UI boundary.
enum PlannerWriteAction { saveItem, createCategory, deleteItem, deleteCategory }

/// Returns safe recovery guidance without exposing database or provider errors.
String plannerWriteFailureMessage(
  Object error, {
  required PlannerWriteAction action,
}) {
  if (error is ArgumentError) {
    return action == PlannerWriteAction.deleteCategory
        ? 'Choose a different destination and try again.'
        : 'Review the selected details and try again.';
  }

  if (error is StateError) {
    return switch (action) {
      PlannerWriteAction.saveItem =>
        'This item may have changed. Refresh and try again.',
      PlannerWriteAction.createCategory =>
        'The planner may have changed. Refresh and try again.',
      PlannerWriteAction.deleteItem =>
        'This item may already be removed. Refresh and try again.',
      PlannerWriteAction.deleteCategory =>
        'This category may already be removed. Refresh and try again.',
    };
  }

  return switch (action) {
    PlannerWriteAction.saveItem =>
      'Could not save this item. Please try again.',
    PlannerWriteAction.createCategory =>
      'Could not create this category. Please try again.',
    PlannerWriteAction.deleteItem =>
      'Could not delete this item. Please try again.',
    PlannerWriteAction.deleteCategory =>
      'Could not delete this category. Please try again.',
  };
}
