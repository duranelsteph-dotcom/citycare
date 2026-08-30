import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/circle.dart';
import '../../domain/repositories/circle_repository.dart';

class CircleController extends ChangeNotifier {
  CircleController(this._repository);

  final CircleRepository _repository;

  List<Circle> circles = [];
  List<CircleMember> members = [];
  Circle? selected;
  bool isLoading = false;
  String? errorMessage;

  Future<void> load() async {
    await _run(() async {
      circles = await _repository.list();
      if (selected != null) {
        final still = circles.where((item) => item.id == selected!.id).firstOrNull;
        selected = still;
        if (still != null) {
          members = await _repository.members(still.id);
        } else {
          members = [];
        }
      } else if (circles.isNotEmpty) {
        selected = circles.first;
        members = await _repository.members(selected!.id);
      }
    });
  }

  Future<bool> create(String name) {
    return _run(() async {
      final created = await _repository.create(name);
      circles = await _repository.list();
      selected = circles.where((item) => item.id == created.id).firstOrNull ?? created;
      members = await _repository.members(selected!.id);
    });
  }

  Future<bool> join(String code) {
    return _run(() async {
      final joined = await _repository.join(code);
      circles = await _repository.list();
      selected = circles.where((item) => item.id == joined.id).firstOrNull ?? joined;
      members = await _repository.members(selected!.id);
    });
  }

  Future<bool> select(Circle? circle) {
    selected = circle;
    notifyListeners();
    if (circle == null) {
      members = [];
      notifyListeners();
      return Future.value(true);
    }
    return _run(() async {
      members = await _repository.members(circle.id);
    });
  }

  Future<bool> leave(String circleId) {
    return _run(() async {
      await _repository.leave(circleId);
      circles = await _repository.list();
      if (selected?.id == circleId) {
        selected = circles.isEmpty ? null : circles.first;
        members = selected == null ? [] : await _repository.members(selected!.id);
      }
    });
  }

  Future<bool> removeMember(String userId) {
    final circle = selected;
    if (circle == null) {
      return Future.value(false);
    }
    return _run(() async {
      await _repository.removeMember(circle.id, userId);
      members = await _repository.members(circle.id);
      circles = await _repository.list();
      selected = circles.where((item) => item.id == circle.id).firstOrNull ?? circle;
    });
  }

  Future<bool> regenerateInvite() {
    final circle = selected;
    if (circle == null) {
      return Future.value(false);
    }
    return _run(() async {
      final code = await _repository.regenerateInvite(circle.id);
      _applyInviteCode(circle, code);
    });
  }

  /// Relit le code sans le régénérer. Échec silencieux : on garde le code déjà chargé.
  Future<void> refreshInviteCode() async {
    final circle = selected;
    if (circle == null) {
      return;
    }
    try {
      final code = await _repository.currentInvite(circle.id);
      if (code == circle.inviteCode) {
        return;
      }
      _applyInviteCode(circle, code);
      notifyListeners();
    } catch (_) {
      // L'écran affiche encore inviteCode local.
    }
  }

  void _applyInviteCode(Circle circle, String code) {
    selected = circle.copyWith(inviteCode: code);
    circles = [
      for (final item in circles)
        if (item.id == circle.id) item.copyWith(inviteCode: code) else item,
    ];
  }

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Impossible de mettre à jour le cercle pour le moment.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
