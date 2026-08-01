import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_card.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/domain/models/medication_draft.dart';
import 'package:medremind/data/services/ai_scanner_service.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/theme/tokens.dart';
import 'package:medremind/ui/features/prescriptions/views/prescription_new_screen.dart';

/// Capture a prescription photo and send it to the AI proxy.
/// Ported from `app/prescription/scan.tsx`.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _picker = ImagePicker();

  File? _image;
  bool _busy = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    final t = ref.read(translationsProvider);
    setState(() => _error = null);

    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 2000,
      );
    } catch (_) {
      // A denied camera/photo permission surfaces here; explain instead of
      // appearing to do nothing.
      setState(() => _error = t.t(source == ImageSource.camera
          ? 'permissions.cameraBody'
          : 'permissions.photosBody'));
      return;
    }
    if (file == null) return;

    setState(() {
      _image = File(file!.path);
      _busy = true;
    });

    await _send(File(file.path), t);
  }

  Future<void> _send(File image, Translations t) async {
    final bytes = await image.readAsBytes();
    final result = await const AiScannerApi().scanPrescriptionImage(
      base64Encode(bytes),
      lang: ref.read(appStateProvider).language.name,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.ok) {
      setState(() => _error = t.t(scanErrorMessageKey(result.error!)));
      return;
    }

    if (result.medications.isEmpty && result.rawText.trim().isEmpty) {
      setState(() => _error = t.t('scan.noText'));
      return;
    }

    // Even with nothing parsed we continue: the raw text helps the user type
    // the medications in by hand.
    final drafts =
        result.medications.map(MedicationDraft.fromScan).toList();

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrescriptionNewScreen(
          prefillMedications: drafts,
          prefillDoctor: result.doctorName,
          prefillClinic: result.clinic,
          prefillIssuedDate:
              result.issuedDate.isEmpty ? null : result.issuedDate,
          rawText: result.rawText,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    return AppScreen(
      children: [
        AppHeader(title: t.t('scan.title')),

        AppCard(
          child: Column(
            children: [
              if (_image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Image.file(_image!,
                      height: 220, width: double.infinity, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                        color: AppColors.border,
                        width: 1.5,
                        style: BorderStyle.solid),
                  ),
                  child: const Center(
                    child: Icon(Icons.document_scanner_outlined,
                        size: 48, color: AppColors.textFaint),
                  ),
                ),
              const SizedBox(height: Spacing.md),
              AppText(t.t('scan.instruction'),
                  variant: TextVariant.caption,
                  color: TextColorKey.textMuted,
                  center: true),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        if (_busy) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: Spacing.md),
          AppText(t.t('scan.aiReading'),
              center: true, color: TextColorKey.textMuted),
          const SizedBox(height: Spacing.lg),
        ],

        if (_error != null) ...[
          AppCard(
            tone: CardTone.warn,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_outlined,
                    color: AppColors.warn, size: 20),
                const SizedBox(width: Spacing.md),
                Expanded(child: AppText(_error!)),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
        ],

        AppButton(
          label: _image == null ? t.t('scan.capture') : t.t('scan.retake'),
          size: ButtonSize.lg,
          icon: Icons.photo_camera_outlined,
          disabled: _busy,
          onPressed: () => _pick(ImageSource.camera),
        ),
        const SizedBox(height: Spacing.md),
        AppButton(
          label: t.t('scan.fromGallery'),
          variant: ButtonVariant.secondary,
          icon: Icons.photo_library_outlined,
          disabled: _busy,
          onPressed: () => _pick(ImageSource.gallery),
        ),
        const SizedBox(height: Spacing.lg),

        AppText(t.t('scan.disclaimer'),
            variant: TextVariant.caption,
            color: TextColorKey.textFaint,
            center: true),
      ],
    );
  }
}
