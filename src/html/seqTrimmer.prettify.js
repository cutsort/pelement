PR['registerLangHandler'](
    PR['createSimpleLexer'](
        [
          [PR['PR_COMMENT'], /^[^>]*|[^<]*$/i]
        ], 
        [
          [PR['PR_KEYWORD'], />[^<]*</i]
        ]),
    ['seqTrimmer']);

