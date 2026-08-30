import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../core/phone/phone_e164.dart';

/// Sélecteur de pays + saisie nationale, défaut Cameroun +237.
class PhoneNumberFormField extends FormField<String> {
  PhoneNumberFormField({
    super.key,
    required TextEditingController controller,
    required DialCountry country,
    required ValueChanged<DialCountry> onCountryChanged,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onFieldSubmitted,
  }) : super(
          validator: (_) {
            if (!PhoneE164.isPlausible(country, controller.text)) {
              return 'Entrez un numéro de téléphone valide';
            }
            return null;
          },
          builder: (state) {
            return _PhoneNumberBox(
              controller: controller,
              country: country,
              errorText: state.errorText,
              textInputAction: textInputAction,
              onCountryChanged: (next) {
                onCountryChanged(next);
                state.didChange(controller.text);
              },
              onChanged: state.didChange,
              onSubmitted: onFieldSubmitted,
            );
          },
        );
}

class _PhoneNumberBox extends StatelessWidget {
  const _PhoneNumberBox({
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    required this.onChanged,
    required this.textInputAction,
    this.errorText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final DialCountry country;
  final ValueChanged<DialCountry> onCountryChanged;
  final ValueChanged<String> onChanged;
  final TextInputAction textInputAction;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;

  Future<void> _pickCountry(BuildContext context) async {
    final selected = await showModalBottomSheet<DialCountry>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Indicatif',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              for (final item in PhoneE164.countries)
                ListTile(
                  leading: Text(item.flagEmoji, style: const TextStyle(fontSize: 22)),
                  title: Text(item.name),
                  trailing: Text(
                    item.dialCode,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: CityCareBrand.violet),
                  ),
                  selected: item.iso2 == country.iso2,
                  onTap: () => Navigator.of(context).pop(item),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      onCountryChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = errorText != null ? Theme.of(context).colorScheme.error : CityCareBrand.tileBorder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: CityCareBrand.fieldFill,
            borderRadius: CityCareBrand.borderRadiusMd,
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            children: [
              InkWell(
                key: const Key('auth-country-selector'),
                onTap: () => _pickCountry(context),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(CityCareBrand.radiusMd)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(country.flagEmoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(
                        country.dialCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: CityCareBrand.titleInk,
                        ),
                      ),
                      const Icon(Icons.expand_more, color: CityCareBrand.mutedText),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: CityCareBrand.tileBorder),
              Expanded(
                child: TextField(
                  key: const Key('auth-phone-field'),
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  textInputAction: textInputAction,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CityCareBrand.titleInk,
                  ),
                  cursorColor: CityCareBrand.violet,
                  decoration: InputDecoration(
                    filled: false,
                    hintText: country.placeholder,
                    hintStyle: const TextStyle(
                      color: Color(0xFF757575),
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
                  ),
                  onChanged: (value) {
                    final detected = PhoneE164.countryForInternational(value);
                    if (detected != null && detected.iso2 != country.iso2) {
                      onCountryChanged(detected);
                    }
                    onChanged(value);
                  },
                  onSubmitted: onSubmitted,
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
