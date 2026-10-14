import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../data_models.dart';

// Owns one provider's published-calendar link field and edit state.
class CalendarFeedEditor extends StatefulWidget {
  const CalendarFeedEditor({
    super.key,
    required this.provider,
    required this.iconAsset,
    required this.connected,
    required this.connecting,
    required this.onConnect,
    this.onEditingStarted,
    this.onCancelled,
  });

  final CalendarProvider provider;
  final String iconAsset;
  final bool connected;
  final bool connecting;
  final Future<bool> Function(String url) onConnect;
  final VoidCallback? onEditingStarted;
  final VoidCallback? onCancelled;

  @override
  State<CalendarFeedEditor> createState() => _CalendarFeedEditorState();
}

class _CalendarFeedEditorState extends State<CalendarFeedEditor> {
  final _controller = TextEditingController();
  bool _isEditing = false;

  @override
  void didUpdateWidget(covariant CalendarFeedEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connected != widget.connected) {
      _controller.clear();
      _isEditing = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.connected && !_isEditing) {
      return SizedBox(
        height: AppSpacing.popupFieldHeight,
        child: OutlinedButton.icon(
          onPressed: _beginEditing,
          icon: const Icon(Icons.link),
          label: const Text('Change published link'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, AppSpacing.popupFieldHeight),
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            textStyle: _actionTextStyle(context, AppColors.primary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.connected
              ? 'Enter a new published link. The saved link is kept private and is not shown here.'
              : _instructions(widget.provider),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.xs),
        _buildField(context),
        const SizedBox(height: AppSpacing.xs),
        if (widget.connected)
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: widget.connecting ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.popupFieldHeight),
                    textStyle: _actionTextStyle(context, AppColors.onPrimary),
                  ),
                  child: Text(
                    widget.connecting ? 'Checking calendar…' : 'Update link',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.connecting ? null : _cancelEditing,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.popupFieldHeight),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    textStyle: _actionTextStyle(context, AppColors.primary),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          )
        else
          SizedBox(
            height: AppSpacing.popupFieldHeight,
            child: FilledButton.icon(
              onPressed: widget.connecting ? null : _submit,
              icon: Image.asset(
                widget.iconAsset,
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
              label: Text(
                widget.connecting
                    ? 'Checking calendar…'
                    : _connectButtonLabel(widget.provider),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.popupFieldHeight),
                textStyle: _actionTextStyle(context, AppColors.onPrimary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildField(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadii.popup),
    ),
    child: SizedBox(
      height: AppSpacing.popupFieldHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: double.infinity,
            height: 24,
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textAlignVertical: TextAlignVertical.center,
              style: _fieldTextStyle(context),
              decoration: InputDecoration.collapsed(
                hintText: '${widget.provider.title} published .ics link',
                hintStyle: _fieldHintStyle(context),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void _beginEditing() {
    setState(() {
      _isEditing = true;
      _controller.clear();
    });
    widget.onEditingStarted?.call();
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _controller.clear();
    });
    widget.onCancelled?.call();
  }

  Future<void> _submit() async {
    final connected = await widget.onConnect(_controller.text);
    if (!mounted || !connected) return;
    setState(() {
      _isEditing = false;
      _controller.clear();
    });
  }

  TextStyle _actionTextStyle(BuildContext context, Color color) => Theme.of(
    context,
  ).textTheme.bodyMedium!.copyWith(color: color, fontWeight: FontWeight.normal);

  TextStyle _fieldTextStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .bodyMedium!
      .copyWith(color: AppColors.onSurface, fontWeight: FontWeight.normal);

  TextStyle _fieldHintStyle(BuildContext context) => _fieldTextStyle(
    context,
  ).copyWith(color: AppColors.onSurface.withValues(alpha: 0.55));

  String _instructions(CalendarProvider provider) => switch (provider) {
    CalendarProvider.canvas =>
      'Paste the calendar feed link from Canvas. The link grants read access; keep it private.',
    CalendarProvider.googleCalendar =>
      'Paste the secret address in iCal format from Google Calendar. Anyone with the link can view the calendar, so keep it private.',
    CalendarProvider.outlook =>
      'Paste the published ICS link from Outlook. Anyone with the link can view the calendar, so keep it private.',
  };

  String _connectButtonLabel(CalendarProvider provider) =>
      provider == CalendarProvider.googleCalendar
      ? 'Connect Google Calendar'
      : 'Connect ${provider.title} calendar';
}
