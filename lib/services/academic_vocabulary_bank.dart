/// A comprehensive bank of B2–C1 discourse markers and academic vocabulary,
/// used by SpeechAnalysisService to flag "range" — i.e. does the speaker
/// reach for varied, higher-register language, or lean on the same handful
/// of basic words throughout.
///
/// Grouped by rhetorical function (the categories a CEFR speaking examiner
/// actually listens for — addition, contrast, cause/effect, exemplification,
/// stance, emphasis, sequencing, hedging, conclusion) plus academic
/// adjectives/verbs/nouns. The grouping is only for readability/maintenance
/// here; SpeechAnalysisService currently just flattens this into one
/// membership check per transcript, so category boundaries aren't load-
/// bearing at runtime (yet — see the note at the bottom of this file for a
/// natural next step).
///
/// Coverage note: this still isn't an exhaustive C2 academic word list (that
/// would start pulling in far more domain-specific/rare vocabulary than is
/// useful for judging a 2-minute MUET talk) — it's sized to reward genuine
/// range on a general-topics speaking task without rewarding trivia.
///
/// Source note: this is an original compilation based on general knowledge
/// of B2-C1 level English, grouped by part of speech / rhetorical function
/// below. It is NOT a copy of Cambridge's English Vocabulary Profile (EVP)
/// or any other licensed/proprietary leveled word list — those are
/// copyrighted commercial datasets, not something to reproduce wholesale.
/// Expect some overlap with any general B2-C1 word list purely because the
/// underlying vocabulary tier is the same; the selection and grouping here
/// are independent.
const Set<String> kAcademicVocabularyBank = {
  // --- Addition ---
  'furthermore', 'moreover', 'in addition', 'additionally', 'besides',
  "what's more", 'on top of that', 'not only', 'as well as', 'along with',
  'coupled with', 'in conjunction with',

  // --- Contrast / concession ---
  'nevertheless', 'nonetheless', 'on the other hand', 'in contrast',
  'conversely', 'by contrast', 'whereas', 'while', 'although', 'even though',
  'despite', 'in spite of', 'that said', 'having said that', 'yet still',
  'admittedly', 'notwithstanding', 'albeit', 'regardless of',
  'as opposed to', 'unlike',

  // --- Cause and effect ---
  'therefore', 'consequently', 'as a result', 'as a consequence', 'hence',
  'thus', 'accordingly', 'due to', 'owing to', 'because of', 'leads to',
  'results in', 'gives rise to', 'stems from', 'brought about by',
  'in turn', 'thereby',

  // --- Exemplification ---
  'for example', 'for instance', 'such as', 'namely', 'to illustrate',
  'a case in point', 'in particular', 'specifically', 'to name a few',

  // --- Stance / opinion ---
  'in my opinion', 'from my perspective', 'from my point of view',
  'i would argue', 'i would contend', 'arguably', 'it could be argued',
  'personally', 'as far as i am concerned', 'to my mind',

  // --- Emphasis / certainty ---
  'significantly', 'notably', 'remarkably', 'importantly', 'crucially',
  'above all', 'indeed', 'in fact', 'undoubtedly', 'unquestionably',
  'without a doubt', 'needless to say', 'more importantly',

  // --- Sequencing / structure ---
  'firstly', 'secondly', 'thirdly', 'to begin with', 'first and foremost',
  'subsequently', 'meanwhile', 'eventually', 'ultimately', 'in the meantime',
  'following this', 'prior to this',

  // --- Hedging / qualifying ---
  'to some extent', 'to a certain degree', 'on the whole', 'broadly speaking',
  'generally speaking', 'in general', 'more often than not', 'by and large',
  'for the most part', 'in most cases', 'strictly speaking',

  // --- Conclusion / summary ---
  'in conclusion', 'to conclude', 'to summarize', 'in summary',
  'to sum up', 'all things considered', 'in short', 'overall',
  'taking everything into account', 'in a nutshell',

  // --- Academic adjectives ---
  'substantial', 'considerable', 'significant', 'crucial', 'fundamental',
  'comprehensive', 'predominant', 'prevalent', 'inevitable', 'controversial',
  'beneficial', 'detrimental', 'feasible', 'viable', 'plausible', 'inherent',
  'pivotal', 'paramount', 'integral', 'versatile', 'sustainable', 'tangible',
  'ambiguous', 'coherent', 'consistent', 'prominent', 'profound',
  'unprecedented', 'widespread', 'compelling', 'rigorous', 'meticulous',
  'ubiquitous', 'multifaceted', 'nuanced', 'legitimate', 'redundant',
  'adverse', 'chronic', 'diverse', 'holistic', 'intrinsic', 'notable',
  'optimal', 'robust', 'subtle', 'volatile',

  // --- Academic verbs ---
  'demonstrate', 'indicate', 'suggest', 'highlight', 'emphasize',
  'illustrate', 'facilitate', 'contribute', 'enhance', 'undermine',
  'address', 'tackle', 'mitigate', 'foster', 'cultivate', 'implement',
  'establish', 'sustain', 'accelerate', 'hinder', 'promote', 'reinforce',
  'encompass', 'constitute', 'derive', 'entail', 'accommodate', 'acknowledge',
  'advocate', 'assess', 'attain', 'clarify', 'differentiate', 'evaluate',
  'exceed', 'exemplify', 'exploit', 'incorporate', 'justify', 'maximize',
  'minimize', 'optimize', 'outweigh', 'perceive', 'prioritize', 'reinstate',
  'stimulate', 'validate',

  // --- Academic nouns ---
  'implication', 'perspective', 'phenomenon', 'framework', 'methodology',
  'dimension', 'aspect', 'consequence', 'significance', 'prevalence',
  'discrepancy', 'correlation', 'disparity', 'incentive', 'initiative',
  'infrastructure', 'controversy', 'criterion', 'dilemma', 
  'notion', 'paradigm', 'precedent', 'prerequisite', 'rationale', 'scenario',
  'trend', 'variable', 'consensus', 'contradiction', 'drawback',

  // --- Comparison ---
  'similarly', 'likewise', 'in the same way', 'by the same token',
  'equally', 'in comparison', 'compared to', 'relative to',

  // ===========================================================
  // Extended bank below — original compilation, not Cambridge EVP.
  // ===========================================================

  // --- Additional academic adjectives ---
  'acute', 'adequate', 'alarming', 'ample', 'apparent', 'arbitrary',
  'arduous', 'articulate', 'artificial', 'assertive', 'astute', 'authentic',
  'autonomous', 'awkward', 'biased', 'blatant', 'bleak', 'bold', 'brittle',
  'candid', 'capable', 'catastrophic', 'cautious', 'ceaseless', 'celebrated',
  'chaotic', 'coincidental', 'collaborative', 'colossal', 'commendable',
  'competent', 'complacent', 'complex', 'complicated', 'conceivable',
  'concise', 'conclusive', 'concurrent', 'condescending', 'confidential',
  'congruent', 'conscientious', 'considerate', 'constructive', 'contemporary',
  'contentious', 'contingent', 'conventional', 'cordial', 'credible',
  'cumbersome', 'cumulative', 'cynical', 'daunting', 'decisive', 'deficient',
  'definitive', 'deliberate', 'deceptive', 'demanding', 'dependable',
  'deplorable', 'derivative', 'desirable', 'destructive', 'devastating',
  'dire', 'discerning', 'disciplined', 'discouraging', 'discreet',
  'disproportionate', 'dispassionate', 'distinct', 'distinctive',
  'disturbing', 'divisive', 'dogmatic', 'dubious', 'dynamic', 'eccentric',
  'elaborate', 'eloquent', 'elusive', 'embedded', 'eminent', 'empirical',
  'encouraging', 'endemic', 'enigmatic', 'enormous', 'epidemic', 'equitable',
  'erratic', 'essential', 'ethical', 'evasive', 'exceptional', 'excessive',
  'exhaustive', 'exorbitant', 'exotic', 'explicit', 'exponential',
  'extensive', 'external', 'extraordinary', 'extravagant', 'faulty',
  'favorable', 'ferocious', 'fickle', 'finite', 'flagrant', 'flawed',
  'fleeting', 'flimsy', 'formidable', 'fragile', 'frantic', 'frivolous',
  'fruitful', 'futile', 'genuine', 'glaring', 'gradual', 'grave', 'gross',
  'gruelling', 'hazardous', 'hesitant', 'hostile', 'humane', 'hypothetical',
  'illogical', 'illusory', 'immense', 'imminent', 'impartial', 'impeccable',
  'imperative', 'impetuous', 'implicit', 'implausible', 'impractical',
  'impressive', 'impulsive', 'inadequate', 'inadvertent', 'incessant',
  'incidental', 'inclusive', 'incompatible', 'inconceivable', 'inconclusive',
  'inconsistent', 'inconspicuous', 'indispensable', 'indistinguishable',
  'ineffective', 'inefficient', 'inept', 'inexplicable', 'infamous',
  'infinite', 'informative', 'infrequent', 'ingenious', 'innate',
  'innovative', 'inordinate', 'insidious', 'insightful', 'insignificant',
  'instrumental', 'insufficient', 'intangible', 'intense', 'intentional',
  'intolerable', 'intricate', 'intriguing', 'invaluable', 'invasive',
  'inventive', 'irrational', 'irreversible', 'irrelevant', 'judicious',
  'lamentable', 'laudable', 'lax', 'lenient', 'lethal', 'levelheaded',
  'lucid', 'lucrative', 'ludicrous', 'malicious', 'mandatory', 'marginal',
  'meager', 'methodical', 'mindful', 'minimal', 'misguided', 'momentous',
  'monumental', 'mundane', 'negligible', 'notorious', 'novel', 'obscure',
  'obsolete', 'obstinate', 'offensive', 'ominous', 'onerous', 'opaque',
  'opportunistic', 'oppressive', 'orthodox', 'outdated', 'outrageous',
  'overt', 'painstaking', 'palpable', 'paradoxical', 'partisan', 'passive',
  'pertinent', 'pervasive', 'plagued', 'pragmatic', 'precarious', 'precise',
  'preliminary', 'premature', 'presumptuous', 'pretentious', 'primary',
  'principled', 'problematic', 'productive', 'proficient', 'prolific',
  'prolonged', 'prone', 'prosperous', 'provisional', 'prudent', 'punitive',
  'questionable', 'radical', 'rampant', 'rare', 'rational', 'reckless',
  'redeeming', 'relentless', 'reliable', 'relevant', 'reluctant', 'remedial',
  'reminiscent', 'reprehensible', 'resilient', 'resourceful', 'respective',
  'restrictive', 'retrospective', 'reversible', 'ruthless', 'scarce',
  'sceptical', 'seamless', 'sensible', 'sensitive', 'severe', 'shallow',
  'shrewd', 'sizable', 'sluggish', 'sobering', 'solitary', 'sophisticated',
  'sparse', 'speculative', 'spontaneous', 'sporadic', 'spurious',
  'staggering', 'stark', 'static', 'steadfast', 'stringent', 'strenuous',
  'subjective', 'submissive', 'subordinate', 'subsequent', 'substandard',
  'superficial', 'superfluous', 'susceptible', 'sweeping', 'systematic',
  'tacit', 'tedious', 'tenacious', 'tentative', 'thorough', 'timely',
  'tolerant', 'transient', 'treacherous', 'trivial', 'turbulent',
  'unanimous', 'unattainable', 'unavoidable', 'uncharacteristic',
  'unconventional', 'undeniable', 'understated', 'unequivocal', 'unfeasible',
  'unfounded', 'uniform', 'unjustified', 'unorthodox', 'unpredictable',
  'unprincipled', 'unreliable', 'unrestricted', 'unsubstantiated',
  'unsuitable', 'unsustainable', 'unwarranted', 'unwavering', 'unyielding',
  'utmost', 'vague', 'valid', 'verifiable', 'vigilant', 'vigorous',
  'vindictive', 'virtuous', 'vital', 'vulnerable', 'wary', 'worthwhile',
  'zealous',

  // --- Additional academic verbs ---
  'abandon', 'abolish', 'absorb', 'accumulate', 'acquire', 'adapt', 'adhere',
  'administer', 'advance', 'aggravate', 'alienate', 'alleviate', 'allocate',
  'alter', 'amend', 'amplify', 'analyze', 'anticipate', 'appease', 'apply',
  'appraise', 'approximate', 'ascertain', 'aspire', 'assemble',
  'assert', 'assign', 'assimilate', 'associate', 'assume', 'attribute',
  'augment', 'authorize', 'blame', 'boost', 'bolster', 'bypass',
  'capitalize', 'categorize', 'cease', 'challenge', 'characterize',
  'circumvent', 'cite', 'coincide', 'collaborate', 'combat', 'commence',
  'compensate', 'compile', 'complement', 'comply', 'comprise', 'conceive',
  'concede', 'conclude', 'condemn', 'confer', 'confine', 'confirm',
  'conform', 'confront', 'consolidate', 'constrain', 'construct', 'consult',
  'contemplate', 'contradict', 'convert', 'convey', 'coordinate',
  'correlate', 'correspond', 'counteract', 'curb', 'curtail', 'decline',
  'deduce', 'deem', 'defer', 'define', 'delegate', 'delineate', 'denote',
  'deprive', 'designate', 'detect', 'deteriorate', 'determine', 'deviate',
  'devise', 'diminish', 'disclose', 'discourage', 'disperse', 'disregard',
  'dissuade', 'distinguish', 'diverge', 'diversify', 'document', 'dominate',
  'downplay', 'duplicate', 'eliminate', 'elucidate', 'embody',
  'empower', 'enable', 'enact', 'encounter', 'endorse', 'endure', 'enforce',
  'engage', 'ensure', 'envisage', 'equip', 'eradicate', 'escalate',
  'estimate', 'evoke', 'examine', 'exclude', 'execute', 'exert', 'expand',
  'expedite', 'extend', 'extract', 'fabricate', 'formulate', 'fortify',
  'fulfil', 'gather', 'generate', 'govern', 'grant', 'hamper', 'harness',
  'identify', 'impede', 'imply', 'incur', 'induce', 'infer', 'inflict',
  'influence', 'initiate', 'inspect', 'instigate', 'integrate', 'intensify',
  'interact', 'interpret', 'intervene', 'invest', 'investigate', 'isolate',
  'jeopardize', 'magnify', 'maintain', 'mandate', 'manipulate', 'manifest',
  'mediate', 'modify', 'monitor', 'negotiate', 'neglect', 'nurture',
   'observe', 'obstruct', 'obtain', 'offset', 'oppose',
  'orchestrate', 'originate', 'outline', 'overcome', 'overlook',
  'overshadow', 'overstate', 'oversee', 'overturn', 'participate',
  'permeate', 'persist', 'pertain', 'pinpoint', 'portray', 'postulate',
  'precede', 'predict', 'predominate', 'preserve', 'prevail', 'proceed',
  'procure', 'prohibit', 'project', 'propagate', 'propel', 'propose',
  'prosper', 'provoke', 'purport', 'pursue', 'rectify', 'redress', 'refine',
  'refute', 'regulate', 'rehabilitate', 'reiterate', 'reject', 'relinquish',
  'remedy', 'render', 'replicate', 'represent', 'resolve', 'restore',
  'restrain', 'restrict', 'retain', 'retrieve', 'reveal', 'revise',
  'revitalize', 'safeguard', 'salvage', 'scrutinize', 'secure', 'segregate',
  'sever', 'shape', 'shift', 'signify', 'simulate', 'solicit', 'specify',
  'speculate', 'spur', 'streamline', 'strengthen', 'subdue', 'submit',
  'substantiate', 'substitute', 'suppress', 'surpass', 'surround', 'tailor',
  'terminate', 'thrive', 'transcend', 'transform', 'translate', 'transmit',
  'undergo', 'underlie', 'underline', 'underpin', 'undertake', 'unify',
  'unveil', 'uphold', 'utilize', 'verify', 'warrant', 'withstand', 'yield',

  // --- Additional academic nouns ---
  'adversity', 'affiliation', 'agenda', 'ailment', 'allegation',
  'ambiguity', 'ambition', 'anomaly', 'antecedent', 'anticipation',
  'apparatus', 'appraisal', 'apprehension', 'aptitude', 'archetype',
  'artifact', 'assertion', 'assumption',  'attrition',
  'authenticity', 'autonomy', 'backdrop', 'backlash', 'bias', 'breakthrough',
  'bureaucracy', 'campaign', 'capability', 'catalyst', 'causation', 'caveat',
  'coalition', 'cognition', 'cohesion', 'commodity', 'compensation',
  'competence', 'complexity', 'complication', 'compliance', 'component',
  'composition', 'comprehension', 'compromise', 'conception', 'condition',
  'confinement', 'conflict', 'conformity', 'congestion', 'connotation',
  'constraint', 'contention', 'context', 'contingency', 'continuity',
  'contribution', 'conviction', 'corroboration', 'credibility', 'criteria',
  'crisis', 'critique', 'culmination', 'curriculum', 'deficit',
  'degradation', 'deliberation', 'demographic', 'denomination', 'dependency',
  'deprivation', 'derivation', 'deterrent', 'deviation', 'diagnosis',
  'dichotomy', 'differential', 'dilution', 'disclosure', 'discourse',
  'disposition', 'disruption', 'dissent', 'distinction', 'diversity',
  'doctrine', 'domain', 'dominance', 'downturn', 'dynamics', 'ecosystem',
  'efficacy', 'elaboration', 'emphasis', 'empowerment', 'endeavor',
  'endorsement', 'entity', 'epitome', 'equilibrium', 'equity', 'escalation',
  'essence', 'estimation', 'ethic', 'evaluation', 'exception', 'exemplar',
  'exodus', 'expansion', 'expenditure', 'expertise', 'exposure',
  'extremity', 'facet', 'faction', 'fallacy', 'feasibility', 'fluctuation',
  'forerunner', 'foresight', 'formulation', 'foundation', 'fragmentation',
  'fraud', 'fruition', 'function', 'funding', 'genesis', 'gravity',
  'hierarchy', 'hindrance', 'hindsight', 'hypothesis', 'ideology',
  'imbalance', 'immersion', 'impact', 'impasse', 
  'implementation', 'inception', 'incidence', 'inclination', 'inclusion',
  'incoherence', 'indicator', 'indignation', 'inequality', 'inference',
  'infringement', 'ingenuity', 'initiation', 'innovation', 'inquiry',
  'insight', 'instability', 'integration', 'integrity', 'intensity',
  'interdependence', 'interference', 'interplay', 'interpretation',
  'intervention', 'intuition', 'inundation', 'inventory', 'jargon',
  'jeopardy', 'jurisdiction', 'justification', 'latitude', 'legacy',
  'legislation', 'legitimacy', 'liability', 'litigation', 'longevity',
  'magnitude', 'mainstream', 'manifestation', 'manipulation', 'margin',
  'mechanism', 'mediation', 'mentality', 'milestone', 'momentum',
  'monopoly', 'morale', 'motive', 'mutation', 'myth', 'narrative',
  'negligence', 'niche', 'nomenclature', 'norm', 'nuance', 'obstacle',
  'occurrence', 'omission', 'oppression', 'optimism', 'orientation',
  'outbreak', 'outcome', 'outlook', 'overhaul', 'oversight', 'paradox',
  'parameter', 'parity', 'pathology', 'perception', 'permutation',
  'perpetuity', 'persistence', 'pessimism', 'philosophy', 'plight',
  'polarity', 'policy', 'portfolio', 'potential', 'predicament',
  'predisposition', 'premise', 'presumption', 'pretext', 'principle',
  'priority', 'probability', 'procedure', 'proficiency', 'projection',
  'proliferation', 'prominence', 'propensity', 'proportion', 'proposition',
  'prospect', 'protocol', 'provision', 'proximity', 'quandary', 'quota',
  'ramification', 'reasoning', 'recession', 'reciprocity', 'recurrence',
  'redundancy', 'referendum', 'reform', 'regime', 'regulation', 'relevance',
  'reliability', 'renaissance', 'repercussion', 'reservation', 'residue',
  'resilience', 'resolution', 'resource', 'restoration', 'restraint',
  'retention', 'revelation', 'revision', 'rhetoric', 'rigor', 'sanction',
  'saturation', 'scepticism', 'schema', 'scope', 'scrutiny', 'sequence',
  'setback', 'severity', 'shortfall', 'simulation', 'skepticism',
  'spectrum', 'speculation', 'spontaneity', 'stagnation', 'standpoint',
  'statute', 'stereotype', 'stigma', 'stimulus', 'stipulation', 'strategy',
  'stratification', 'structure', 'subsidiary', 'subsidy', 'substance',
  'subtlety', 'superiority', 'supplement', 'surplus', 'susceptibility',
  'symmetry', 'symptom', 'synergy', 'synthesis', 'tangent', 'taxonomy',
  'tendency', 'tenet', 'tension', 'terminology', 'testimony', 'threshold',
  'timeframe', 'trajectory', 'transition', 'transparency', 'trauma',
  'tribunal', 'turbulence', 'ultimatum', 'underpinning', 'uniformity',
  'upheaval', 'utility', 'validity', 'variance', 'variation', 'velocity',
  'viability', 'viewpoint', 'vigilance', 'vindication', 'virtue', 'vision',
  'volatility',

  // --- Additional academic adverbs ---
  'allegedly', 'apparently', 'categorically', 'chiefly', 'comparatively',
  'considerably', 'conspicuously', 'conveniently', 'correspondingly',
  'critically', 'decidedly', 'deliberately', 'demonstrably',
  'disproportionately', 'distinctly', 'drastically', 'effectively',
  'empirically', 'essentially', 'evidently', 'exceedingly', 'exclusively',
  'extensively', 'extremely', 'fairly', 'fundamentally', 'generally',
  'gradually', 'greatly', 'increasingly', 'inherently', 'initially',
  'intentionally', 'intrinsically', 'invariably', 'largely', 'markedly',
  'marginally', 'mutually', 'negatively', 'objectively', 'occasionally',
  'overwhelmingly', 'partially', 'particularly', 'patently', 'positively',
  'potentially', 'precisely', 'predominantly', 'primarily', 'progressively',
  'proportionally', 'purely', 'radically', 'rarely', 'readily',
  'relatively', 'respectively', 'seemingly', 'simultaneously', 'solely',
  'sparingly', 'staunchly', 'steadily', 'strictly', 'strongly',
  'substantially', 'successfully', 'sufficiently', 'superficially',
  'systematically', 'technically', 'theoretically', 'thoroughly',
  'typically', 'universally', 'unnecessarily', 'unusually', 'vastly',
  'virtually', 'widely',

  // --- Additional idioms / academic collocations ---
  'a double-edged sword', 'a step in the right direction', 'against all odds',
  'at the heart of', 'at the forefront of', 'bear in mind', 'by no means',
  'call into question', 'come to terms with', 'draw a distinction',
  'drive home the point', 'each and every', 'far from',
  'food for thought', 'for all intents and purposes', 'get to the root of',
  'go hand in hand with', 'hold true', 'in a bid to', 'in due course',
  'in essence', 'in hindsight', 'in light of', 'in line with',
  'in no small part', 'in numerous instances', 'in retrospect',
  'in the face of', 'in the long run', 'in the wake of', 'keep pace with',
  'lay the groundwork', 'leave much to be desired', 'make a case for',
  'make headway', 'on account of', 'on balance', 'on closer inspection',
  'open the door to', 'pave the way for', 'play a pivotal role',
  'play devil\'s advocate', 'point to the fact that', 'put into perspective',
  'raise the question', 'reach a consensus', 'run the risk of',
  'set the stage for', 'shed light on', 'stand the test of time',
  'strike a balance', 'take into account', 'take root',
  'the crux of the matter', 'the flip side', 'to a large extent',
  'to that end', 'turn a blind eye', 'under no circumstances',
  'up to a point', 'when it comes to', 'with regard to',
  'with this in mind', 'yield results',

  // --- Additional stance / hedging phrases ---
  'it stands to reason that', 'one could argue that',
  'it is widely believed that', 'it is worth noting that',
  'it seems reasonable to assume', 'there is little doubt that',
  'few would dispute that', 'it is generally accepted that',
  'it is often claimed that', 'some might contend that',
};

/// A future refinement: split this into named category maps (addition,
/// contrast, cause/effect, ...) and have SpeechAnalysisService report which
/// *categories* a speaker used vs. never touched (e.g. "you never used a
/// contrast marker") rather than just a flat count. That maps much more
/// directly onto how the CEFR Coherence dimension is actually judged — see
/// cefr_scoring_service.dart's COHERENCE rubric — but changes the
/// SpeechMetrics/UI shape, so it's left as a deliberate next step rather
/// than folded in here.
///
/// 2024 expansion note: the bank grew from ~200 to ~1,370 unique terms,
/// adding dedicated adjective/verb/noun/adverb sections plus a batch of
/// academic idioms and stance phrases. All new entries are an original
/// compilation (see the source note near the top of this file), not a copy
/// of any licensed word list.