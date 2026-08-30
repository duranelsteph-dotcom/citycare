import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/brand.dart';
import '../../domain/enums/citycare_enums.dart';
import '../auth/auth_scope.dart';
import '../family/family_scope.dart';
import 'alert_scope.dart';

/// FAB circulaire blanc / violet : le maintien le rend rouge et envoie le SOS.
///
/// Un appui court n’envoie rien : il ouvre les options (jeune) ou les alertes
/// (parent). [Annuler] est visible pendant le maintien et après un envoi réussi.
class HoldSosFab extends StatefulWidget {
  const HoldSosFab({
    super.key,
    required this.role,
    required this.onShortPress,
    this.holdDuration = const Duration(milliseconds: 1200),
  });

  final UserRole role;
  final VoidCallback onShortPress;
  final Duration holdDuration;

  @override
  State<HoldSosFab> createState() => _HoldSosFabState();
}

class _HoldSosFabState extends State<HoldSosFab> with SingleTickerProviderStateMixin {
  late final AnimationController _hold;
  bool _armed = false;
  bool _sending = false;
  bool _holdCancelled = false;
  bool _didActivate = false;
  String? _sentAlertId;

  @override
  void initState() {
    super.initState();
    _hold = AnimationController(vsync: this, duration: widget.holdDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted && !_holdCancelled) {
          _activate();
        }
      });
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _startHold() {
    if (_sending) {
      return;
    }
    _holdCancelled = false;
    _didActivate = false;
    setState(() => _armed = true);
    HapticFeedback.lightImpact();
    _hold.forward(from: 0);
  }

  /// Annule le maintien avant l’envoi. Ne touche pas à une alerte déjà partie.
  void _cancelHold() {
    if (_sending) {
      return;
    }
    _holdCancelled = true;
    _hold.stop();
    _hold.reset();
    setState(() => _armed = false);
  }

  void _release() {
    if (_sending || _didActivate || _hold.status == AnimationStatus.completed) {
      return;
    }
    if (_holdCancelled) {
      return;
    }
    final short = _hold.value < 0.25;
    _cancelHold();
    if (short) {
      widget.onShortPress();
    }
  }

  Future<void> _activate() async {
    if (_sending || _holdCancelled || _didActivate) {
      return;
    }
    _didActivate = true;
    setState(() => _sending = true);
    HapticFeedback.heavyImpact();
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final alerts = AlertScope.of(context);
      final role = widget.role;
      var sent = false;
      if (role == UserRole.young) {
        sent = await alerts.triggerSos(description: 'SOS maintenu (application)');
      } else {
        final family = FamilyScope.maybeOf(context);
        final candidates = family?.active.where((link) => link.canTriggerAlert).toList() ?? [];
        if (candidates.isEmpty) {
          messenger?.showSnackBar(
            const SnackBar(
              content: Text(
                'SOS non envoyé : aucun jeune autorisé. '
                'Ouvrez Alertes pour signaler un danger.',
              ),
            ),
          );
        } else if (candidates.length == 1) {
          sent = await alerts.triggerSos(youngPersonId: candidates.first.youngPersonId);
        } else {
          // Plusieurs jeunes : on envoie pour le premier autorisé, plutôt
          // que de faire semblant qu’un onglet suffit.
          sent = await alerts.triggerSos(youngPersonId: candidates.first.youngPersonId);
        }
      }
      if (!mounted) {
        return;
      }
      if (sent) {
        _sentAlertId = alerts.current?.id ?? alerts.openSos?.id;
        messenger?.showSnackBar(
          SnackBar(
            content: Text(alerts.infoMessage ?? 'SOS envoyé'),
            duration: const Duration(seconds: 8),
            action: _sentAlertId == null
                ? null
                : SnackBarAction(
                    label: 'Annuler',
                    onPressed: _cancelSent,
                  ),
          ),
        );
      } else {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(alerts.errorMessage ?? 'SOS indisponible pour le moment.'),
            backgroundColor: CityCareBrand.sos,
          ),
        );
      }
    } catch (error) {
      final detail = AlertScope.maybeOf(context)?.errorMessage;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(detail ?? 'SOS indisponible : $error'),
          backgroundColor: CityCareBrand.sos,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _armed = false;
        });
        _hold.reset();
      }
    }
  }

  Future<void> _cancelSent() async {
    final id = _sentAlertId ?? AlertScope.of(context).openSos?.id;
    if (id == null) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await AlertScope.of(context).cancel(id);
    if (!mounted) {
      return;
    }
    if (ok) {
      setState(() => _sentAlertId = null);
      messenger?.clearSnackBars();
      messenger?.showSnackBar(const SnackBar(content: Text('SOS annulé')));
    } else {
      final error = AlertScope.of(context).errorMessage;
      messenger?.showSnackBar(
        SnackBar(content: Text(error ?? 'Impossible d’annuler le SOS.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthScope.of(context).user?.role ?? widget.role;
    final openId = AlertScope.maybeOf(context)?.openSos?.id;
    final canCancelSent = _sentAlertId != null || openId != null;
    return AnimatedBuilder(
      animation: _hold,
      builder: (context, _) {
        final t = _hold.value;
        final fill = Color.lerp(Colors.white, CityCareBrand.sos, t)!;
        final ink = Color.lerp(CityCareBrand.violet, Colors.white, t)!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_armed || _sending || canCancelSent) ...[
              Material(
                color: Colors.white,
                elevation: 3,
                borderRadius: CityCareBrand.borderRadiusMd,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_sending)
                        const Text(
                          'Envoi du SOS…',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        )
                      else if (canCancelSent && !_armed)
                        const Text(
                          key: Key('sos-sent-label'),
                          'SOS envoyé',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: CityCareBrand.sos,
                          ),
                        )
                      else if (_armed)
                        Text(
                          'Maintenez… ${((1 - t) * (widget.holdDuration.inMilliseconds / 1000)).clamp(0, 9).toStringAsFixed(1)} s',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      GestureDetector(
                        key: const Key('sos-cancel'),
                        onTap: _sending
                            ? null
                            : (_armed ? _cancelHold : _cancelSent),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Text(
                            'Annuler',
                            style: TextStyle(
                              color: CityCareBrand.sos,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _sending ? null : (_) => _startHold(),
              onPointerUp: (_) => _release(),
              onPointerCancel: (_) => _cancelHold(),
              child: Tooltip(
                message: role == UserRole.young
                    ? 'Maintenez pour envoyer un SOS'
                    : 'Maintenez pour signaler un danger',
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 68,
                        height: 68,
                        child: CircularProgressIndicator(
                          value: t,
                          strokeWidth: 4,
                          color: CityCareBrand.sos,
                          backgroundColor: CityCareBrand.lavender,
                        ),
                      ),
                      Material(
                        key: const Key('sos-fab'),
                        color: fill,
                        elevation: 3,
                        shape: const CircleBorder(
                          side: BorderSide(color: CityCareBrand.violet, width: 2),
                        ),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Center(
                            child: _sending
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    'SOS',
                                    style: TextStyle(
                                      color: ink,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
