# ECC rules (고정 사본)

- 출처: https://github.com/affaan-m/ECC `rules/common`, `rules/python`, `rules/typescript`, `rules/react`, `rules/web`, `rules/react-native`
- 커밋: `ccd8da1a724b7b9baf1b6b711073840f8e143313` (2026-11-19 가져옴)
- 라이선스: MIT (`LICENSE`)

`ecc@ecc` 플러그인은 rules 를 배포하지 못해서 따로 둔다. 원격에서 매번 받지 않고
사본을 고정한 이유는, rules 가 모든 세션의 컨텍스트에 그대로 들어가는 지시문이라
검토하지 않은 변경이 저절로 들어오면 안 되기 때문이다.

`.claude/hooks/install-ecc-rules.sh` 가 세션 시작 때 `PACKS` 에 적힌 팩
(`common`·`python`·`typescript`·`react`·`web`)만 `~/.claude/rules/ecc/` 로 복사한다.
갱신하려면 새 커밋의 해당 폴더들을 검토한 뒤 이 폴더를 교체하고 위 커밋 값을 고친다.

## react-native 는 전역 설치 제외
`react-native/` 는 모든 `**/*.ts`·`**/*.tsx` 에 걸리고, 본문에 "RN 프로젝트에는
`web/` 을 설치하지 말라"고 적혀 있다. 전역에 두면 일반 웹·TS 프로젝트에도 RN 규칙이
붙고 `web/` 과 충돌하므로 `PACKS` 에 넣지 않는다. RN 프로젝트에서만 그 프로젝트의
`.claude/rules/` 로 복사해 쓴다.

```bash
mkdir -p <RN프로젝트>/.claude/rules/ecc
cp -R rules/ecc/react-native <RN프로젝트>/.claude/rules/ecc/
```
