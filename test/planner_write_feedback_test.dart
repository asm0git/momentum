import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/widgets/planner_write_feedback.dart';

void main() {
  test('maps invalid category destinations to actionable guidance', () {
    final message = plannerWriteFailureMessage(
      ArgumentError.value(
        4,
        'destinationCategoryId',
        'Choose an existing category.',
      ),
      action: PlannerWriteAction.deleteCategory,
    );

    expect(message, 'Choose a different destination and try again.');
    expect(message, isNot(contains('destinationCategoryId')));
  });

  test('maps stale planner state to refresh guidance', () {
    final message = plannerWriteFailureMessage(
      StateError('The task was not updated in local storage.'),
      action: PlannerWriteAction.saveItem,
    );

    expect(message, 'This item may have changed. Refresh and try again.');
    expect(message, isNot(contains('local storage')));
  });

  test('gives context-specific recovery guidance for delete failures', () {
    final itemMessage = plannerWriteFailureMessage(
      StateError('missing row id=12'),
      action: PlannerWriteAction.deleteItem,
    );
    final categoryMessage = plannerWriteFailureMessage(
      StateError('missing category id=4'),
      action: PlannerWriteAction.deleteCategory,
    );

    expect(
      itemMessage,
      'This item may already be removed. Refresh and try again.',
    );
    expect(
      categoryMessage,
      'This category may already be removed. Refresh and try again.',
    );
    expect(itemMessage, isNot(contains('id=12')));
    expect(categoryMessage, isNot(contains('id=4')));
  });

  test('keeps storage details out of generic failure guidance', () {
    const storageError = 'SQLITE_CANTOPEN at C:/private/planner.db';
    final message = plannerWriteFailureMessage(
      Exception(storageError),
      action: PlannerWriteAction.createCategory,
    );

    expect(message, 'Could not create this category. Please try again.');
    expect(message, isNot(contains(storageError)));
  });
}
