import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:avii/features/auth/providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void showEditProfilePopup(
    BuildContext context, String userName, String profileImageUrl) {
  File? pickedImage;
  final picker = ImagePicker();
  final TextEditingController controller =
      TextEditingController(text: userName);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white, // White background
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
                      setState(() => pickedImage = File(img.path));
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: pickedImage != null
                        ? FileImage(pickedImage!)
                        : NetworkImage(profileImageUrl) as ImageProvider,
                  ),
                ),
                const SizedBox(height: 24),
                // Display name field
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Display name',
                    labelStyle: const TextStyle(
                        color: Color(0xFF4285F4)), // Primary blue color
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF4285F4)), // Primary blue color
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF4285F4),
                          width: 2), // Primary blue color
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear,
                          color: Color(0xFF4285F4)), // Primary blue color
                      onPressed: () => controller.clear(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Info text
                const Text(
                  "Профайл зургаа эсвэл нэрээ өөрчлөх үү?",
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Color(0xFF4285F4)), // Primary blue color
                ),
                const SizedBox(height: 24),
                // Done button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.grey.shade50, // Light grey background
                      foregroundColor:
                          const Color(0xFF4285F4), // Primary blue color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                            color: Color(0xFF4285F4), width: 1), // Blue outline
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      try {
                        final newName = controller.text.trim();
                        final auth = context.read<AuthProvider>();

                        // Only update if there are actual changes
                        if (newName.isNotEmpty || pickedImage != null) {
                          await auth.updateProfile(
                            displayName: newName.isNotEmpty ? newName : null,
                            photo: pickedImage,
                          );
                        }

                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        // Show error message if update fails
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Профайл шинэчлэхэд алдаа гарлаа: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Хадгалах',
                      style: TextStyle(
                          color: Color(0xFF4285F4),
                          fontSize: 16), // Primary blue color
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
