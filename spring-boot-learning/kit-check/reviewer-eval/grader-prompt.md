You are grading two code review reports of the same small Java service. The reports are labelled X and Y. You don't
know who or what wrote them, and you must not try to find out.

Work only inside this folder: `{DIR}`
- `code/`: the service that was reviewed (the whole module was under review, every file treated as new)
- `answer-key.md`: the 10 planted defects (K1 to K10), what full marks need, and a short "Not defects" list
- `X.md`, `Y.md`: the two reports

Don't read, list or search anything outside that folder, and don't use the web.

For each report, list every finding: each distinct claim that something is wrong, whether it sits under "Must fix" or
under notes. Check each one yourself by opening the file and line in `code/`. Then give it one class:

| Class | When |
|---|---|
| `KNOWN` | It matches a defect in the answer key. Add `"known": "K<n>"` and `"credit"`: `"full"` when the mechanism and the location are right and the "Full marks need" column is met; `"partial"` when it points at the right place but misses the mechanism the key asks for. K5: either half alone is partial, both halves are full. K6: full only if the report says the model rejects the request (a 400) for this model; "temperature 0 is unusual" is not enough |
| `VALID-high`, `VALID-medium`, `VALID-low` | A real defect that is not in the key, confirmed in the code. The level is the harm it could do |
| `DEBATABLE` | An opinion or preference, something the code can't confirm, or an item on the key's "Not defects" list |
| `WRONG` | A claim about the code, or about a library or model version, that is false |

Rules:
- If a report states the same known defect more than once, record it once, at its best credit.
- If one finding covers two known defects, record two entries.
- A finding that restates a known defect is `KNOWN`, never also `VALID`.
- Judge X and Y by the same standard and independently of each other. Don't reward length or style.

Write `{DIR}/grades.json`, valid JSON and nothing else, in this shape:

{"X": [{"finding": "<short title>", "class": "KNOWN", "known": "K2", "credit": "full", "why": "<one or two sentences with file:line evidence>"},
       {"finding": "<short title>", "class": "VALID-medium", "why": "<...>"}],
 "Y": [...]}

Then reply with two lines only: for X and for Y, the count of each class and which K numbers got full and partial credit.
