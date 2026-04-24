# Specialisations

Three worked examples of narrowing `CLAUDE.md` for a specific domain. Each one shows the sections that typically need editing, and what a filled-in version looks like.

You don't need to apply all the changes in any example — start with Purpose and Owner baseline; add the rest if your domain warrants it.

---

## Example 1: Software engineering wiki

Small specialisation. The default tag vocab still fits; the interesting edits are in Purpose and Owner baseline.

### Purpose (rewrite)

```markdown
This is a **software engineering knowledge base**. Sources are a mix of engineering blog posts, conference talks, papers on systems / distributed computing / databases, and occasionally a book (Kleppmann, Hennessy & Patterson, *Refactoring*). The wiki is not a summary of any single source; it's a running synthesis across all of them, organised around the *ideas* rather than the sources.
```

### Owner baseline (rewrite)

```markdown
The owner is a working senior engineer with 10+ years of experience. Assume fluency with standard SWE foundations — data structures, networking, databases, concurrency, distributed systems basics. Do not explain what a B-tree is or why locking matters. Do explain *why* a specific algorithm earned its place over obvious alternatives, and what breaks at scale if you change it. Ground explanations in real systems (Postgres, Redis, Kafka, Git, Kubernetes) rather than abstract descriptions.
```

### Scope (optional — if running a sibling data-engineering wiki)

```markdown
This wiki covers general software engineering. Data-engineering-specific sources (streaming, warehousing, data modelling, Iceberg / Delta Lake / dbt / Airflow) belong in the sibling `data-engineering-wiki/`. A source on "SQL query optimisation" could go in either — default to software-wiki if the framing is algorithmic, data-engineering-wiki if the framing is pipeline-centric.
```

### Tag vocabulary

Default vocab works as-is. No changes needed.

### Source types

Default types (`article | paper | talk | book | chapter`) cover this domain.

---

## Example 2: Home kitchen wiki

Bigger specialisation. Tag vocab changes substantially; adds a `recipe` source type.

### Purpose (rewrite)

```markdown
This is a **home cooking knowledge base**. Sources are a mix of cookbooks, food-science articles, YouTube cooking channels, published recipes, and occasional restaurant visits worth noting. The wiki is not a catalogue of recipes; it's a running synthesis of techniques, ingredient behaviours, and the reasoning behind why dishes work.
```

### Owner baseline (rewrite)

```markdown
The owner is a home cook with ~5 years of serious practice. Assume comfort with standard techniques (sautéing, braising, basic emulsions, bread doughs, stocks). Do not explain what "deglazing" is. Do explain *why* a technique works chemically — Maillard vs caramelisation, gluten development, why an ice bath stops carryover cooking. Ground every technique in at least one real dish the owner has made or could reasonably make.
```

### Tag vocabulary (override)

```markdown
- `[technique]` — a method (lamination, emulsification, sous-vide, tempering).
- `[ingredient]` — a material and its behaviour (butter, anchovy, short-grain rice).
- `[dish]` — a specific recipe or preparation (tomato confit, French omelette).
- `[concept]` — an idea that explains behaviour (Maillard reaction, gluten development, water activity).
- `[tradeoff]` — a tension (fresh vs aged cheese for melting; butter vs oil for frying).
- `[tool]` — a piece of equipment worth its own page (cast iron, Dutch oven, immersion blender).
- `[question]` — an open question ("does resting dough in the fridge actually improve flavour?").
- `[source]` — reserved for source cards.
```

If you change the vocabulary, also update:

- `index.md` group headings to match.
- `.obsidian/graph.json` colour groups (tags that no longer exist fall back to grey).

### Source types (add one)

Add `recipe` as a source type for published recipes from blogs, cookbooks, or apps. Create `raw/recipes/` and a new clipper template (`recipe_clipper.json`) modelled on `article_clipper.json` but writing to `raw/recipes/` with `source_type: recipe`.

---

## Example 3: Product management wiki

Middle-weight specialisation. Adjusts tag vocab slightly and tightens the owner baseline. Default source types still fit.

### Purpose (rewrite)

```markdown
This is a **product management knowledge base**. Sources are a mix of product-strategy books (Marty Cagan, Teresa Torres), blog posts and talks from operating PMs, post-mortems of product launches, research methodology material, and occasional academic papers on behavioural economics or HCI. The wiki is not a summary of any single source; it's a running synthesis across all of them.
```

### Owner baseline (rewrite)

```markdown
The owner is a senior product manager with 7+ years of experience, shipping software products in B2B SaaS. Assume fluency with PM basics — roadmapping, user research methods, feature prioritisation frameworks, stakeholder management. Do not explain what an OKR is or why user interviews matter. Do explain the *mechanism* behind why one discovery method outperforms another for a given question type, and ground recommendations in real product cases (published post-mortems, well-known product pivots).
```

### Tag vocabulary (adjust)

```markdown
- `[concept]` — an idea or mental model (jobs-to-be-done, network effects, disruption theory).
- `[framework]` — a named structured approach (RICE, Kano model, opportunity solution tree).
- `[method]` — a specific research or execution technique (concept testing, user interviews, A/B tests).
- `[case-study]` — a specific product, launch, or pivot worth its own page.
- `[tradeoff]` — a tension (depth vs breadth in discovery, speed vs rigour in experimentation).
- `[metric]` — a measurement worth its own page (NPS, retention, activation).
- `[question]` — an open question.
- `[source]` — reserved for source cards.
```

`[framework]`, `[method]`, `[case-study]`, and `[metric]` replace the default `[technique]`, `[architecture]`, `[model]`, and `[system]` — the underlying structure is the same (something concrete you can point at), the names just fit the domain better.

### Source types

Default types fit. Optionally add `post-mortem` if you ingest enough of them to warrant the distinction.

---

## What didn't change

Across all three examples, the following stayed untouched:

- The three layers (raw / sources / topics).
- The three rules (extend over create, flat topic layer, source cards ≠ summaries).
- Page shapes (frontmatter schemas, body structure).
- The ingest / read / query / lint operations.
- The teaching voice section — hook, motivate, trace, ground, earn the tradeoff, anti-patterns.
- Logging conventions.
- The utilities and skills.

The specialisation happens at the edges. The engine stays the same.
