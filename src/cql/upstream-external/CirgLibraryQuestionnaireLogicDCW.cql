library CirgLibraryQuestionnaireLogicDCW version '0.1.0'

using FHIR version '4.0.1'

include "FHIRHelpers" version '4.0.1' called FHIRHelpers

context Patient


// helper functions
/*
 * retrieve the numeric value for the answer based on value code
 * @param questionnaire as FHIR.Questionnaire where code in question is queried
 * @param code as String
 * @return the value as Integer
 */
define function getAnswerValueByCode(questionnaire FHIR.Questionnaire, code String):
  (singleton from ((questionnaire.item.answerOption) Q where Q.value.code = code)) a
  let 
    extensionItem: a.extension
  return if extensionItem is not null then getAnswerOptionExtensionValue(extensionItem) else (0 as Integer)

/*
 * retrieve the numeric value for the score for an questionnaire response item
 * @param questionnaire as FHIR.Questionnaire where answer option code based on link id will be queried
 * @param responses as a list of FHIR.QuestionnaireResponse.Item
 * @param linkId as String
 * @return score in Integer
 */
define function getScoringByResponseItem(questionnaire FHIR.Questionnaire, responses List<FHIR.QuestionnaireResponse.Item>, linkId String):
  (singleton from (((responses) o where o.linkId.value = linkId) I
  return 
    if I is null then ({null as Integer})
    else
      if I.answer[0].value.code is not null then getAnswerValueByCode(questionnaire, I.answer[0].value.code.value) else 0 as Integer))

/*
 * retrieve questionnaire responses matched to the target questionnaire
 * @param responses as FHIR.QuestionnaireResponse
 * @param questionnaire as FHIR.Questionnaire to match against
 */
define function MatchedReponsesByQuestionnaire(responses List<FHIR.QuestionnaireResponse>, currentQuestionnaire FHIR.Questionnaire):
  ((responses) Q
    where 
    (
      (
        PositionOf(Lower(currentQuestionnaire.name), Lower(Q.questionnaire.value)) != -1 or
        PositionOf(Lower(currentQuestionnaire.id), Lower(Q.questionnaire.value)) != -1
      ) and 
      Q.status.value = 'completed')
  )
  sort by authored desc, meta.lastUpdated.value desc

/*
 * retrieve answer value FHIR object by response item
 * @param linkId as String
 * @param responses as a list of FHIR.QuestionnaireResponse.Item
 */
define function GetResponseValueByLinkId(linkId String, responses List<FHIR.QuestionnaireResponse.Item>):
  (responses r where r.linkId.value = linkId) I
  return I.answer[0].value


define function getQuestionnaire(questionnaireName String):
  First([Questionnaire] Q
    where 
      PositionOf(Lower(questionnaireName), Lower(Q.id)) != -1 or
      PositionOf(Lower(questionnaireName), Lower(Q.name)) != -1 or
      Lower(Q.name) = Lower(questionnaireName)
  )

// Logic for presenting questionnaire

define dcw_cog_level_1:
// if (no dementia condition)
  not HasDementia

define dcw_care_partner_present:
// TODO check Care Partner present (via CP gateway question, or field in FHIR?)
  true

// Naming pattern: "CIRG-ECOG12" is Questionnaire.id
define PresentQnr_CIRG-ECOG12:
  dcw_cog_level_1 

define PresentQnr_CIRG-CP-ECOG:
  dcw_cog_level_1
    and dcw_care_partner_present

define PresentQnr_CIRG-MINICOG:
  dcw_cog_level_1 

define dcw_cog_level_2:
// if (dementia condition)
// and/or 
// CIRG-MINICOG score is fail
// a failed score is 0,1,2, or 3
  HasDementia and First(MINICOG_Score) <= 3

define PresentQnr_CIRG-SLUMS:
  dcw_cog_level_2

define PresentQnr_CIRG-ADL-IADL:
  dcw_cog_level_2
    and dcw_care_partner_present

define dcw_mood_level_1:
  dcw_care_partner_present

define PresentQnr_CIRG-BEHAV5:
  dcw_mood_level_1

define dcw_mood_level_2:
// if (
//   depression condition ("F32.A - Depression, unspecified" and "F33.1 - Major Depressive Disorder, Recurrent, Moderate")
//   and/or 
//   anxiety condition ("F41.1 - Generalized Anxiety Disorder" - not present in our 3 test patients...)
//   and/or 
//   CIRG-BEHAV5 score is fail 
// )
  HasMoodConditions and First(BEHAV5_Score) <= 7

define PresentQnr_CIRG-GAD7:
  dcw_mood_level_2
// and
//   CIRG-SLUMS score is Normal or Mild Neurocognitive Disorder 

define PresentQnr_CIRG-GDS:
  dcw_mood_level_2
// and
//   CIRG-SLUMS score is Normal or Mild Neurocognitive Disorder 

define PresentQnr_CIRG-C-IDAS:
  dcw_mood_level_2
// and
//   CIRG-SLUMS score indicates dementia 
// and
//   Care Partner present (via CP gateway question, or field in FHIR?)

// these draft additions based on clinical_quality_language/Examples/ChlamydiaScreening_Common.cql ,
// however I think that's more about mapping conditions to lab tests...
// valueset "Dementia NOS": 'F03.9'
// valueset "Vascular Dementia, unspecified severity": 'F01.5'
// valueset "Frontotemporal dementia": 'G31.0'
// valueset "Parkinson's disease": 'G20'
// valueset "Unspecified dementia, with behavioral disturbance": 'F03.91'

// define "Conditions Indicating Dementia":
//     ["Condition": "Dementia NOS"]
//     union ["Condition": "Vascular Dementia, unspecified severity"]
//     union ["Condition": "Frontotemporal dementia"]
//     union ["Condition": "Parkinson's disease"]
//     union ["Condition": "Unspecified dementia, with behavioral disturbance"]

define DementiaConditions:
  ["Condition"] C where exists (
    C.code.coding[0].code.value = 'F03.9' or
    C.code.coding[0].code.value = 'F01.5' or
    C.code.coding[0].code.value = 'G31.0' or
    C.code.coding[0].code.value = 'G20' or
    C.code.coding[0].code.value = 'F03.91'
  )

define HasDementia:
  Length(DementiaConditions) > 0


//   depression condition ("F32.A - Depression, unspecified" and "F33.1 - Major Depressive Disorder, Recurrent, Moderate")
//   and/or 
//   anxiety condition ("F41.1 - Generalized Anxiety Disorder" - not present in our 3 test patients...)

define MoodConditions: 
  ["Condition"] C where exists (
    C.code.coding[0].code.value = 'F32.A' or
    C.code.coding[0].code.value = 'F33.1' or
    C.code.coding[0].code.value = 'F41.1'
  )

define HasMoodConditions:
  Length(MoodConditions) > 0


// below from: https://github.com/uwcirg/asbi-screening-app/blob/feature/apply-plandefinition-without-encender/src/cql/upstream-external/QuestionnaireLogicLibrary_PHQ9_GAD7.cql

// TODO generalize, call by Questionnaire.id
// define PHQ9_Questionnaire:
//   getQuestionnaire('PHQ9')

// define GA7_Questionnaire:
//   getQuestionnaire('GAD7')

define BEHAV5_Questionnaire:
  getQuestionnaire('BEHAV5')

define BEHAV5_Responses:
  MatchedReponsesByQuestionnaire([QuestionnaireResponse], BEHAV5_Questionnaire)

define BEHAV5_Score:
  (BEHAV5_Responses) I
  return (
    Coalesce(First(getScoringByResponseItem(BEHAV5_Questionnaire, I.item, 'behav-1')), 0) +
    Coalesce(First(getScoringByResponseItem(BEHAV5_Questionnaire, I.item, 'behav-2')), 0) +
    Coalesce(First(getScoringByResponseItem(BEHAV5_Questionnaire, I.item, 'behav-3')), 0) + 
    Coalesce(First(getScoringByResponseItem(BEHAV5_Questionnaire, I.item, 'behav-4')), 0) +
    Coalesce(First(getScoringByResponseItem(BEHAV5_Questionnaire, I.item, 'behav-5')), 0) +
    Coalesce(First(.getScoringByResponseItem(BEHAV5_Questionnaire, I.item, 'behav-6')), 0)
  )

define MINICOG_Questionnaire:
  getQuestionnaire('MINICOG')

define MINICOG_Responses:
  MatchedReponsesByQuestionnaire([QuestionnaireResponse], BEHAV5_Questionnaire)

define MINICOG_Score:
  (MINICOG_Responses) I
  let
    responses: I.item,
    word_recall_value: GetResponseValueByLinkId('minicog-question1', responses),
    clock_draw_value: GetResponseValueByLinkId('minicog-question2', responses),
    word_recall_score: if word_recall_value is not null then word_recall_value.value.value else null,
    clock_draw_score: if clock_draw_value is not null then clock_draw_value.value.value else null
  return 
    if word_recall_score is not null and clock_draw_score is null then word_recall_score as Integer
    else if clock_draw_score is not null and word_recall_score is null then clock_draw_score as Integer
    else if word_recall_score is not null and clock_draw_score is not null then (word_recall_score as Integer) + (clock_draw_score as Integer)
    else null


define SLUMS_Questionnaire:
  getQuestionnaire('SLUMS')

define SLUMS_Responses:
  MatchedReponsesByQuestionnaire([QuestionnaireResponse], SLUMS_Questionnaire)

define SLUMS_Score:
  (SLUMS_Responses) I
    let answerValue : GetResponseValueByLinkId('minicog-question2', I.item)
    return if answerValue is not null then answerValue.value.value as Integer
    else null


// TODO generalize, call by Questionnaire.id
// define PHQ9_Responses:
//   ([QuestionnaireResponse] QR
//     where (
//       (PositionOf(PHQ9_Questionnaire.id, QR.questionnaire.value)  != -1 or
//       PositionOf(PHQ9_Questionnaire.name, QR.questionnaire.value) != -1) and
//       date from QR.authored.value >= Today() and 
//       QR.status.value = 'completed'
//     )
//     sort by authored desc
//   )

// define GAD7_Responses:
//   ([QuestionnaireResponse] QR
//     where (
//       (PositionOf(GA7_Questionnaire.id, QR.questionnaire.value)  != -1 or
//       PositionOf(GA7_Questionnaire.name, QR.questionnaire.value) != -1) and
//       date from QR.authored.value >= Today() and 
//       QR.status.value = 'completed'
//     )
//     sort by authored desc
//   )

// define PresentPHQ9:
//   (Length(PHQ9_Responses)) l
//   return 
//     if l != 0 then null 
//     else PHQ9_Questionnaire.id.value
  
// define PresentGAD7:
//   (Length(GAD7_Responses)) l 
//   return 
//     if l != 0 then null
//     else GA7_Questionnaire.id.value
