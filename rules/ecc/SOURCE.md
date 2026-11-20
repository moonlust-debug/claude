# ECC rules (고정 사본)

- 출처: https://github.com/affaan-m/ECC `rules/` 전체(21개 팩). 원본 안내문은 `UPSTREAM-README.md`
- 커밋: `ccd8da1a724b7b9baf1b6b711073840f8e143313` (2026-11-19 가져옴)
- 라이선스: MIT (`LICENSE`)

`ecc@ecc` 플러그인은 rules 를 배포하지 못해서 따로 둔다. 원격에서 매번 받지 않고
사본을 고정한 이유는, rules 가 모든 세션의 컨텍스트에 그대로 들어가는 지시문이라
검토하지 않은 변경이 저절로 들어오면 안 되기 때문이다.
갱신하려면 새 커밋의 폴더들을 검토한 뒤 이 폴더를 교체하고 위 커밋 값을 고친다.

## 전역 설치 팩 (18개)
`.claude/hooks/install-ecc-rules.sh` 의 `PACKS` 에 적힌 팩만 세션 시작 때
`~/.claude/rules/ecc/` 로 복사한다. 모두 자기 언어 파일에만 걸려 서로 충돌하지 않는다.

`common` `python` `typescript` `react` `web` `golang` `angular` `cpp` `csharp` `dart`
`fsharp` `java` `kotlin` `perl` `php` `ruby` `rust` `swift`

## 프로젝트별로만 쓰는 팩 (3개 + react-native)
아래 팩은 그 프레임워크가 아닌 프로젝트 파일에도 걸리는 넓은 경로를 쓰거나 다른 팩과
상충해서 `PACKS` 에 넣지 않는다.

| 팩 | 전역에서 뺀 이유 |
|----|----|
| `react-native` | 모든 `**/*.ts`·`**/*.tsx` 에 걸리고 "RN 프로젝트에는 `web/` 을 설치하지 말라"고 명시 |
| `arkts` | HarmonyOS 전용인데 모든 `**/*.ts` 에 걸림 |
| `vue` | `hooks.md` 가 모든 `**/*.ts`·`**/*.tsx` 에 걸리고 "plain `tsc` 를 typecheck 훅으로 쓰지 말라"고 해 일반 TS 와 상충 |
| `nuxt` | `**/pages/**`·`**/middleware/**`·`**/server/**/*.ts` 가 Next.js 등 다른 프로젝트에도 걸림 |

해당 프로젝트에서만 그 프로젝트의 `.claude/rules/` 로 복사해 쓴다(저장소 루트에서 실행).

```bash
mkdir -p <프로젝트>/.claude/rules/ecc
cp -R rules/ecc/<팩> <프로젝트>/.claude/rules/ecc/      # 예: react-native, vue, nuxt(+vue), arkts
```
