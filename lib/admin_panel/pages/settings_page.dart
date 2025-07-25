import 'package:flutter/material.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/side_menu.dart';
import '../../features/settings/themes/app_themes.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _lowStockAlerts = true;
  int _lowStockThreshold = 5;

  bool _emailNotif = true;
  bool _orderNotif = true;

  String _language = 'English';

  final _thresholdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _thresholdCtrl.text = _lowStockThreshold.toString();
  }

  @override
  void dispose() {
    _thresholdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(selected: 'Settings'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Тохиргоо'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Бүтээгдэхүүн бүртгэл',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        _buildSwitchTile(
                          title: 'бага нөөц алэрт',
                          subtitle:
                              'Бүтээгдэхүүний нөөц бага байх үед анхааруулах',
                          value: _lowStockAlerts,
                          onChanged: (v) => setState(() => _lowStockAlerts = v),
                        ),
                        const SizedBox(height: 12),
                        _buildNumberField(
                          label: 'бага нөөц босго',
                          controller: _thresholdCtrl,
                          onChanged: (v) => setState(() {
                            _lowStockThreshold =
                                int.tryParse(v) ?? _lowStockThreshold;
                          }),
                        ),
                        const SizedBox(height: 32),
                        const Text('Мэдэгдэл тохируулалт',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        _buildSwitchTile(
                          title: 'Имэйл мэдэгдэл',
                          subtitle: 'Үнэлгээний талаар мэдэглэл авах',
                          value: _emailNotif,
                          onChanged: (v) => setState(() => _emailNotif = v),
                        ),
                        const SizedBox(height: 12),
                        _buildSwitchTile(
                          title: 'Захиалгын мэдэгдэл',
                          subtitle: 'Шинэ захиалгын талаар мэдэглэл авах',
                          value: _orderNotif,
                          onChanged: (v) => setState(() => _orderNotif = v),
                        ),
                        const SizedBox(height: 32),
                        const Text('Language',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        DropdownButton<String>(
                          value: _language,
                          items: const [
                            DropdownMenuItem(
                                value: 'English', child: Text('Англи')),
                            DropdownMenuItem(
                                value: 'Mongolian', child: Text('Монгол')),
                          ],
                          onChanged: (v) => setState(() => _language = v!),
                        ),
                        const SizedBox(height: 48),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Persist settings to Firestore later on
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Тохируулалт хадгалагдлаа')));
                            },
                            child: const Text('Хадгалах'),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
      {required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildNumberField(
      {required String label,
      required TextEditingController controller,
      required ValueChanged<String> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        SizedBox(
          width: 120,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                isDense: true, border: OutlineInputBorder()),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
