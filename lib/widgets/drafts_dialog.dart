import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/draft_provider.dart';
import '../providers/cart_provider.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';

class DraftsDialog extends StatelessWidget {
  const DraftsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          const Icon(Icons.history, color: AppColors.primary),
          const SizedBox(width: 10),
          Text('Pesanan Tertunda', style: AppTextStyles.heading3),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Consumer<DraftProvider>(
          builder: (context, draftProv, _) {
            if (draftProv.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (draftProv.drafts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Tidak ada pesanan tertunda'),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: draftProv.drafts.length,
              itemBuilder: (context, index) {
                final draft = draftProv.drafts[index];
                return Card(
                  color: AppColors.card,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      '#${draft.draftNumber} - ${draft.isTakeAway ? 'Dibawa Pulang' : 'Meja ${draft.tableNumber}'}',
                      style: AppTextStyles.subtitle,
                    ),
                    subtitle: Text(
                      '${draft.totalQuantity} item • ${AppFormatter.formatRupiah(draft.total)}',
                      style: AppTextStyles.caption,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          onPressed: () => draftProv.deleteDraft(draft.id),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      final cartProv = Provider.of<CartProvider>(context, listen: false);
                      cartProv.loadDraft(draft);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
