import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/search.dart';
import '../../domain/repositories/case_repository.dart';

class CaseController extends ChangeNotifier {
  CaseController(this._repository);

  final CaseRepository _repository;

  List<MissingPersonCase> items = [];
  MissingPersonCase? current;
  List<CaseEvent> timeline = [];
  Trajectory? trajectory;
  SearchIntelligence? intelligence;
  AiAnalysis? aiAnalysis;
  List<SearchZone> searchZones = [];
  List<Testimony> testimonies = [];
  bool isBusy = false;
  String? errorMessage;

  SearchZone? get probableZone {
    for (final zone in searchZones) {
      if (zone.isProbable) {
        return zone;
      }
    }
    return null;
  }

  List<SearchZone> get priorityZones {
    final items = [for (final zone in searchZones) if (zone.isPriority) zone];
    items.sort((a, b) => a.priorityRank.compareTo(b.priorityRank));
    return items;
  }

  MissingPersonCase? get openCase {
    for (final item in items) {
      if (item.isOpen) {
        return item;
      }
    }
    return current?.isOpen == true ? current : null;
  }

  Future<void> loadMineAsYoung() async {
    await _run(() async {
      items = await _repository.mineAsYoung();
      current = openCase;
    });
  }

  Future<void> loadMineAsGuardian() async {
    await _run(() async {
      items = await _repository.mineAsGuardian();
    });
  }

  Future<void> loadOne(String caseId) async {
    await _run(() async {
      current = await _repository.getById(caseId);
      try {
        timeline = await _repository.events(caseId);
      } on ApiException {
        timeline = [];
      }
      try {
        trajectory = await _repository.trajectory(caseId);
      } on ApiException {
        trajectory = null;
      }
      try {
        intelligence = await _repository.intelligence(caseId);
      } on ApiException {
        intelligence = null;
      }
      try {
        aiAnalysis = await _repository.aiAnalysis(caseId);
      } on ApiException {
        aiAnalysis = null;
      }
      try {
        searchZones = await _repository.searchZones(caseId);
      } on ApiException {
        searchZones = [];
      }
      try {
        testimonies = await _repository.testimonies(caseId);
      } on ApiException {
        testimonies = [];
      }
    });
  }

  Future<bool> create(CaseDraft draft, {String? photoPath}) {
    return _run(() async {
      current = await _repository.create(draft);
      if (photoPath != null && photoPath.isNotEmpty) {
        current = await _repository.uploadPhoto(current!.id, photoPath);
      }
      try {
        timeline = await _repository.events(current!.id);
      } on ApiException {
        timeline = [];
      }
      items = [current!, ...items.where((item) => item.id != current!.id)];
    });
  }

  Future<bool> acknowledge(String caseId) {
    return _run(() async {
      current = await _repository.acknowledge(caseId);
      items = [for (final item in items) if (item.id == current!.id) current! else item];
      try {
        timeline = await _repository.events(caseId);
      } on ApiException {
        timeline = [];
      }
    });
  }

  Future<bool> markInfo(String caseId) {
    return _run(() async {
      current = await _repository.markInfo(caseId);
      items = [for (final item in items) if (item.id == current!.id) current! else item];
      try {
        timeline = await _repository.events(caseId);
      } on ApiException {
        timeline = [];
      }
    });
  }

  Future<bool> markFound(String caseId) {
    return _run(() async {
      current = await _repository.markFound(caseId);
      items = [for (final item in items) if (item.id == current!.id) current! else item];
      await _reloadTimeline(caseId);
    });
  }

  Future<bool> startSearch(String caseId) {
    return _run(() async {
      current = await _repository.startSearch(caseId);
      items = [for (final item in items) if (item.id == current!.id) current! else item];
      await _reloadTimeline(caseId);
    });
  }

  Future<bool> refreshIntelligence(String caseId) {
    return _run(() async {
      intelligence = await _repository.refreshIntelligence(caseId);
      try {
        searchZones = await _repository.searchZones(caseId);
      } on ApiException {
        searchZones = [];
      }
      try {
        testimonies = await _repository.testimonies(caseId);
      } on ApiException {
        testimonies = [];
      }
      try {
        aiAnalysis = await _repository.aiAnalysis(caseId);
      } on ApiException {
        aiAnalysis = null;
      }
    });
  }

  Future<bool> close(String caseId) {
    return _run(() async {
      current = await _repository.close(caseId);
      items = [for (final item in items) if (item.id == current!.id) current! else item];
      await _reloadTimeline(caseId);
    });
  }

  Future<void> _reloadTimeline(String caseId) async {
    try {
      timeline = await _repository.events(caseId);
    } on ApiException {
      timeline = [];
    }
  }

  Future<bool> submitTestimony(String caseId, TestimonyDraft draft) {
    return _run(() async {
      final created = await _repository.submitTestimony(caseId, draft);
      testimonies = [created, ...testimonies.where((item) => item.id != created.id)];
    });
  }

  Future<bool> reviewTestimony(String caseId, String testimonyId) {
    return _replaceTestimony(() => _repository.reviewTestimony(caseId, testimonyId));
  }

  Future<bool> verifyTestimony(String caseId, String testimonyId) {
    return _replaceTestimony(() => _repository.verifyTestimony(caseId, testimonyId));
  }

  Future<bool> rejectTestimony(String caseId, String testimonyId) {
    return _replaceTestimony(() => _repository.rejectTestimony(caseId, testimonyId));
  }

  Future<bool> refreshAiAnalysis(String caseId) {
    return _run(() async {
      aiAnalysis = await _repository.refreshAiAnalysis(caseId);
      try {
        testimonies = await _repository.testimonies(caseId);
      } on ApiException {
        testimonies = [];
      }
    });
  }

  Future<bool> refreshTestimonyConsistency(String caseId) {
    return _run(() async {
      testimonies = await _repository.refreshTestimonyConsistency(caseId);
    });
  }

  Future<bool> _replaceTestimony(Future<Testimony> Function() action) {
    return _run(() async {
      final updated = await action();
      testimonies = [for (final item in testimonies) if (item.id == updated.id) updated else item];
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Dossier indisponible pour le moment.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
