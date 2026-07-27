import type { AppLanguage } from '@/i18n';

const encouragements: Record<AppLanguage, string[]> = {
  vi: [
    'Mỗi liều thuốc đúng giờ là một bước tới sức khỏe tốt hơn.',
    'Bạn đang chăm sóc bản thân rất tốt — hãy tiếp tục nhé!',
    'Sức khỏe là hành trình, không phải đích đến. Cố lên!',
    'Hôm nay uống đủ thuốc, ngày mai khỏe hơn một chút.',
    'Kiên trì nhỏ mỗi ngày tạo nên thay đổi lớn.',
    'Cơ thể bạn sẽ cảm ơn bạn vì sự đều đặn này.',
    'Một ngày mới, một cơ hội để chăm sóc chính mình.',
    'Đừng quên uống đủ nước và nghỉ ngơi nhé.',
  ],
  en: [
    'Every dose on time is a step toward better health.',
    "You're taking great care of yourself — keep it up!",
    'Health is a journey, not a destination. You got this!',
    'Take your meds today, feel a little better tomorrow.',
    'Small consistency every day makes a big difference.',
    'Your body will thank you for this steadiness.',
    'A new day, a new chance to care for yourself.',
    "Don't forget to stay hydrated and rest well.",
  ],
};

/** Deterministic pick by day so the message is stable within a day. */
export function encouragementOfTheDay(lang: AppLanguage, dayIndex: number): string {
  const list = encouragements[lang];
  return list[dayIndex % list.length];
}
