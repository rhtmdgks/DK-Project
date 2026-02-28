# Android App Bundle(AAB) 내보내기 가이드

Play Store에 LAON 앱을 올리기 위해 App Bundle을 빌드하는 방법입니다.

## 1. 업로드 키스토어 만들기 (최초 1회)

아직 키스토어가 없다면 터미널에서 다음을 실행하세요. **비밀번호와 alias는 안전한 곳에 보관**하세요.

```bash
cd android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- `upload-keystore.jks`: 키스토어 파일 이름 (원하면 변경 가능)
- `upload`: key alias (원하면 변경 가능)
- 프롬프트에 따라 비밀번호, 이름, 조직 등을 입력합니다.

생성된 `upload-keystore.jks` 파일은 **반드시 백업**하고, Git 등에 올리지 마세요.

## 2. key.properties 설정

1. `android/key.properties.example` 을 복사해 `android/key.properties` 를 만듭니다.

   ```bash
   cp android/key.properties.example android/key.properties
   ```

2. `android/key.properties` 를 열어 실제 값으로 수정합니다.

   ```properties
   storePassword=키스토어_비밀번호
   keyPassword=키_비밀번호
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```

   - `storeFile`: `android/` 폴더 기준 경로. 키스토어를 `android/` 안에 두었다면 `upload-keystore.jks` 만 적으면 됩니다.
   - `key.properties` 와 `*.jks` 파일은 **절대 커밋하지 마세요.** (이미 `.gitignore` 에 포함됨)

## 3. App Bundle 빌드

프로젝트 루트에서:

```bash
flutter clean
flutter pub get
flutter build appbundle
```

빌드가 끝나면 다음 파일이 생성됩니다.

- **경로:** `build/app/outputs/bundle/release/app-release.aab`

이 `.aab` 파일을 Google Play Console에 업로드하면 됩니다.

## 4. (선택) 버전 올리기

`pubspec.yaml` 의 `version` 을 수정하면 버전이 반영됩니다.

```yaml
version: 1.0.0+1   # 1.0.0 = versionName, 1 = versionCode
```

Play Store에 올릴 때마다 `versionCode`(+ 뒤 숫자)는 이전보다 커야 하므로, 배포할 때마다 예: `1.0.0+2` 처럼 올려주세요.

## 5. key.properties 없이 빌드할 때

`key.properties` 를 만들지 않으면 release 빌드도 **debug 키**로 서명됩니다.  
실제 배포용으로는 반드시 위 1~2단계대로 업로드 키스토어와 `key.properties` 를 설정한 뒤 빌드하세요.

## 요약

| 단계 | 내용 |
|------|------|
| 1 | `android/` 에서 `keytool` 로 `upload-keystore.jks` 생성 |
| 2 | `android/key.properties` 생성 후 비밀번호·alias·storeFile 입력 |
| 3 | `flutter build appbundle` 실행 |
| 4 | `build/app/outputs/bundle/release/app-release.aab` 를 Play Console에 업로드 |
