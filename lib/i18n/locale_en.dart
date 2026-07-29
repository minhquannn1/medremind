/// English strings. Ported 1:1 from `src/i18n/locales/en.ts`.
/// Must stay key-for-key in sync with [localeVi] — a test asserts that.
library;

const Map<String, String> localeEn = {
  // common
  'common.appName': 'MedRemind',
  'common.save': 'Save',
  'common.cancel': 'Cancel',
  'common.delete': 'Delete',
  'common.edit': 'Edit',
  'common.add': 'Add',
  'common.next': 'Continue',
  'common.back': 'Back',
  'common.done': 'Done',
  'common.confirm': 'Confirm',
  'common.optional': 'Optional',
  'common.required': 'Required',
  'common.today': 'Today',
  'common.yes': 'Yes',
  'common.no': 'No',
  'common.seeAll': 'See all',
  'common.loading': 'Loading…',
  'common.none': 'None yet',
  'common.saved': 'Saved',
  'common.deleteConfirm': 'Are you sure you want to delete?',
  'common.units.mg': 'mg',
  'common.units.ml': 'ml',
  'common.units.tablet': 'tablet',
  'common.units.day': 'day',
  'common.units.time': 'time',

  // tabs
  'tabs.home': 'Home',
  'tabs.prescriptions': 'Prescriptions',
  'tabs.schedule': 'Schedule',
  'tabs.profile': 'Profile',

  // auth
  'auth.account': 'Account',
  'auth.email': 'Email',
  'auth.password': 'Password',
  'auth.login': 'Log in',
  'auth.signup': 'Sign up',
  'auth.logout': 'Log out',
  'auth.logoutConfirm':
      'Log out of your account? Your data stays saved and is restored when you log back in.',
  'auth.loginSubtitle': 'Log in to keep tracking your medications.',
  'auth.signupSubtitle':
      'Create an account to save and sync your medication profile.',
  'auth.noAccount': "Don't have an account?",
  'auth.haveAccount': 'Already have an account?',
  'auth.errorEmailTaken': 'This email is already registered.',
  'auth.errorInvalidCredentials': 'Wrong email or password.',
  'auth.errorAccountDeleted':
      'This account no longer exists — it was deleted. Please sign up for a new account.',
  'auth.errorWeakPassword': 'Password must be at least 8 characters.',
  'auth.errorMissingFields': 'Please fill in all fields.',
  'auth.errorNetwork':
      'Could not reach the server. Check your connection and try again.',
  'auth.showPassword': 'Show password',
  'auth.hidePassword': 'Hide password',
  'auth.deleteAccount': 'Delete account',
  'auth.deleteAccountConfirmTitle': 'Delete account?',
  'auth.deleteAccountConfirmBody':
      'Your account, on-device medication data, and server backup will be permanently deleted. This cannot be undone.',
  'auth.deleteAccountFinalTitle': 'Are you absolutely sure?',
  'auth.deleteAccountFinalBody':
      'This is the final step. All your data will be lost forever.',
  'auth.deleteAccountError':
      'Could not delete the account. Check your connection and try again.',

  // onboarding
  'onboarding.welcomeTitle': 'Welcome to MedRemind',
  'onboarding.welcomeBody':
      'Track your prescriptions, get reminders on time, and never miss a dose.',
  'onboarding.createProfile': 'Create your profile',
  'onboarding.profileHint': 'This helps personalize reminders and advice.',
  'onboarding.start': 'Get started',
  'onboarding.disclaimer':
      'MedRemind provides reminders and reference information only — it does not diagnose or replace advice from your doctor or pharmacist.',

  // home
  'home.greetingMorning': 'Good morning',
  'home.greetingAfternoon': 'Good afternoon',
  'home.greetingEvening': 'Good evening',
  'home.adherenceTitle': '7-day adherence',
  'home.adherenceCaption': 'doses taken',
  'home.todayDoses': "Today's doses",
  'home.nextDose': 'Next dose',
  'home.noDosesToday': 'No doses today',
  'home.noDosesTodayBody': 'Add a prescription to start getting reminders.',
  'home.allDone': "Great! You've taken all your medicine today 🎉",
  'home.refillAlert': 'Running low',
  'home.upcomingAppointment': 'Upcoming appointment',

  // dose
  'dose.take': 'Take',
  'dose.taken': 'Taken',
  'dose.skip': 'Skip',
  'dose.skipped': 'Skipped',
  'dose.missed': 'Missed',
  'dose.pending': 'Pending',
  'dose.snooze': 'Snooze',
  'dose.takeWith': 'Take with',
  'dose.beforeMeal': 'Before meal',
  'dose.afterMeal': 'After meal',
  'dose.withMeal': 'With meal',
  'dose.anytime': 'Anytime',
  'dose.markedTaken': 'Dose marked as taken',

  // prescriptions
  'prescriptions.title': 'Prescriptions',
  'prescriptions.empty': 'No prescriptions yet',
  'prescriptions.emptyBody':
      "Add one by entering it manually or scanning your doctor's prescription.",
  'prescriptions.addManual': 'Enter manually',
  'prescriptions.scan': 'Scan',
  'prescriptions.new': 'New prescription',
  'prescriptions.doctor': 'Doctor',
  'prescriptions.clinic': 'Clinic / Hospital',
  'prescriptions.issuedDate': 'Date issued',
  'prescriptions.notes': 'Notes',
  'prescriptions.medicineCount': '{{count}} medications',
  'prescriptions.active': 'Active',
  'prescriptions.completed': 'Completed',
  'prescriptions.photo': 'Prescription photo',
  'prescriptions.addPhoto': 'Add photo',
  'prescriptions.medications': 'Medications',
  'prescriptions.addMedication': 'Add medication',
  'prescriptions.savePrescription': 'Save prescription',
  'prescriptions.errorNoMedication':
      'Add at least one medication — enter its name, then save.',
  'prescriptions.errorMissingName': 'Medication {{index}}: name is missing.',
  'prescriptions.errorMissingTime':
      'Medication {{index}} ({{name}}): needs at least one intake time.',

  // medication
  'medication.name': 'Medication name',
  'medication.namePlaceholder': 'e.g. Paracetamol 500mg',
  'medication.form': 'Form',
  'medication.forms.tablet': 'Tablet',
  'medication.forms.capsule': 'Capsule',
  'medication.forms.syrup': 'Syrup',
  'medication.forms.drops': 'Drops',
  'medication.forms.injection': 'Injection',
  'medication.forms.cream': 'Cream',
  'medication.forms.other': 'Other',
  'medication.dosage': 'Dose per intake',
  'medication.dosagePlaceholder': 'e.g. 1 tablet',
  'medication.frequency': 'Times / day',
  'medication.times': 'Times',
  'medication.addTime': 'Add time',
  'medication.duration': 'Days to take',
  'medication.durationHint': 'Leave blank for long-term use',
  'medication.quantity': 'Quantity purchased',
  'medication.quantityRemaining': 'Remaining',
  'medication.relationToMeal': 'When to take',
  'medication.takeWith': 'Take with',
  'medication.takeWithPlaceholder': 'e.g. plenty of water, after eating',
  'medication.info': 'Medication info',
  'medication.notes': 'Other notes',
  'medication.stopAfter': 'Stop after',
  'medication.lowStock': 'Running low ({{count}} left)',
  'medication.outOfStock': 'Out of stock',
  'medication.whatIsItFor': 'What is this medicine for?',
  'medication.aiExplanation': 'Explained by AI',
  'medication.aiDisclaimer':
      "For reference only — not a substitute for your doctor's advice.",
  'medication.explainPrompt':
      'See a simple explanation of what this medicine does and key cautions.',
  'medication.explainAction': 'Explain medicine',
  'medication.explaining': 'Generating explanation…',
  'medication.explainError':
      'Could not generate an explanation. Check your connection and try again.',
  'medication.explainRetry': 'Try again',
  'medication.photo': 'Medicine photo',
  'medication.addPhoto': 'Add medicine photo',

  // schedule
  'schedule.title': 'Schedule',
  'schedule.reviewTitle': 'Review intake times',
  'schedule.reviewHint': 'Adjust the times to fit your daily routine.',
  'schedule.morning': 'Morning',
  'schedule.noon': 'Noon',
  'schedule.evening': 'Evening',
  'schedule.night': 'Night',
  'schedule.noSchedule': 'No schedule yet',

  // profile
  'profile.title': 'Profile',
  'profile.personal': 'Personal info',
  'profile.fullName': 'Full name',
  'profile.dob': 'Date of birth',
  'profile.age': 'Age',
  'profile.gender': 'Gender',
  'profile.genders.male': 'Male',
  'profile.genders.female': 'Female',
  'profile.genders.other': 'Other',
  'profile.height': 'Height',
  'profile.weight': 'Weight',
  'profile.anthropometry': 'Body metrics',
  'profile.medicalHistory': 'Medical history',
  'profile.addCondition': 'Add condition',
  'profile.conditionPlaceholder': 'e.g. Hypertension',
  'profile.allergies': 'Drug allergies',
  'profile.addAllergy': 'Add allergy',
  'profile.allergyPlaceholder': 'e.g. Penicillin',
  'profile.allergySeverity': 'Severity',
  'profile.severities.mild': 'Mild',
  'profile.severities.moderate': 'Moderate',
  'profile.severities.severe': 'Severe',
  'profile.history': 'Medication & visit history',
  'profile.noHistory': 'No history yet',
  'profile.bmi': 'BMI',

  // appointments
  'appointments.title': 'Appointments & refills',
  'appointments.revisit': 'Revisit',
  'appointments.refill': 'Refill',
  'appointments.date': 'Date',
  'appointments.add': 'Add appointment',
  'appointments.upcoming': 'Upcoming',
  'appointments.onThisDay': 'Appointments on this day',
  'appointments.none': 'No appointments',

  // lifestyle
  'lifestyle.title': 'Lifestyle tips',
  'lifestyle.nutrition': 'Nutrition',
  'lifestyle.activity': 'Activity',
  'lifestyle.encouragement': "Today's encouragement",

  // history
  'history.title': 'Medication history',
  'history.subtitle': 'Your dose log for the last 30 days.',
  'history.open': 'View medication history',
  'history.empty': 'No history yet',
  'history.emptyBody':
      'History will appear once you start taking scheduled doses.',

  // doctor
  'doctor.title': 'Connect a doctor',
  'doctor.subtitle':
      'Link with your doctor so they can monitor your adherence and support you better.',
  'doctor.enterCodeTitle': 'Enter pairing code',
  'doctor.enterCodeHint':
      'Enter the code your doctor gave you (format MED-XXXXXX).',
  'doctor.connect': 'Connect',
  'doctor.connectedTo': 'Connected to',
  'doctor.yourDoctor': 'Your doctor',
  'doctor.code': 'Code',
  'doctor.syncNow': 'Sync now',
  'doctor.syncDone': 'Your data was sent to the doctor.',
  'doctor.disconnect': 'Disconnect',
  'doctor.disconnectConfirm':
      'Disconnect from your doctor? Data will no longer be sent.',
  'doctor.invalidCode': 'Invalid code. Please double-check with your doctor.',
  'doctor.networkError':
      'Could not reach the server. Check your connection and try again.',
  'doctor.privacyNote':
      'Only medication adherence and prescription info are shared with the doctor you connect to.',

  // reminders
  'reminders.channelName': 'Medication reminders',
  'reminders.doseTitle': 'Time to take your medicine 💊',
  'reminders.doseBody': '{{medication}} — {{dosage}}',
  'reminders.refillTitle': 'Running low on medicine',
  'reminders.refillBody': '{{medication}} has only {{count}} left. Time to refill.',
  'reminders.appointmentTitle': 'Appointment reminder',
  'reminders.permissionNeeded': 'Notifications needed',
  'reminders.permissionBody':
      'Enable notifications to get medication reminders on time.',
  'reminders.enable': 'Enable notifications',

  // permissions
  'permissions.openSettings': 'Open Settings',
  'permissions.cameraTitle': 'Camera access needed',
  'permissions.cameraBody':
      'MedRemind uses the camera to photograph prescriptions and medicines. Enable it in Settings → MedRemind → Camera.',
  'permissions.photosTitle': 'Photo access needed',
  'permissions.photosBody':
      'MedRemind needs your photo library so you can pick a prescription photo. Enable it in Settings → MedRemind → Photos.',
  'permissions.notificationsTitle': 'Notifications are off',
  'permissions.notificationsBody':
      'Your prescription was saved, but you will NOT get dose reminders. Enable them in Settings → MedRemind → Notifications.',

  // scan
  'scan.title': 'Scan prescription',
  'scan.instruction': 'Place the prescription in the frame and hold steady.',
  'scan.capture': 'Capture',
  'scan.retake': 'Retake',
  'scan.processing': 'Reading prescription…',
  'scan.aiReading': 'AI is reading the prescription…\nThis takes a few seconds.',
  'scan.review': 'Review result',
  'scan.reviewHint': 'Compare with the original and edit if needed.',
  'scan.noText':
      'Could not read the image. Retake more clearly (good light, sharp text) or enter manually.',
  'scan.networkError':
      'Could not reach the server. Check your network/Wi-Fi and retry, or enter manually.',
  'scan.serverError':
      'The server failed to read the prescription. Retry or enter manually.',
  'scan.timeout':
      'Reading took too long. Retry with a clearer photo or enter manually.',
  'scan.ocrUnavailable':
      'Auto-reading is unavailable. You can enter details manually with the photo attached.',
  'scan.noMedsParsed':
      "Couldn't extract medications from the image. Continue to enter manually — the text AI read is shown for reference.",
  'scan.detectedText': 'Text detected from image',
  'scan.detectedTextHint': 'Use it to fill in the medications accurately.',
  'scan.permissionTitle': 'Camera permission needed',
  'scan.permissionBody': 'Allow camera access to scan prescriptions.',
  'scan.grant': 'Grant permission',
  'scan.fromGallery': 'Pick from gallery',
  'scan.disclaimer':
      'AI-read information is for reference only. Always compare with the original prescription and follow your doctor or pharmacist.',

  // settings
  'settings.title': 'Settings',
  'settings.language': 'Language',
  'settings.languageVi': 'Tiếng Việt',
  'settings.languageEn': 'English',
  'settings.notifications': 'Notifications',
  'settings.reminderSound': 'Reminder sound',
  'settings.reminderVibration': 'Reminder vibration',
  'settings.about': 'About',
  'settings.privacyPolicy': 'Privacy policy',
  'settings.support': 'Support & contact',
};
