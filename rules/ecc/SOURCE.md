# ECC rules (고정 사본)

- 출처: https://github.com/affaan-m/ECC `rules/common`, `rules/python`, `rules/typescript`, `rules/react`
- 커밋: `ccd8da1a724b7b9baf1b6b711073840f8e143313` (2026-11-19 가져옴)
- 라이선스: MIT (`LICENSE`)

`ecc@ecc` 플러그인은 rules 를 배포하지 못해서 따로 둔다. 원격에서 매번 받지 않고
사본을 고정한 이유는, rules 가 모든 세션의 컨텍스트에 그대로 들어가는 지시문이라
검토하지 않은 변경이 저절로 들어오면 안 되기 때문이다.

`.claude/hooks/install-ecc-rules.sh` 가 세션 시작 때 `~/.claude/rules/ecc/` 로 복사한다.
갱신하려면 새 커밋의 `rules/common`·`rules/python`·`rules/typescript`·`rules/react` 를 검토한 뒤 이 폴더를 교체하고
위 커밋 값을 고친다.
