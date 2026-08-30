import 'package:flutter/material.dart';

import '../alerts/alert_scope.dart';
import '../auth/auth_scope.dart';
import '../location/background_share_tile.dart';
import '../location/location_scope.dart';
import '../map/care_status.dart';
import '../notifications/notification_scope.dart';
import 'family_scope.dart';

class YoungProfilePage extends StatefulWidget {
  const YoungProfilePage({super.key});

  @override
  State<YoungProfilePage> createState() => _YoungProfilePageState();
}

class _YoungProfilePageState extends State<YoungProfilePage> {
  final _name = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    final family = FamilyScope.of(context);
    family.loadForYoung().then((_) {
      if (!mounted) {
        return;
      }
      final profile = family.youngProfile;
      if (profile != null) {
        _name.text = profile.displayName;
      } else {
        _name.text = AuthScope.of(context).user?.fullName ?? '';
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = FamilyScope.of(context);
    final locations = LocationScope.maybeOf(context);
    final alerts = AlertScope.maybeOf(context);
    final inbox = NotificationScope.maybeOf(context);
    final user = AuthScope.of(context).user;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          family,
          if (locations != null) locations,
          if (alerts != null) alerts,
          if (inbox != null) inbox,
        ]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (locations != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CareStatusBadge(
                    status: careStatusForMember(
                      point: locations.latest,
                      youngPersonId: user?.youngPersonId,
                      alerts: alerts?.items ?? const [],
                      inbox: inbox?.items ?? const [],
                      isSelf: true,
                      locations: locations,
                    ),
                    compact: false,
                    showDisclaimer: true,
                  ),
                ),
              const BackgroundShareTile(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Prénom / nom', border: OutlineInputBorder()),
              ),
              if (family.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(family.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: family.isLoading
                    ? null
                    : () async {
                        final ok = await family.saveYoungProfile(displayName: _name.text.trim());
                        if (ok && context.mounted) {
                          AuthScope.of(context).applyFullName(_name.text.trim());
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profil enregistré')),
                          );
                        }
                      },
                child: const Text('Enregistrer'),
              ),
              const SizedBox(height: 32),
              Text('Contacts d’urgence', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Personnes à joindre en cas de besoin. Ce n’est pas un SOS automatique, '
                'pas une notification push, pas un kidnapping confirmé.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactName,
                decoration: const InputDecoration(labelText: 'Nom du contact', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: family.isLoading
                    ? null
                    : () async {
                        final ok = await family.addContact(
                          name: _contactName.text.trim(),
                          phone: _contactPhone.text.trim(),
                        );
                        if (ok && context.mounted) {
                          _contactName.clear();
                          _contactPhone.clear();
                        }
                      },
                child: const Text('Ajouter un contact'),
              ),
              const SizedBox(height: 16),
              if (family.contacts.isEmpty)
                const Text('Aucun contact d’urgence pour le moment.')
              else
                ...family.contacts.map(
                  (contact) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(contact.name),
                    subtitle: Text(contact.phone),
                    trailing: IconButton(
                      tooltip: 'Retirer',
                      onPressed: family.isLoading ? null : () => family.removeContact(contact.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
