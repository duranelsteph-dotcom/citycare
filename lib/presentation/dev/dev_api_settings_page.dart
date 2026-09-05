import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/brand.dart';
import '../../core/config/api_config.dart';

/// Écran dev : saisir l’URL API après redémarrage PC (tunnel Cloudflare, etc.).
class DevApiSettingsPage extends StatefulWidget {
  const DevApiSettingsPage({super.key});

  @override
  State<DevApiSettingsPage> createState() => _DevApiSettingsPageState();
}

class _DevApiSettingsPageState extends State<DevApiSettingsPage> {
  late final TextEditingController _urlController;
  bool _busy = false;
  String? _message;
  bool? _savedOk;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiConfig.manualApiUrl ?? ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    setState(() {
      _busy = true;
      _message = null;
      _savedOk = null;
    });
    final ok = await ApiConfig.applyManualApiUrl(_urlController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _savedOk = ok;
      _message = ok
          ? 'Serveur joignable. URL enregistrée : ${ApiConfig.baseUrl}'
          : 'Impossible de joindre le serveur. Vérifiez l’URL et que le tunnel tourne sur le PC.';
    });
  }

  Future<void> _reset() async {
    setState(() {
      _busy = true;
      _message = null;
      _savedOk = null;
    });
    await ApiConfig.clearManualApiUrl();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _urlController.text = ApiConfig.baseUrl;
      _message = 'URL manuelle effacée. Détection automatique relancée.';
      _savedOk = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('URL du serveur (dev)'),
        backgroundColor: CityCareBrand.violet,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(CityCareBrand.spaceLg),
        children: [
          const Text(
            'Après un redémarrage du PC, le tunnel Cloudflare change d’adresse. '
            'Collez la nouvelle URL ici — pas besoin de réinstaller l’APK.',
            style: TextStyle(color: CityCareBrand.mutedText, height: 1.45),
          ),
          const SizedBox(height: CityCareBrand.spaceMd),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'URL API',
              hintText: 'https://….trycloudflare.com/api/v1',
              suffixIcon: IconButton(
                tooltip: 'Coller',
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null && data!.text!.isNotEmpty) {
                    _urlController.text = data.text!.trim();
                  }
                },
                icon: const Icon(Icons.content_paste),
              ),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: CityCareBrand.spaceSm),
          Text(
            'Actuel : ${ApiConfig.baseUrl}',
            style: const TextStyle(fontSize: 12, color: CityCareBrand.mutedText),
          ),
          if (_message != null) ...[
            const SizedBox(height: CityCareBrand.spaceMd),
            Text(
              _message!,
              style: TextStyle(
                color: _savedOk == true ? Colors.green.shade800 : Theme.of(context).colorScheme.error,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: CityCareBrand.spaceXl),
          FilledButton(
            onPressed: _busy ? null : _testAndSave,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Tester et enregistrer'),
          ),
          const SizedBox(height: CityCareBrand.spaceSm),
          OutlinedButton(
            onPressed: _busy ? null : _reset,
            child: const Text('Effacer l’URL manuelle'),
          ),
          const SizedBox(height: CityCareBrand.spaceLg),
          const Text(
            'Sur le PC : .\\scripts\\start_dev_tunnel.ps1\n'
            'L’URL s’affiche dans le terminal (copiée dans le presse-papiers).',
            style: TextStyle(fontSize: 12, color: CityCareBrand.mutedText, height: 1.4),
          ),
        ],
      ),
    );
  }
}
