import type { AppLanguage } from '@/i18n';

export interface LifestyleTip {
  category: 'nutrition' | 'activity';
  text: string;
}

/** Context derived from the patient's own profile, used to personalize tips. */
export interface PatientContext {
  age: number | null;
  bmi: number | null;
  conditions: string[]; // lowercased condition names
  allergies: string[]; // lowercased allergy substances
}

const base: Record<AppLanguage, LifestyleTip[]> = {
  vi: [
    { category: 'nutrition', text: 'Ăn nhiều rau xanh và trái cây tươi mỗi ngày.' },
    { category: 'nutrition', text: 'Hạn chế muối, đường và đồ chiên rán.' },
    { category: 'nutrition', text: 'Uống đủ 1.5–2 lít nước mỗi ngày.' },
    { category: 'nutrition', text: 'Một số thuốc nên uống sau ăn để tránh hại dạ dày.' },
    { category: 'activity', text: 'Đi bộ nhẹ 30 phút mỗi ngày giúp tuần hoàn tốt hơn.' },
    { category: 'activity', text: 'Ngủ đủ 7–8 tiếng để cơ thể hồi phục.' },
    { category: 'activity', text: 'Tái khám đúng hẹn để bác sĩ theo dõi tiến triển.' },
  ],
  en: [
    { category: 'nutrition', text: 'Eat plenty of leafy greens and fresh fruit daily.' },
    { category: 'nutrition', text: 'Limit salt, sugar, and fried foods.' },
    { category: 'nutrition', text: 'Drink 1.5–2 liters of water each day.' },
    { category: 'nutrition', text: 'Some medicines are best taken after meals to protect your stomach.' },
    { category: 'activity', text: 'A gentle 30-minute walk daily improves circulation.' },
    { category: 'activity', text: 'Sleep 7–8 hours so your body can recover.' },
    { category: 'activity', text: 'Keep follow-up visits so your doctor can track progress.' },
  ],
};

// Condition-specific advice. Keys are keyword fragments matched against the
// patient's lowercased condition names (Vietnamese + English synonyms).
interface ConditionRule {
  keywords: string[];
  tips: Record<AppLanguage, LifestyleTip[]>;
}

const conditionRules: ConditionRule[] = [
  {
    keywords: ['huyết áp', 'tăng huyết áp', 'hypertension', 'blood pressure'],
    tips: {
      vi: [
        { category: 'nutrition', text: 'Huyết áp cao: giảm muối dưới 5g/ngày, tránh đồ hộp và nước chấm mặn.' },
        { category: 'activity', text: 'Huyết áp cao: đo huyết áp đều đặn và tránh gắng sức đột ngột.' },
      ],
      en: [
        { category: 'nutrition', text: 'High blood pressure: keep salt under 5g/day; avoid canned and salty sauces.' },
        { category: 'activity', text: 'High blood pressure: measure it regularly and avoid sudden exertion.' },
      ],
    },
  },
  {
    keywords: ['tiểu đường', 'đái tháo đường', 'diabetes', 'blood sugar', 'đường huyết'],
    tips: {
      vi: [
        { category: 'nutrition', text: 'Tiểu đường: hạn chế cơm trắng, bánh kẹo, nước ngọt; chia nhỏ bữa ăn.' },
        { category: 'activity', text: 'Tiểu đường: đi bộ sau ăn 15–20 phút giúp ổn định đường huyết.' },
      ],
      en: [
        { category: 'nutrition', text: 'Diabetes: limit white rice, sweets, and sodas; eat smaller, frequent meals.' },
        { category: 'activity', text: 'Diabetes: a 15–20 min walk after meals helps steady blood sugar.' },
      ],
    },
  },
  {
    keywords: ['dạ dày', 'bao tử', 'gastric', 'stomach', 'ulcer', 'viêm loét'],
    tips: {
      vi: [
        { category: 'nutrition', text: 'Bệnh dạ dày: ăn đúng giờ, tránh cay nóng, cà phê, rượu bia và ăn quá no.' },
      ],
      en: [
        { category: 'nutrition', text: 'Stomach issues: eat on schedule; avoid spicy food, coffee, alcohol, and overeating.' },
      ],
    },
  },
  {
    keywords: ['mỡ máu', 'cholesterol', 'lipid', 'rối loạn lipid'],
    tips: {
      vi: [
        { category: 'nutrition', text: 'Mỡ máu cao: hạn chế mỡ động vật, nội tạng; ưu tiên cá và dầu thực vật.' },
      ],
      en: [
        { category: 'nutrition', text: 'High cholesterol: cut animal fat and organ meats; prefer fish and plant oils.' },
      ],
    },
  },
  {
    keywords: ['tim', 'mạch vành', 'heart', 'cardiac', 'suy tim'],
    tips: {
      vi: [
        { category: 'activity', text: 'Bệnh tim: vận động nhẹ nhàng theo sức, ngừng ngay nếu thấy đau ngực, khó thở.' },
      ],
      en: [
        { category: 'activity', text: 'Heart condition: exercise gently within limits; stop if you feel chest pain or breathlessness.' },
      ],
    },
  },
  {
    keywords: ['thận', 'kidney', 'renal'],
    tips: {
      vi: [
        { category: 'nutrition', text: 'Bệnh thận: hỏi bác sĩ về lượng nước, muối và đạm phù hợp mỗi ngày.' },
      ],
      en: [
        { category: 'nutrition', text: 'Kidney condition: ask your doctor about right daily water, salt, and protein limits.' },
      ],
    },
  },
];

function bmiTip(lang: AppLanguage, bmi: number): LifestyleTip | null {
  if (bmi >= 25) {
    return {
      category: 'activity',
      text:
        lang === 'vi'
          ? `Chỉ số BMI ${bmi.toFixed(1)} hơi cao — tăng vận động và giảm tinh bột giúp cải thiện sức khỏe.`
          : `Your BMI ${bmi.toFixed(1)} is a bit high — more activity and fewer refined carbs will help.`,
    };
  }
  if (bmi < 18.5) {
    return {
      category: 'nutrition',
      text:
        lang === 'vi'
          ? `Chỉ số BMI ${bmi.toFixed(1)} hơi thấp — ăn đủ chất và chia nhiều bữa để lấy lại cân nặng.`
          : `Your BMI ${bmi.toFixed(1)} is a bit low — eat nutritious, frequent meals to regain weight.`,
    };
  }
  return null;
}

function ageTip(lang: AppLanguage, age: number): LifestyleTip | null {
  if (age >= 60) {
    return {
      category: 'activity',
      text:
        lang === 'vi'
          ? 'Tuổi cao: chú ý đi lại chắc chắn tránh té ngã, và uống thuốc đúng giờ mỗi ngày.'
          : 'Older age: move carefully to prevent falls, and take medicines at the same time daily.',
    };
  }
  return null;
}

/**
 * Returns lifestyle tips tailored to the patient. Condition/BMI/age-specific
 * tips are surfaced first, then general tips fill the rest. Falls back to the
 * plain general list when no context is available.
 */
export function getLifestyleTips(lang: AppLanguage, ctx?: PatientContext): LifestyleTip[] {
  if (!ctx) return base[lang];

  const personalized: LifestyleTip[] = [];
  const seen = new Set<string>();
  const push = (tip: LifestyleTip | null) => {
    if (tip && !seen.has(tip.text)) {
      seen.add(tip.text);
      personalized.push(tip);
    }
  };

  for (const rule of conditionRules) {
    const matches = ctx.conditions.some((c) =>
      rule.keywords.some((k) => c.includes(k)),
    );
    if (matches) rule.tips[lang].forEach(push);
  }

  if (ctx.bmi != null) push(bmiTip(lang, ctx.bmi));
  if (ctx.age != null) push(ageTip(lang, ctx.age));

  // Fill up to a reasonable number with general tips.
  for (const tip of base[lang]) {
    if (personalized.length >= 6) break;
    push(tip);
  }

  return personalized;
}
