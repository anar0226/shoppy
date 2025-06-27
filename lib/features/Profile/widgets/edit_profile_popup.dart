import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:avii/features/auth/providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void showEditProfilePopup(
    BuildContext context, String userName, String profileImageUrl) {
  File? _pickedImage;
  final picker = ImagePicker();
  final TextEditingController controller =
      TextEditingController(text: userName);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Profile picture
                GestureDetector(
                  onTap: () async {
                    final XFile? img =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (img != null) {
                      setState(() => _pickedImage = File(img.path));
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!)
                        : NetworkImage(profileImageUrl) as ImageProvider,
                  ),
                ),
                const SizedBox(height: 24),
                // Display name field
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Display name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.purple, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => controller.clear(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Info text
                const Text(
                  "Your photo and display name will be shown with content you post to the app.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                // Done button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      final newName = controller.text.trim();
                      final auth = context.read<AuthProvider>();
                      await auth.updateProfile(
                        displayName: newName.isNotEmpty ? newName : null,
                        photo: _pickedImage,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text(
                      'Done',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
