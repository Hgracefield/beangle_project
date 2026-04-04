import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.readOnly = false,
    this.enabled = true,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      readOnly: readOnly,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hint,
        filled: !enabled || readOnly,
        fillColor: const Color(0xFFF2F4F1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
//  << 아이디 입력필드 (성공했던 이메일이 로컬에 저장) -04.04.hj-

class EmailHistoryTextField extends StatefulWidget {
  const EmailHistoryTextField({
    super.key,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.suggestions,
    this.keyboardType,
    this.textInputAction,
  });

  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final List<String> suggestions;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  State<EmailHistoryTextField> createState() => _EmailHistoryTextFieldState();
}

class _EmailHistoryTextFieldState extends State<EmailHistoryTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Iterable<String> _buildOptions(TextEditingValue value) {
    final String query = value.text.trim().toLowerCase();
    if (widget.suggestions.isEmpty) {
      return const <String>[];
    }

    if (query.isEmpty) {
      return widget.suggestions;
    }

    return widget.suggestions.where(
      (String item) => item.toLowerCase().contains(query),
    );
  }

  void _triggerSuggestions() {
    widget.controller.value = widget.controller.value.copyWith(
      selection: TextSelection.collapsed(offset: widget.controller.text.length),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: _buildOptions,
      displayStringForOption: (String option) => option,
      onSelected: (String selection) {
        widget.controller.text = selection;
        widget.controller.selection = TextSelection.collapsed(
          offset: selection.length,
        );
      },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onTap: _triggerSuggestions,
              decoration: InputDecoration(
                prefixIcon: Icon(widget.icon),
                hintText: widget.hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            final List<String> optionList = options.toList(growable: false);
            if (optionList.isEmpty) {
              return const SizedBox.shrink();
            }

            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 400,
                    maxHeight: 220,
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: optionList.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = optionList[index];
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(option),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
    );
  }
}
