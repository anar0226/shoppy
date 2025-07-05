import 'package:flutter/material.dart';
import '../services/simple_recommendation_service.dart';

class PreferencesDialog extends StatefulWidget {
  const PreferencesDialog({Key? key}) : super(key: key);

  @override
  State<PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<PreferencesDialog> {
  String? selectedShoppingFor;
  final Set<String> selectedInterests = {};
  bool isLoading = false;

  final List<String> shoppingOptions = ['men', 'women', 'both'];

  final List<String> interestOptions = [
    'Цахилгаан бараа',
    'Хувцас хунар',
    'Гоо сайхан',
    'Спорт',
    'Гэр ахуй',
    'Тоглоом',
    'Хоол хүнс',
    'Эрүүл мэнд',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person, color: Colors.blue, size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Бид танд таалагдаж магадгүй дэлгүүрүүдийг санал болгох болно',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Таны дуртай дэлгүүрүүдийг харуулахад тусална уу',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Shopping for section
            const Text(
              'Өөрийнхөө сонирхсон ангиллыг сонгоно уу:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: shoppingOptions.map((option) {
                final isSelected = selectedShoppingFor == option;
                return ChoiceChip(
                  label: Text(_getShoppingLabel(option)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      selectedShoppingFor = selected ? option : null;
                    });
                  },
                  selectedColor: Colors.blue.shade100,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.blue.shade800 : Colors.grey[700],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Interests section
            const Text(
              'Өөрийнхөө сонирхсон ангиллыг сонгоно уу:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: interestOptions.map((interest) {
                final isSelected = selectedInterests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedInterests.add(interest);
                      } else {
                        selectedInterests.remove(interest);
                      }
                    });
                  },
                  selectedColor: Colors.green.shade100,
                  labelStyle: TextStyle(
                    color:
                        isSelected ? Colors.green.shade800 : Colors.grey[700],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.of(context).pop(false);
                        },
                  child: const Text('Алгасах'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isLoading || !_canSave() ? null : _savePreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Хадгалах'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getShoppingLabel(String option) {
    switch (option) {
      case 'men':
        return 'Эрэгтэйчүүдийн бараа';
      case 'women':
        return 'Эмэгтэйчүүдийн бараа';
      case 'both':
        return 'Хоёулаа';
      default:
        return option;
    }
  }

  bool _canSave() {
    return selectedShoppingFor != null || selectedInterests.isNotEmpty;
  }

  Future<void> _savePreferences() async {
    setState(() {
      isLoading = true;
    });

    try {
      final recommendationService = SimpleRecommendationService();
      await recommendationService.createInitialPreferences(
        shoppingFor: selectedShoppingFor ?? 'both',
        interests: selectedInterests.toList(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Тохиргоо хадгалахад алдаа гарлаа: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}
