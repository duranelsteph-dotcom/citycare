/// Hôte LAN du PC de développement (IPv4 privée).
///
/// Généré / mis à jour pour **cette** machine Windows. Pas un secret.
/// 127.0.0.1 sur le téléphone = le téléphone, sauf `adb reverse`.
/// Mettre à jour si `ipconfig` change (nouveau Wi‑Fi).
///
/// Ne jamais promouvoir [kDevHotspotHost] en premier : c’est le hotspot
/// Windows (192.168.137.1). Le téléphone n’y a une route que s’il y est.
library;

/// IPv4 Wi‑Fi actuelle (`ipconfig`, passerelle 10.5.50.1). Pas 127.0.0.1.
const kDevLanHost = '10.5.48.255';

/// Port uvicorn local.
const kDevLanPort = 8000;

/// Hotspot Windows — dernier recours, seulement si le health répond.
const kDevHotspotHost = '192.168.137.1';

/// URL API complète via le Wi‑Fi du PC (même réseau que le téléphone).
const kDevLanApiUrl = 'http://$kDevLanHost:$kDevLanPort/api/v1';

/// URL API via le hotspot Windows. Ne pas mémoriser si le health échoue.
const kDevHotspotApiUrl = 'http://$kDevHotspotHost:$kDevLanPort/api/v1';