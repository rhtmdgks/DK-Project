/// 학교 도메인 모델.
///
/// 서버 `schools` 테이블/`list_active_schools()` RPC 응답과
/// SharedPreferences 캐시(jsonEncode 왕복)에 공용으로 사용한다.
class School {
  const School({
    required this.id,
    required this.name,
    required this.slug,
    this.nameEn,
    this.neisAtptCode,
    this.neisSchoolCode,
  });

  /// schools.id (uuid)
  final String id;

  /// 학교 이름 (예: '대구고등학교')
  final String name;

  /// URL/식별용 슬러그 (예: 'daegu-high')
  final String slug;

  /// 영문 이름 (nullable)
  final String? nameEn;

  /// NEIS 시도교육청 코드 (atpt_ofcdc_sc_code, 로그인 후 상세 조회 시에만 존재)
  final String? neisAtptCode;

  /// NEIS 학교 코드 (sd_schul_code, 로그인 후 상세 조회 시에만 존재)
  final String? neisSchoolCode;

  /// 서버 응답/캐시 JSON에서 생성. 모든 키는 null-safe로 처리한다.
  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      nameEn: json['name_en'] as String?,
      neisAtptCode: json['atpt_ofcdc_sc_code'] as String?,
      neisSchoolCode: json['sd_schul_code'] as String?,
    );
  }

  /// SharedPreferences 캐시용 JSON. [School.fromJson]과 대칭.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'name_en': nameEn,
      'atpt_ofcdc_sc_code': neisAtptCode,
      'sd_schul_code': neisSchoolCode,
    };
  }
}
