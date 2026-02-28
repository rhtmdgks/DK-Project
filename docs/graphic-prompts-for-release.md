# 앱 출시용 그래픽 제작 프롬프트 (Gemini Nanobanana)

아래 프롬프트를 **Gemini의 Nanobanana**에 그대로 복사해 넣고, 필요한 에셋별로 이미지를 생성하세요.

---

## 1. 앱·브랜드 컨텍스트 (공통 참고용)

생성 전에 참고할 앱 정보입니다. 프롬프트에 이미 반영되어 있지만, 수정할 때 활용하세요.

- **앱 이름**: 라온(LAON)
- **대상**: 대덕고등학교 학생·교직원
- **기능**: 일정, 급식, 공지·설문, 건의, 채팅, 알림
- **톤**: 토스처럼 깔끔·미니멀·신뢰감, 불필요한 장식 없음
- **색감**: 밝은 배경(#F8FAFF 계열), 포인트 블루(#0B66FF), 다크 텍스트(#353E5C)

---

## 2. Feature Graphic (필수) — 1024×500 px

Play Store 상단 배너. **정확한 비율 1024:500**으로 생성하고, 필요 시 나중에 1024×500 px로 리사이즈하세요.

### 프롬프트 (영문, Nanobanana용)

```
Create a Google Play Store feature graphic image for a Korean high school app named "LAON (라온)". The app helps students and teachers check daily schedule, school meals, notices, and surveys in one place.

Style: Clean, minimal, trustworthy. Similar to Toss (토스) app — no clutter, soft light blue background (#F8FAFF), accent blue (#0B66FF). No 3D characters or cartoon. Flat, modern UI-style illustration or abstract shapes only. Optional: simple line art of calendar, meal tray, or document. Leave center or right area clear for app logo or short tagline. Aspect ratio 1024:500 (wide banner). Professional, school-friendly, not childish.
```

### 한글 보조 지시 (스타일만 강조할 때)

```
스타일: 토스 앱처럼 미니멀하고 신뢰감 있는 배너. 밝은 하늘색 배경, 포인트 블루. 3D 캐릭터·캐주얼 일러스트 금지. 플랫한 UI/일러스트 또는 단순 도형만. 1024:500 가로 배너 비율.
```

---

## 3. Feature Graphic 대안 — 카피 포함 버전

배너 안에 슬로건을 넣고 싶을 때 사용. (텍스트는 나중에 디자인 툴로 덮어써도 됨.)

### 프롬프트

```
Wide banner image for a school app store listing, 1024 by 500 pixels. Minimal design: soft light blue background, subtle geometric shapes or very simple icons (calendar, food, megaphone) in light blue and blue (#0B66FF). No people, no 3D. Clean space in the center for the text "학교 생활, 한곳에서" or app name. Style: modern, trustworthy, like Toss or Notion — flat, professional. Korean high school context but visual only, no text in image if possible.
```

---

## 4. 스크린샷용 배경/프레임 (선택)

앱 스크린샷을 감쌀 프레임이나 배경이 필요할 때.

### 프롬프트

```
Minimal frame or background for mobile app screenshot mockup. Single phone frame, white or very light gray background. No decoration. Clean, like Toss or Apple App Store screenshot style. Transparent or simple drop shadow only. 9:16 vertical ratio.
```

---

## 5. 프로모 이미지 (SNS/공지용) — 정사각형

인스타그램·공지용 정사각형 프로모.

### 프롬프트

```
Square promotional image for a Korean school app "LAON". 1080x1080. Clean, minimal: light blue background (#F8FAFF), blue accent (#0B66FF). Simple flat graphics — calendar, meal, notice icon style. No 3D, no characters. Tagline area left clear. Style: Toss-like, professional, school-friendly.
```

---

## 6. 사용 시 체크리스트

- [ ] Feature Graphic는 **1024×500 px**로 최종 저장 (PNG 또는 JPEG).
- [ ] Play Console에서는 **텍스트가 이미지의 20%를 넘지 않도록** 권장됨. 텍스트를 많이 넣었다면 비율 확인.
- [ ] 앱 로고(라온 아이콘)는 별도 에셋이 있으므로, 배너에는 로고를 넣지 않거나 프로젝트의 `assets/images/laon_icon.png`를 합성해 사용.
- [ ] 생성 결과가 비율이 다르면 Figma·포토샵 등에서 **1024×500으로 크롭/리사이즈** 후 업로드.

---

## 7. Nanobanana에 넣는 순서 제안

1. **2번 Feature Graphic** 먼저 생성 → 마음에 들면 1024×500으로 리사이즈해 Play Console에 업로드.
2. 필요 시 **3번(카피 포함)** 또는 **5번(정사각형)** 추가 생성.
3. 스크린샷은 앱을 직접 캡처한 뒤, **4번**으로 만든 프레임에 끼워 넣어도 됨.

이 문서의 프롬프트를 Nanobanana에 복사해 사용하면 됩니다.
