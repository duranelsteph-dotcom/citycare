# Soutenance CityCare — scénario 10 minutes

Application de **prévention, alerte et dernière position connue** (jeune / parent / proche).
Ce n’est **pas** un GPS temps réel, **pas** un kidnapping confirmé.

## Comptes démo

Mot de passe pour tous : `motdepasse`.  
Après le mot de passe : code OTP affiché à l’écran (**aucun SMS**). En développement, le backend renvoie `otp_dev`.

| Rôle | Téléphone | Nom |
| --- | --- | --- |
| Parent | `+237699000001` | Marie Demo |
| Jeune | `+237699000002` | Amina Demo |
| Proche | `+237699000003` | Marc Demo |
| Autorité | `+237699000004` | Poste Demo |

Préparer les données : depuis `backend/`, venv activé,

```text
python -m simulator seed --play
```

Cercle **Famille Demo** (Marie + Amina + Marc). Les liens de confiance (GuardianLink) restent séparés : rejoindre le cercle **ne donne pas** la position.

## Scénario 10 minutes

1. **Login parent (≈1 min)** — `+237699000001` / `motdepasse` / OTP démo. Quatre onglets : Accueil, Membres, Alertes, Profil.
2. **Carte (≈2 min)** — Accueil = carte. Pastilles = dernière position connue, pas un suivi en direct. Feuille membres : Amina, fraîcheur honnête, batterie kit si présente. Statut « Position récente » ≠ garantie de sécurité.
3. **Cercle (≈1 min)** — Profil → Mes cercles / Rejoindre. Montrer **Famille Demo** et le code. Créer ou rejoindre : grouping seulement.
4. **SOS (≈2 min)** — FAB rouge (jeune) ou onglet Alertes (parent). Lire le bandeau **« pas un kidnapping confirmé »**. Déclencher ou ouvrir la fiche démo. Clore ≠ preuve d’enlèvement.
5. **Zones (≈2 min)** — Toutes les fonctions → Zones de sécurité (École, Maison) et zone à risque « Carrefour du marché ». Entrée / sortie = règles + horaires, pas une disparition.
6. **Historique (≈1 min)** — Chips Aujourd’hui / Hier / 7 jours. Liste de trajets, **pas** un rapport de conduite (pas de vitesse max).
7. **Anomalie / kit (≈1 min)** — Bandeau carte ou Notifications si une anomalie a été jouée. Règles métier, **pas de machine learning**. Kit IoT : le bracelet parle au **serveur**, pas à l’app.

## Réel vs simulé

| Sujet | État pour la soutenance |
| --- | --- |
| SMS / OTP | **Simulé.** Code affiché (`otp_dev`). Aucun opérateur SMS. |
| Kit IoT | **Simulé.** Script `simulator` + secret local (`.demo_kit.json`). Pas un vrai bracelet. |
| IA / anomalies | **Règles métier explicables** (arrêt, trou de signal, saut GPS…). Pas de TFLite, pas de Random Forest entraîné. |
| Push FCM | **Optionnel.** Inbox in-app toujours. Push seulement si Firebase est configuré **et** un jeton appareil enregistré. |
| Carte | OpenStreetMap par défaut. Google Maps seulement avec une clé (pas versionnée). |
| File hors ligne | Réelle (positions / SOS en file, flush au retour réseau). Pas une synchro magique. |
| Phase 16 (SMS production, TFLite, Firestore) | **Non implémentée** — hors périmètre. |
| Phase 17 (anomalies) | **En place** : règles + inbox + bandeau carte. Ne pas la présenter comme du ML. |

## Phrase utile si on insiste

> « CityCare montre une dernière position connue et une demande d’aide. Ce n’est pas un kidnapping confirmé, pas un suivi en direct. »
