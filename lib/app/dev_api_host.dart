/// HÃ´te LAN du PC de dÃ©veloppement (IPv4 privÃ©e).
///
/// GÃ©nÃ©rÃ© / mis Ã  jour pour **cette** machine Windows. Pas un secret.
/// 127.0.0.1 sur le tÃ©lÃ©phone = le tÃ©lÃ©phone, sauf `adb reverse`.
/// Mettre Ã  jour si `ipconfig` change (nouveau Wiâ€‘Fi).
///
/// Ne jamais promouvoir [kDevHotspotHost] en premier : câ€™est le hotspot
/// Windows (192.168.137.1). Le tÃ©lÃ©phone nâ€™y a une route que sâ€™il y est.
library;

/// IPv4 Wiâ€‘Fi actuelle (`ipconfig`, passerelle 10.5.50.1). Pas 127.0.0.1.
const kDevLanHost = '10.5.50.210';

/// Port uvicorn local.
const kDevLanPort = 8000;

/// Hotspot Windows â€” dernier recours, seulement si le health rÃ©pond.
const kDevHotspotHost = '192.168.137.1';

/// URL API complÃ¨te via le Wiâ€‘Fi du PC (mÃªme rÃ©seau que le tÃ©lÃ©phone).
const kDevLanApiUrl = 'http://$kDevLanHost:$kDevLanPort/api/v1';

/// URL API via le hotspot Windows. Ne pas mÃ©moriser si le health Ã©choue.
const kDevHotspotApiUrl = 'http://$kDevHotspotHost:$kDevLanPort/api/v1';