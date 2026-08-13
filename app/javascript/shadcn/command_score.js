// A port of `cmdk`'s own scorer, vendored at `vendor/cmdk/command-score.ts`
// (MIT, Paco Coursey) — which in turn is a fork of `command-score` by Fabrice
// Weinberg.
//
// It is here rather than replaced with a substring test because the ranking
// *is* the component: a palette that lists "Group Policy" above "Groups" for
// "gp" feels like a palette, and one that filters by `includes` does not. The
// gem's searchable select does filter by substring, and that is the right
// answer there — it filters a list a caller already ordered, and shows it in
// that order.
//
// The weights are upstream's, with its own comments kept: they are the file.
const SCORE_CONTINUE_MATCH = 1
// A new match at the start of a word scores better than a new match elsewhere.
const SCORE_SPACE_WORD_JUMP = 0.9
const SCORE_NON_SPACE_WORD_JUMP = 0.8
// Any other match isn't ideal, but we include it for completeness.
const SCORE_CHARACTER_JUMP = 0.17
// If the user transposed two letters, it should be significantly penalized.
const SCORE_TRANSPOSITION = 0.1
// The goodness of a match should decay slightly with each missing character.
const PENALTY_SKIPPED = 0.999
// An exact-case match is worth slightly more than a case-insensitive one.
const PENALTY_CASE_MISMATCH = 0.9999
// Match higher for letters closer to the beginning of the word.
const PENALTY_NOT_COMPLETE = 0.99

const IS_GAP_REGEXP = /[\\/_+.#"@[({&]/
const COUNT_GAPS_REGEXP = /[\\/_+.#"@[({&]/g
const IS_SPACE_REGEXP = /[\s-]/
const COUNT_SPACE_REGEXP = /[\s-]/g

function commandScoreInner(string, abbreviation, lowerString, lowerAbbreviation, stringIndex, abbreviationIndex, memoisedResults) {
  if (abbreviationIndex === abbreviation.length) {
    return stringIndex === string.length ? SCORE_CONTINUE_MATCH : PENALTY_NOT_COMPLETE
  }

  const memoiseKey = `${stringIndex},${abbreviationIndex}`
  if (memoisedResults[memoiseKey] !== undefined) return memoisedResults[memoiseKey]

  const abbreviationChar = lowerAbbreviation.charAt(abbreviationIndex)
  let index = lowerString.indexOf(abbreviationChar, stringIndex)
  let highScore = 0
  let score, transposedScore, wordBreaks, spaceBreaks

  while (index >= 0) {
    score = commandScoreInner(string, abbreviation, lowerString, lowerAbbreviation, index + 1, abbreviationIndex + 1, memoisedResults)

    if (score > highScore) {
      if (index === stringIndex) {
        score *= SCORE_CONTINUE_MATCH
      } else if (IS_GAP_REGEXP.test(string.charAt(index - 1))) {
        score *= SCORE_NON_SPACE_WORD_JUMP
        wordBreaks = string.slice(stringIndex, index - 1).match(COUNT_GAPS_REGEXP)
        if (wordBreaks && stringIndex > 0) score *= Math.pow(PENALTY_SKIPPED, wordBreaks.length)
      } else if (IS_SPACE_REGEXP.test(string.charAt(index - 1))) {
        score *= SCORE_SPACE_WORD_JUMP
        spaceBreaks = string.slice(stringIndex, index - 1).match(COUNT_SPACE_REGEXP)
        if (spaceBreaks && stringIndex > 0) score *= Math.pow(PENALTY_SKIPPED, spaceBreaks.length)
      } else {
        score *= SCORE_CHARACTER_JUMP
        if (stringIndex > 0) score *= Math.pow(PENALTY_SKIPPED, index - stringIndex)
      }

      if (string.charAt(index) !== abbreviation.charAt(abbreviationIndex)) score *= PENALTY_CASE_MISMATCH
    }

    if (
      (score < SCORE_TRANSPOSITION &&
        lowerString.charAt(index - 1) === lowerAbbreviation.charAt(abbreviationIndex + 1)) ||
      (lowerAbbreviation.charAt(abbreviationIndex + 1) === lowerAbbreviation.charAt(abbreviationIndex) &&
        lowerString.charAt(index - 1) !== lowerAbbreviation.charAt(abbreviationIndex))
    ) {
      transposedScore = commandScoreInner(string, abbreviation, lowerString, lowerAbbreviation, index + 1, abbreviationIndex + 2, memoisedResults)

      if (transposedScore * SCORE_TRANSPOSITION > score) {
        score = transposedScore * SCORE_TRANSPOSITION
      }
    }

    if (score > highScore) highScore = score

    index = lowerString.indexOf(abbreviationChar, index + 1)
  }

  memoisedResults[memoiseKey] = highScore

  return highScore
}

function formatInput(string) {
  // Convert all valid space characters to space so they match each other.
  return string.toLowerCase().replace(COUNT_SPACE_REGEXP, " ")
}

// `keywords` are searched and never shown, which is how "Preferences" is found
// by typing "settings".
export function commandScore(string, abbreviation, aliases) {
  const searchable = aliases && aliases.length ? `${string} ${aliases.join(" ")}` : string

  return commandScoreInner(
    searchable,
    abbreviation,
    formatInput(searchable),
    formatInput(abbreviation),
    0,
    0,
    {}
  )
}
