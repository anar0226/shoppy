import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/address_provider.dart';
import '../models/address_model.dart';
import 'add_edit_address_page.dart';

class ManageAddressesPage extends StatelessWidget {
  const ManageAddressesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Addresses'),
        centerTitle: true,
      ),
      body: Consumer<AddressProvider>(
        builder: (_, provider, __) {
          if (provider.addresses.isEmpty) {
            // redirect to add
            Future.microtask(() => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => AddEditAddressPage())));
            return const SizedBox.shrink();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) {
              final addr = provider.addresses[i];
              return ListTile(
                title: Text('${addr.firstName} ${addr.lastName}'),
                subtitle:
                    Text('${addr.line1} ${addr.apartment}\n${addr.phone}'),
                isThreeLine: true,
                leading: Radio<String>(
                  value: addr.id,
                  groupValue: provider.defaultAddressId,
                  onChanged: (val) {
                    if (val != null) {
                      provider.setDefaultAddress(val);
                    }
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditAddressPage(address: addr),
                    ),
                  );
                },
              );
            },
            separatorBuilder: (_, __) => const Divider(),
            itemCount: provider.addresses.length,
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ElevatedButton(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => AddEditAddressPage())),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
          child: const Text('Add new address'),
        ),
      ),
    );
  }
}
