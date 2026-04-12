'use strict';

/**
 * FAQ locale model (canonical):
 * - question / answer: German (primary)
 * - questionEn / answerEn: optional English
 *
 * Legacy (deprecated): questionDe / answerDe were used to store English — read fallback only.
 */

function trimOrUndefined(v) {
  if (v == null) return undefined;
  const s = String(v).trim();
  return s.length ? s : undefined;
}

/**
 * Resolve optional English from create/update params (accepts canonical or legacy keys).
 */
function resolveEnglishFromParams(params) {
  const questionEn = trimOrUndefined(
    params.questionEn !== undefined ? params.questionEn : params.questionDe
  );
  const answerEn = trimOrUndefined(
    params.answerEn !== undefined ? params.answerEn : params.answerDe
  );
  return { questionEn, answerEn };
}

/**
 * Pick English field updates from a partial update object (canonical or legacy keys).
 * Returns { questionEn?: string|null, answerEn?: string|null } where null means unset.
 */
function pickEnglishUpdates(updates) {
  const result = {};
  const hasQ =
    Object.prototype.hasOwnProperty.call(updates, 'questionEn') ||
    Object.prototype.hasOwnProperty.call(updates, 'questionDe');
  const hasA =
    Object.prototype.hasOwnProperty.call(updates, 'answerEn') ||
    Object.prototype.hasOwnProperty.call(updates, 'answerDe');

  if (hasQ) {
    const raw = updates.questionEn !== undefined ? updates.questionEn : updates.questionDe;
    const t = trimOrUndefined(raw);
    result.questionEn = t === undefined ? null : t;
  }
  if (hasA) {
    const raw = updates.answerEn !== undefined ? updates.answerEn : updates.answerDe;
    const t = trimOrUndefined(raw);
    result.answerEn = t === undefined ? null : t;
  }
  return result;
}

/**
 * Apply English fields to a Parse FAQ object; strip legacy columns when any EN field is written.
 */
function applyEnglishFieldsToFaq(faq, { questionEn, answerEn }) {
  let touched = false;
  if (questionEn !== undefined) {
    touched = true;
    if (questionEn === null || questionEn === '') {
      faq.unset('questionEn');
    } else {
      faq.set('questionEn', questionEn);
    }
  }
  if (answerEn !== undefined) {
    touched = true;
    if (answerEn === null || answerEn === '') {
      faq.unset('answerEn');
    } else {
      faq.set('answerEn', answerEn);
    }
  }
  if (touched) {
    faq.unset('questionDe');
    faq.unset('answerDe');
  }
}

/**
 * Merge legacy into canonical for API JSON; strip misleading keys from response.
 */
function hydrateFaqLocaleJSON(json) {
  const qEn = trimOrUndefined(json.questionEn ?? json.questionDe);
  const aEn = trimOrUndefined(json.answerEn ?? json.answerDe);
  const next = { ...json };
  delete next.questionDe;
  delete next.answerDe;
  if (qEn) next.questionEn = qEn;
  else delete next.questionEn;
  if (aEn) next.answerEn = aEn;
  else delete next.answerEn;
  return next;
}

module.exports = {
  resolveEnglishFromParams,
  pickEnglishUpdates,
  applyEnglishFieldsToFaq,
  hydrateFaqLocaleJSON,
  trimOrUndefined,
};
