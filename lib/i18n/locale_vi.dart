/// Vietnamese strings. Ported 1:1 from `src/i18n/locales/vi.ts`.
/// Flattened to dotted keys so lookups read the same as the RN `t()` calls:
/// `t('common.save')`, `t('medication.forms.tablet')`.
library;

const Map<String, String> localeVi = {
  // common
  'common.appName': 'MedRemind',
  'common.save': 'Lưu',
  'common.cancel': 'Hủy',
  'common.delete': 'Xóa',
  'common.edit': 'Sửa',
  'common.add': 'Thêm',
  'common.next': 'Tiếp tục',
  'common.back': 'Quay lại',
  'common.done': 'Xong',
  'common.confirm': 'Xác nhận',
  'common.optional': 'Không bắt buộc',
  'common.required': 'Bắt buộc',
  'common.today': 'Hôm nay',
  'common.yes': 'Có',
  'common.no': 'Không',
  'common.seeAll': 'Xem tất cả',
  'common.loading': 'Đang tải…',
  'common.none': 'Chưa có',
  'common.saved': 'Đã lưu',
  'common.deleteConfirm': 'Bạn chắc chắn muốn xóa?',
  'common.units.mg': 'mg',
  'common.units.ml': 'ml',
  'common.units.tablet': 'viên',
  'common.units.day': 'ngày',
  'common.units.time': 'lần',

  // tabs
  'tabs.home': 'Trang chủ',
  'tabs.prescriptions': 'Đơn thuốc',
  'tabs.schedule': 'Lịch',
  'tabs.profile': 'Hồ sơ',

  // auth
  'auth.account': 'Tài khoản',
  'auth.email': 'Email',
  'auth.emailPlaceholder': 'ban@example.com',
  'auth.namePlaceholder': 'Nguyễn Văn A',
  'auth.password': 'Mật khẩu',
  'auth.passwordPlaceholder': 'Nhập mật khẩu',
  'auth.login': 'Đăng nhập',
  'auth.signup': 'Đăng ký',
  'auth.logout': 'Đăng xuất',
  'auth.logoutConfirm':
      'Đăng xuất khỏi tài khoản? Dữ liệu vẫn được lưu và khôi phục khi bạn đăng nhập lại.',
  'auth.loginSubtitle': 'Đăng nhập để tiếp tục theo dõi thuốc của bạn.',
  'auth.signupSubtitle': 'Tạo tài khoản để lưu và đồng bộ hồ sơ thuốc của bạn.',
  'auth.noAccount': 'Chưa có tài khoản?',
  'auth.haveAccount': 'Đã có tài khoản?',
  'auth.errorEmailTaken': 'Email này đã được đăng ký.',
  'auth.errorInvalidCredentials': 'Sai email hoặc mật khẩu.',
  'auth.errorAccountDeleted':
      'Tài khoản này không tồn tại — tài khoản đã bị xóa. Vui lòng đăng ký tài khoản mới.',
  'auth.errorWeakPassword': 'Mật khẩu cần ít nhất 8 ký tự.',
  'auth.errorMissingFields': 'Vui lòng điền đầy đủ thông tin.',
  'auth.errorNetwork': 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
  'auth.showPassword': 'Hiện mật khẩu',
  'auth.hidePassword': 'Ẩn mật khẩu',
  'auth.deleteAccount': 'Xóa tài khoản',
  'auth.deleteAccountConfirmTitle': 'Xóa tài khoản?',
  'auth.deleteAccountConfirmBody':
      'Tài khoản, dữ liệu thuốc trên máy và bản sao lưu trên máy chủ sẽ bị xóa vĩnh viễn. Không thể hoàn tác.',
  'auth.deleteAccountFinalTitle': 'Bạn chắc chắn chứ?',
  'auth.deleteAccountFinalBody':
      'Đây là bước cuối cùng. Toàn bộ dữ liệu sẽ mất vĩnh viễn.',
  'auth.deleteAccountError':
      'Không xóa được tài khoản. Kiểm tra mạng rồi thử lại.',

  // onboarding
  'onboarding.welcomeTitle': 'Chào mừng đến với MedRemind',
  'onboarding.welcomeBody':
      'Theo dõi đơn thuốc, nhắc bạn uống đúng giờ và không bỏ lỡ liều nào.',
  'onboarding.createProfile': 'Tạo hồ sơ của bạn',
  'onboarding.profileHint':
      'Thông tin này giúp cá nhân hóa nhắc nhở và lời khuyên.',
  'onboarding.start': 'Bắt đầu',
  'onboarding.disclaimer':
      'MedRemind chỉ hỗ trợ nhắc lịch và cung cấp thông tin tham khảo — không chẩn đoán hay thay thế tư vấn của bác sĩ, dược sĩ.',

  // home
  'home.greetingMorning': 'Chào buổi sáng',
  'home.greetingAfternoon': 'Chào buổi chiều',
  'home.greetingEvening': 'Chào buổi tối',
  'home.adherenceTitle': 'Tuân thủ 7 ngày',
  'home.adherenceCaption': 'liều đã uống',
  'home.todayDoses': 'Liều hôm nay',
  'home.nextDose': 'Liều kế tiếp',
  'home.noDosesToday': 'Hôm nay không có liều nào',
  'home.noDosesTodayBody': 'Thêm đơn thuốc để bắt đầu nhận nhắc nhở.',
  'home.allDone': 'Tuyệt vời! Bạn đã uống đủ thuốc hôm nay 🎉',
  'home.refillAlert': 'Sắp hết thuốc',
  'home.upcomingAppointment': 'Lịch tái khám sắp tới',

  // dose
  'dose.take': 'Đã uống',
  'dose.taken': 'Đã uống',
  'dose.skip': 'Bỏ qua',
  'dose.skipped': 'Đã bỏ qua',
  'dose.missed': 'Bỏ lỡ',
  'dose.pending': 'Chờ uống',
  'dose.snooze': 'Báo lại',
  'dose.takeWith': 'Uống cùng',
  'dose.beforeMeal': 'Trước ăn',
  'dose.afterMeal': 'Sau ăn',
  'dose.withMeal': 'Trong bữa ăn',
  'dose.anytime': 'Bất kỳ lúc nào',
  'dose.markedTaken': 'Đã ghi nhận uống thuốc',

  // prescriptions
  'prescriptions.title': 'Đơn thuốc',
  'prescriptions.empty': 'Chưa có đơn thuốc',
  'prescriptions.emptyBody':
      'Thêm đơn bằng cách nhập tay hoặc quét ảnh đơn của bác sĩ.',
  'prescriptions.addManual': 'Nhập tay',
  'prescriptions.scan': 'Quét đơn',
  'prescriptions.new': 'Đơn thuốc mới',
  'prescriptions.doctor': 'Bác sĩ',
  'prescriptions.clinic': 'Phòng khám / Bệnh viện',
  'prescriptions.issuedDate': 'Ngày kê đơn',
  'prescriptions.notes': 'Ghi chú',
  'prescriptions.medicineCount': '{{count}} loại thuốc',
  'prescriptions.active': 'Đang dùng',
  'prescriptions.completed': 'Đã hoàn thành',
  'prescriptions.photo': 'Ảnh đơn thuốc',
  'prescriptions.addPhoto': 'Thêm ảnh đơn',
  'prescriptions.medications': 'Danh sách thuốc',
  'prescriptions.addMedication': 'Thêm thuốc',
  'prescriptions.savePrescription': 'Lưu đơn thuốc',
  'prescriptions.errorNoMedication':
      'Cần ít nhất một loại thuốc. Nhập tên thuốc rồi lưu lại.',
  'prescriptions.errorMissingName': 'Thuốc {{index}}: chưa nhập tên thuốc.',
  'prescriptions.errorMissingTime':
      'Thuốc {{index}} ({{name}}): cần ít nhất một giờ uống.',

  // medication
  'medication.name': 'Tên thuốc',
  'medication.namePlaceholder': 'VD: Paracetamol 500mg',
  'medication.form': 'Dạng thuốc',
  'medication.forms.tablet': 'Viên nén',
  'medication.forms.capsule': 'Viên nang',
  'medication.forms.syrup': 'Siro',
  'medication.forms.drops': 'Thuốc nhỏ',
  'medication.forms.injection': 'Tiêm',
  'medication.forms.cream': 'Bôi',
  'medication.forms.other': 'Khác',
  'medication.dosage': 'Liều mỗi lần',
  'medication.dosagePlaceholder': 'VD: 1 viên',
  'medication.frequency': 'Số lần / ngày',
  'medication.times': 'Giờ uống',
  'medication.addTime': 'Thêm giờ',
  'medication.duration': 'Số ngày dùng',
  'medication.durationHint': 'Để trống nếu dùng lâu dài',
  'medication.quantity': 'Số lượng đã mua',
  'medication.quantityRemaining': 'Còn lại',
  'medication.relationToMeal': 'Thời điểm uống',
  'medication.takeWith': 'Uống với',
  'medication.takeWithPlaceholder': 'VD: nhiều nước, sau khi ăn',
  'medication.info': 'Thông tin thuốc',
  'medication.notes': 'Lưu ý khác',
  'medication.stopAfter': 'Ngừng sau',
  'medication.lowStock': 'Sắp hết ({{count}} còn lại)',
  'medication.outOfStock': 'Đã hết thuốc',
  'medication.whatIsItFor': 'Thuốc này dùng để làm gì?',
  'medication.aiExplanation': 'Giải thích bởi AI',
  'medication.aiDisclaimer':
      'Thông tin tham khảo, không thay thế tư vấn của bác sĩ.',
  'medication.explainPrompt':
      'Xem giải thích dễ hiểu về công dụng và lưu ý của thuốc này.',
  'medication.explainAction': 'Giải thích thuốc',
  'medication.explaining': 'Đang tạo giải thích…',
  'medication.explainError':
      'Không tạo được giải thích. Kiểm tra kết nối và thử lại.',
  'medication.explainRetry': 'Thử lại',
  'medication.photo': 'Ảnh thuốc',
  'medication.addPhoto': 'Thêm ảnh thuốc',

  // schedule
  'schedule.title': 'Lịch',
  'schedule.reviewTitle': 'Kiểm tra giờ uống',
  'schedule.reviewHint':
      'Điều chỉnh giờ uống cho phù hợp với sinh hoạt của bạn.',
  'schedule.morning': 'Sáng',
  'schedule.noon': 'Trưa',
  'schedule.evening': 'Chiều',
  'schedule.night': 'Tối',
  'schedule.noSchedule': 'Chưa có lịch uống',

  // profile
  'profile.title': 'Hồ sơ',
  'profile.personal': 'Thông tin cá nhân',
  'profile.fullName': 'Họ và tên',
  'profile.dob': 'Ngày sinh',
  'profile.age': 'Tuổi',
  'profile.gender': 'Giới tính',
  'profile.genders.male': 'Nam',
  'profile.genders.female': 'Nữ',
  'profile.genders.other': 'Khác',
  'profile.height': 'Chiều cao',
  'profile.weight': 'Cân nặng',
  'profile.anthropometry': 'Nhân trắc học',
  'profile.medicalHistory': 'Tiền sử bệnh',
  'profile.addCondition': 'Thêm bệnh',
  'profile.conditionPlaceholder': 'VD: Tăng huyết áp',
  'profile.allergies': 'Dị ứng thuốc',
  'profile.addAllergy': 'Thêm dị ứng',
  'profile.allergyPlaceholder': 'VD: Penicillin',
  'profile.allergySeverity': 'Mức độ',
  'profile.severities.mild': 'Nhẹ',
  'profile.severities.moderate': 'Vừa',
  'profile.severities.severe': 'Nặng',
  'profile.history': 'Lịch sử dùng thuốc & tái khám',
  'profile.noHistory': 'Chưa có lịch sử',
  'profile.bmi': 'BMI',

  // appointments
  'appointments.title': 'Tái khám & mua thuốc',
  'appointments.revisit': 'Tái khám',
  'appointments.refill': 'Mua thuốc',
  'appointments.date': 'Ngày',
  'appointments.add': 'Thêm lịch hẹn',
  'appointments.upcoming': 'Sắp tới',
  'appointments.onThisDay': 'Lịch hẹn ngày này',
  'appointments.none': 'Chưa có lịch hẹn',

  // lifestyle
  'lifestyle.title': 'Lời khuyên sinh hoạt',
  'lifestyle.nutrition': 'Dinh dưỡng',
  'lifestyle.activity': 'Vận động',
  'lifestyle.encouragement': 'Lời động viên hôm nay',

  // history
  'history.title': 'Lịch sử uống thuốc',
  'history.subtitle': 'Nhật ký uống thuốc 30 ngày gần nhất.',
  'history.open': 'Xem lịch sử uống thuốc',
  'history.empty': 'Chưa có lịch sử',
  'history.emptyBody':
      'Lịch sử sẽ xuất hiện sau khi bạn bắt đầu uống thuốc theo lịch.',

  // doctor
  'doctor.title': 'Kết nối bác sĩ',
  'doctor.subtitle':
      'Kết nối với bác sĩ để họ theo dõi việc uống thuốc và hỗ trợ bạn tốt hơn.',
  'doctor.enterCodeTitle': 'Nhập mã ghép nối',
  'doctor.enterCodeHint': 'Nhập mã do bác sĩ cung cấp (dạng MED-XXXXXX).',
  'doctor.connect': 'Kết nối',
  'doctor.connectedTo': 'Đang kết nối với',
  'doctor.yourDoctor': 'Bác sĩ của bạn',
  'doctor.code': 'Mã',
  'doctor.syncNow': 'Đồng bộ ngay',
  'doctor.syncDone': 'Đã gửi dữ liệu cho bác sĩ.',
  'doctor.disconnect': 'Ngắt kết nối',
  'doctor.disconnectConfirm':
      'Ngắt kết nối với bác sĩ? Dữ liệu sẽ không được gửi nữa.',
  'doctor.invalidCode': 'Mã không hợp lệ. Kiểm tra lại với bác sĩ.',
  'doctor.networkError':
      'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
  'doctor.privacyNote':
      'Chỉ thông tin tuân thủ uống thuốc và đơn thuốc được chia sẻ với bác sĩ bạn kết nối.',

  // reminders
  'reminders.channelName': 'Nhắc uống thuốc',
  'reminders.doseTitle': 'Đến giờ uống thuốc 💊',
  'reminders.doseBody': '{{medication}} — {{dosage}}',
  'reminders.refillTitle': 'Sắp hết thuốc',
  'reminders.refillBody': '{{medication}} chỉ còn {{count}}. Hãy mua thêm.',
  'reminders.appointmentTitle': 'Nhắc lịch hẹn',
  'reminders.permissionNeeded': 'Cần quyền thông báo',
  'reminders.permissionBody':
      'Bật thông báo để nhận nhắc nhở uống thuốc đúng giờ.',
  'reminders.enable': 'Bật thông báo',

  // permissions
  'permissions.openSettings': 'Mở Cài đặt',
  'permissions.cameraTitle': 'Cần quyền camera',
  'permissions.cameraBody':
      'MedRemind cần dùng camera để chụp đơn thuốc và ảnh thuốc. Vào Cài đặt → MedRemind → Camera để bật.',
  'permissions.photosTitle': 'Cần quyền ảnh',
  'permissions.photosBody':
      'MedRemind cần truy cập thư viện ảnh để bạn chọn ảnh đơn thuốc. Vào Cài đặt → MedRemind → Ảnh để bật.',
  'permissions.notificationsTitle': 'Thông báo đang tắt',
  'permissions.notificationsBody':
      'Đơn thuốc đã được lưu, nhưng bạn sẽ KHÔNG nhận được nhắc nhở uống thuốc. Vào Cài đặt → MedRemind → Thông báo để bật.',

  // scan
  'scan.title': 'Quét đơn thuốc',
  'scan.instruction': 'Đặt đơn thuốc trong khung và giữ máy ổn định.',
  'scan.capture': 'Chụp',
  'scan.retake': 'Chụp lại',
  'scan.processing': 'Đang đọc đơn thuốc…',
  'scan.aiReading': 'AI đang đọc đơn thuốc…\nVui lòng chờ vài giây.',
  'scan.review': 'Kiểm tra kết quả',
  'scan.reviewHint': 'Đối chiếu với đơn gốc và chỉnh sửa nếu cần.',
  'scan.noText':
      'Không đọc được ảnh. Hãy chụp lại rõ hơn (đủ sáng, chữ nét) hoặc nhập tay.',
  'scan.networkError':
      'Không kết nối được máy chủ. Kiểm tra mạng/Wi-Fi rồi thử lại, hoặc nhập tay.',
  'scan.serverError': 'Máy chủ gặp lỗi khi đọc đơn. Thử lại hoặc nhập tay.',
  'scan.timeout': 'Đọc đơn quá lâu. Thử lại với ảnh rõ hơn hoặc nhập tay.',
  'scan.ocrUnavailable':
      'Tính năng đọc tự động chưa khả dụng. Bạn có thể nhập tay kèm ảnh đơn.',
  'scan.noMedsParsed':
      'Chưa tách được tên thuốc từ ảnh. Tiếp tục để nhập tay — chữ AI đọc được sẽ hiển thị để bạn đối chiếu.',
  'scan.detectedText': 'Chữ đọc được từ ảnh',
  'scan.detectedTextHint': 'Đối chiếu để nhập thuốc cho đúng.',
  'scan.permissionTitle': 'Cần quyền camera',
  'scan.permissionBody': 'Cho phép camera để quét đơn thuốc.',
  'scan.grant': 'Cấp quyền',
  'scan.fromGallery': 'Chọn từ thư viện',
  'scan.disclaimer':
      'Thông tin do AI đọc chỉ để tham khảo. Luôn đối chiếu với đơn gốc và làm theo chỉ định của bác sĩ, dược sĩ.',

  // settings
  'settings.title': 'Cài đặt',
  'settings.language': 'Ngôn ngữ',
  'settings.languageVi': 'Tiếng Việt',
  'settings.languageEn': 'English',
  'settings.notifications': 'Thông báo',
  'settings.reminderSound': 'Âm báo khi nhắc',
  'settings.reminderVibration': 'Rung khi nhắc',
  'settings.about': 'Giới thiệu',
  'settings.privacyPolicy': 'Chính sách quyền riêng tư',
  'settings.support': 'Hỗ trợ & liên hệ',
};
