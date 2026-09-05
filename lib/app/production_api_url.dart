/// URL API de production (Render HTTPS).
///
/// Priorité :
/// 1. `--dart-define=CITYCARE_API_URL=…` (override build)
/// 2. Cette constante (valeur par défaut de l’app)
///
/// Dès qu’elle est non vide, USB / LAN / Cloudflare / localhost ne sont
/// jamais utilisés (voir [ApiConfig.productionApiUrl]).
library;

/// Base API publique CityCare (préfixe /api/v1 conservé pour toutes les routes).
const kProductionApiUrl = 'https://citycare-gp0y.onrender.com/api/v1';
