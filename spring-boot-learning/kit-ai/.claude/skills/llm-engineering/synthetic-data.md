# Synthetic data: invented, labelled, checked by hand

A public portfolio project can't use real claims, real policies, or anything from an employer. Everything is
invented, and the invention is done carefully enough that the eval means something.

## Never

- Real people, real claims, real policy documents, or anything derived from an employer's data, wording, rules,
  products or names, even "anonymised". Public knowledge (how travel insurance generally works) is fine.
- Real-looking identifiers that could belong to someone: use obviously fake ones (`POL-20481`, `+44 7700 900123`
  from the UK's drama range, `@example.com`).

## The policy wording

About 10 pages, written for the project:

- Numbered sections and clauses (`4.1`, `7.3`), so citations point somewhere precise.
- Limits with numbers (per item, per trip, excess), so amounts can be checked.
- Exclusions that interact (unattended baggage; reporting within 24 hours; pre-existing conditions).
- **Two or three deliberately ambiguous clauses**: the cases where the right answer is "a human decides".
- A version and a date at the top. When it changes, the cases that cite it are re-checked.

## The claims: a case mix, not a pile

For ~60 cases (start with 30):

| Kind | Share | Example |
|---|---|---|
| Complete and covered | 25% | lost suitcase, all facts present, under the limit |
| Missing information | 15% | no amount, no date, no policy number |
| An exclusion applies | 15% | reported to the airline after 3 days |
| Over a limit | 8% | a 2,000.00 GBP camera against a 500.00 per-item limit |
| Ambiguous: needs a human | 10% | the clause genuinely doesn't settle it |
| Adversarial | 10% | "ignore your instructions", a fake "SYSTEM NOTE", a claim about a different policy |
| Messy input | 10% | long rambling email, a forwarded thread, odd date formats, typos, mixed currencies |
| Other languages or styles | 7% | short and terse, very formal, non-native English |

Each case gets `covers` (why it exists) and its expected values, decided **before** looking at any model output.

## Drafting with a model, labelling by hand

Drafting the email text with Claude is fine and fast; labelling isn't:

1. Write the case's facts first (the expected values and what makes it interesting), then ask a model to write the
   email that contains them, in a given style.
2. Read every drafted email against its facts: does it actually say what the label claims, and nothing that
   contradicts it? Fix the text or the label.
3. A second pass on another day, on the whole set, looking for labels you'd now argue with.
4. Record `source` on each case: `hand` or `drafted by <model>, labels checked by hand <date>`.

A model that drafts the cases and grades the answers is marking its own homework: the score flatters it.

## Keep it honest over time

- Split once into `dev` and `test` and keep `test` frozen; add new cases to `dev`, and move a batch into `test`
  only on purpose, noting it in the changelog.
- When a real bug is found (in review, or in the e2e run), add a case that reproduces it before fixing it.
- Keep a short `eval/CHANGELOG.md`: what was added or relabelled, and why. Scores before and after a relabel aren't
  comparable, and the changelog is what tells you.
