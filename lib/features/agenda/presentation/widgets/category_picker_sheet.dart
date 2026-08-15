import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/custom_text_field.dart';
import 'package:bussola/core/components/primary_button.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/core/utils/color_parsing.dart';
import 'package:bussola/features/agenda/presentation/providers/category_provider.dart';
import 'package:bussola/features/agenda/presentation/widgets/category_chip.dart';

/// Paleta e ícones fixos para categorias personalizadas — mantém a
/// criação rápida (sem um color-picker complexo) e alinhada ao Design System.
const _paletaCores = ['#2563EB', '#10B981', '#EF4444', '#F59E0B', '#A855F7', '#0EA5E9', '#14B8A6', '#F97316'];
const _paletaIcones = ['📌', '🎯', '🧩', '🎨', '🐾', '🎵', '🧘', '💡'];

/// Modal para escolher a categoria de um evento — lista as categorias do
/// usuário como chips e permite criar uma personalizada na hora.
class CategoryPickerSheet extends ConsumerStatefulWidget {
  final String userId;
  final String? selectedCategoryId;

  const CategoryPickerSheet({super.key, required this.userId, this.selectedCategoryId});

  static Future<String?> show(BuildContext context, {required String userId, String? selectedCategoryId}) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryPickerSheet(userId: userId, selectedCategoryId: selectedCategoryId),
    );
  }

  @override
  ConsumerState<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<CategoryPickerSheet> {
  bool _criandoNova = false;
  final _nameController = TextEditingController();
  String _corEscolhida = _paletaCores.first;
  String _iconeEscolhido = _paletaIcones.first;
  bool _salvando = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _salvarNovaCategoria() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _salvando = true);
    final sucesso = await ref.read(categoryNotifierProvider.notifier).createCustom(
          userId: widget.userId,
          name: _nameController.text.trim(),
          icon: _iconeEscolhido,
          color: _corEscolhida,
        );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (sucesso) {
      final novaLista = ref.read(categoryNotifierProvider).categories;
      final criada = novaLista.where((c) => c.name == _nameController.text.trim()).lastOrNull;
      Navigator.of(context).pop(criada?.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(categoryNotifierProvider).errorMessage ?? 'Não foi possível criar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = ref.watch(categoryNotifierProvider).categories;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(_criandoNova ? 'Nova categoria' : 'Categoria', style: AppTextStyles.heading2),
          const SizedBox(height: 16),
          if (!_criandoNova) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categorias
                  .map((c) => CategoryChip(
                        category: c,
                        selected: c.id == widget.selectedCategoryId,
                        onTap: () => Navigator.of(context).pop(c.id),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => setState(() => _criandoNova = true),
              icon: const Icon(Icons.add),
              label: const Text('Criar categoria personalizada'),
            ),
          ] else ...[
            CustomTextField(label: 'Nome da categoria', controller: _nameController),
            const SizedBox(height: 16),
            Text('Cor', style: AppTextStyles.bodyMuted),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _paletaCores.map((hex) {
                final cor = hexToColor(hex);
                final selecionada = hex == _corEscolhida;
                return GestureDetector(
                  onTap: () => setState(() => _corEscolhida = hex),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cor,
                      shape: BoxShape.circle,
                      border: selecionada ? Border.all(color: Colors.black54, width: 2) : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Ícone', style: AppTextStyles.bodyMuted),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _paletaIcones.map((emoji) {
                final selecionado = emoji == _iconeEscolhido;
                return GestureDetector(
                  onTap: () => setState(() => _iconeEscolhido = emoji),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selecionado ? AppColors.backgroundLight : null,
                      shape: BoxShape.circle,
                      border: Border.all(color: selecionado ? AppColors.primary : Colors.black12),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 16)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Criar categoria', isLoading: _salvando, onPressed: _salvarNovaCategoria),
          ],
        ],
      ),
    );
  }
}

extension _LastOrNull<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
