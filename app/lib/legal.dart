/// About / credits / legal text and a simple viewer screen.
/// Mirrors the hosted policy at https://jaimeferreira2002.github.io/meetro.lx —
/// keep the two in sync. Not lawyer-reviewed; the contact email is still a
/// placeholder (CONTACT_EMAIL) pending a real address.
import 'package:flutter/material.dart';

const appName = 'meetro'; // meetro .Lisboa
const appVersion = '0.1.0';

const disclaimer =
    'Unofficial app. Not affiliated with, endorsed by, or operated by '
    'Metropolitano de Lisboa, E.P.E. Arrival times and train positions are '
    'estimates and may be inaccurate — do not rely on them for time-critical travel.';

/// (source label, attribution) pairs shown in the credits list.
const credits = <(String, String)>[
  ('Transit data', 'Metropolitano de Lisboa, E.P.E. — EstadoServicoML API'),
  ('Map tiles', '© OpenStreetMap contributors, © CARTO'),
  ('Search / geocoding', 'OpenStreetMap — Nominatim'),
  ('Track geometry', '© OpenStreetMap contributors'),
];

const privacyPolicy = '''
Last updated: 18 July 2026
Online: https://jaimeferreira2002.github.io/meetro.lx/privacy.html

$appName ("the app") respects your privacy. This policy explains what the app
does and does not do with your information.

WHAT WE COLLECT
• No accounts, no advertising, no analytics or tracking SDKs.
• The app developer does not collect or store your personal data.

LOCATION
• If you grant permission, your device location is used only to center the map
  on where you are. It is processed on your device and is not sent to us or
  stored. You can deny or revoke this permission at any time in system settings.

SEARCH
• When you search for a place, your query is sent to OpenStreetMap's Nominatim
  service to find matching locations. This is subject to the OpenStreetMap
  Foundation privacy policy.

NETWORK REQUESTS TO THIRD PARTIES
• The app loads live transit data via a relay service and map tiles from CARTO/
  OpenStreetMap. As with any internet request, these providers may receive your
  IP address and standard request metadata under their own policies. The relay
  service does not associate requests with your identity or store personal data.

CHILDREN
• The app is not directed at children and does not knowingly collect data from
  them.

CHANGES
• We may update this policy; material changes will be reflected here with a new
  date.

CONTACT
• CONTACT_EMAIL
''';

const termsOfUse = '''
Last updated: 18 July 2026
Online: https://jaimeferreira2002.github.io/meetro.lx/terms.html

1. UNOFFICIAL SERVICE
$appName is an independent, unofficial app. It is not affiliated with,
endorsed by, or operated by Metropolitano de Lisboa, E.P.E. All transit data
originates from Metro Lisboa's public API.

2. NO WARRANTY / ESTIMATES
The app is provided "as is", without warranties of any kind. Arrival times and
train positions are computed estimates and may be delayed, inaccurate, or
unavailable. Do not rely on the app for time-critical or safety-related
decisions.

3. LIMITATION OF LIABILITY
To the maximum extent permitted by law, the developer is not liable for any
loss or damage arising from use of, or reliance on, the app.

4. INTELLECTUAL PROPERTY
Transit data is © Metropolitano de Lisboa, E.P.E. Map data is © OpenStreetMap
contributors and © CARTO. All marks belong to their respective owners.

5. ACCEPTABLE USE
Do not misuse the app or attempt to disrupt its services or the upstream data
providers.

6. GOVERNING LAW
These terms are governed by the laws of Portugal, without regard to conflict of
law rules.

7. CHANGES
We may update these terms; continued use constitutes acceptance.

CONTACT
CONTACT_EMAIL
''';

/// Full-screen scrollable viewer for a legal document.
class LegalScreen extends StatelessWidget {
  final String title;
  final String body;

  const LegalScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.white, foregroundColor: Colors.black87),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          body.trim(),
          style: const TextStyle(color: Colors.black87, height: 1.5, fontSize: 14),
        ),
      ),
    );
  }
}
