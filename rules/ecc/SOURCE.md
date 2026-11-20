# ECC rules (고정 사본)

- 출처: https://github.com/affaan-m/ECC `rules/` 전체(22개 팩). 원본 안내문은 `UPSTREAM-README.md`
- 커밋: `ccd8da1a724b7b9baf1b6b711073840f8e143313` (2026-11-19 가져옴)
- 라이선스: MIT (`LICENSE`)

`ecc@ecc` 플러그인은 rules 를 배포하지 못해서 따로 둔다. 원격에서 매번 받지 않고
사본을 고정한 이유는, rules 가 모든 세션의 컨텍스트에 그대로 들어가는 지시문이라
검토하지 않은 변경이 저절로 들어오면 안 되기 때문이다.
갱신하려면 새 커밋의 폴더들을 검토한 뒤 이 폴더를 교체하고 위 커밋 값을 고친다.

## 전역 설치 팩 (22개, 전부)
`.claude/hooks/install-ecc-rules.sh` 의 `PACKS` 에 적힌 팩만 세션 시작 때
`~/.claude/rules/ecc/` 로 복사한다.

`common` `python` `typescript` `react` `web` `golang` `angular` `cpp` `csharp` `dart`
`fsharp` `java` `kotlin` `perl` `php` `ruby` `rust` `swift` `vue` `nuxt` `react-native` `arkts`

`vue`·`nuxt`·`react-native`·`arkts` 는 다른 프로젝트 파일에도 걸리지만 사용자 요청(2026-11-20)으로 전역에 둔다.
알려진 영향:
- `vue/hooks.md` 가 모든 `*.ts`·`*.tsx` 에 걸리고 "plain `tsc` 대신 `vue-tsc`" 를 권한다.
  Vue 가 아닌 TS 프로젝트에서는 이 지시를 무시하고 프로젝트의 기존 typecheck 를 따른다.
- `nuxt` 의 `**/pages/**`·`**/middleware/**`·`**/server/**/*.ts` 가 Next.js 등에도 걸린다.
  Nuxt 가 아닌 프로젝트에서는 `useFetch` 등 Nuxt 전용 지시를 적용하지 않는다.
- `react-native` 는 모든 `*.ts`·`*.tsx` 에 걸리고 "RN 프로젝트에는 `web/` 을 쓰지 말라"고 한다.
  RN 이 아닌 프로젝트에서는 Expo·RN 전용 지시를 적용하지 않고, RN 프로젝트에서는 `web/` 지시를 무시한다.
- `arkts` 는 모든 `*.ts` 에 걸린다. HarmonyOS(`*.ets`, `oh-package.json5`) 프로젝트가 아니면 적용하지 않는다.
- 언어별 규칙과 충돌하면 원본 README 대로 더 구체적인 쪽(해당 프로젝트 스택)을 따른다.
