import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Pilote un [OtpField] depuis le parent : vider les cases et refocaliser la
/// première, ou lire la valeur courante.
///
/// À instancier dans le `State` du parent (jamais dans `build`) et à passer via
/// [OtpField.controller]. Aucune ressource à disposer côté contrôleur : il ne
/// fait que déléguer à l'état du champ tant que celui-ci est monté.
class OtpFieldController {
  _OtpFieldState? _state;

  /// Vide toutes les cases et redonne le focus à la première.
  void clear() => _state?._clearAll();

  /// Donne le focus à la première case (sans effacer).
  void focusFirst() => _state?._focusFirst();

  /// Concaténation des chiffres saisis (chaîne vide si aucun).
  String get value => _state?._value ?? '';
}

/// Champ de saisie d'un code OTP en **cases séparées** (une par chiffre).
///
/// - clavier numérique, avance automatique au remplissage, retour arrière qui
///   recule sur la case précédente ;
/// - [onCompleted] est appelé dès que toutes les cases sont remplies ;
/// - [hasError] passe les bordures en rouge (message géré par le parent) ;
/// - le collage d'un code complet est réparti sur les cases.
///
/// Le parent garde la main via un [OtpFieldController] (vider / refocaliser).
class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    this.length = 4,
    required this.onCompleted,
    this.onChanged,
    this.controller,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
  });

  /// Nombre de cases (chiffres attendus).
  final int length;

  /// Appelé avec le code complet dès que toutes les cases sont remplies.
  final ValueChanged<String> onCompleted;

  /// Notifié à chaque changement (saisie partielle incluse).
  final ValueChanged<String>? onChanged;

  /// Contrôleur optionnel pour piloter le champ depuis le parent.
  final OtpFieldController? controller;

  /// Passe les bordures en rouge (état erreur).
  final bool hasError;

  /// Désactive la saisie (ex. pendant la vérification).
  final bool enabled;

  /// Donne le focus à la première case à l'affichage.
  final bool autofocus;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(
      widget.length,
      (i) => FocusNode(onKeyEvent: (node, event) => _onKey(i, event)),
    );
    for (final node in _focusNodes) {
      node.addListener(_onFocusChanged);
    }
    widget.controller?._state = this;
  }

  @override
  void dispose() {
    if (identical(widget.controller?._state, this)) {
      widget.controller?._state = null;
    }
    for (final node in _focusNodes) {
      node.removeListener(_onFocusChanged);
      node.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  String get _value => _controllers.map((c) => c.text).join();

  bool get _isComplete => _controllers.every((c) => c.text.isNotEmpty);

  void _clearAll() {
    for (final controller in _controllers) {
      controller.clear();
    }
    if (mounted) setState(() {});
    _focusFirst();
    widget.onChanged?.call('');
  }

  void _focusFirst() {
    if (_focusNodes.isNotEmpty) _focusNodes.first.requestFocus();
  }

  /// Recule sur la case précédente lorsqu'on efface une case déjà vide.
  KeyEventResult _onKey(int index, KeyEvent event) {
    final isBackspace = event.logicalKey == LogicalKeyboardKey.backspace &&
        event is KeyDownEvent;
    if (isBackspace && _controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      widget.onChanged?.call(_value);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onChanged(int index, String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      // Case effacée : normaliser puis notifier (le recul est géré par _onKey).
      if (_controllers[index].text.isNotEmpty) _controllers[index].text = '';
      widget.onChanged?.call(_value);
      return;
    }
    if (digits.length == 1) {
      _setBox(index, digits);
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else {
      _distribute(index, digits);
    }
    _emit();
  }

  /// Répartit un code collé (ou saisie multiple) à partir de [start].
  void _distribute(int start, String digits) {
    var idx = start;
    for (var k = 0; k < digits.length && idx < widget.length; k++, idx++) {
      _setBox(idx, digits[k]);
    }
    final nextEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
    final target = nextEmpty == -1 ? widget.length - 1 : nextEmpty;
    _focusNodes[target].requestFocus();
  }

  void _setBox(int index, String digit) {
    _controllers[index].value = TextEditingValue(
      text: digit,
      selection: const TextSelection.collapsed(offset: 1),
    );
  }

  void _emit() {
    widget.onChanged?.call(_value);
    if (_isComplete) {
      _focusNodes.last.unfocus();
      widget.onCompleted(_value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          _box(i),
        ],
      ],
    );
  }

  Widget _box(int index) {
    final palette = context.palette;
    final focused = _focusNodes[index].hasFocus;
    final Color borderColor;
    if (widget.hasError) {
      borderColor = AppColors.danger;
    } else if (focused) {
      borderColor = AppColors.primary;
    } else {
      borderColor = palette.border;
    }
    final emphasised = widget.hasError || focused;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 56,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.field,
        border: Border.all(color: borderColor, width: emphasised ? 2 : 1.4),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        enabled: widget.enabled,
        autofocus: widget.autofocus && index == 0,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: index == widget.length - 1
            ? TextInputAction.done
            : TextInputAction.next,
        style: AppTypography.h3.copyWith(color: palette.textPrimary),
        cursorColor: AppColors.primary,
        // Pas de maxLength (collage réparti) ; on filtre les non-chiffres.
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) => _onChanged(index, value),
      ),
    );
  }
}
