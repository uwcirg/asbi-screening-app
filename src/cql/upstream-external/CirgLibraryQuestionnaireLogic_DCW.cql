library CirgLibraryQuestionnaireLogic_DCW version '0.1.0'

using FHIR version '4.0.1'

include "FHIRHelpers" version '4.0.1' called FHIRHelpers

context Patient

// helper functions
/*
 * return the numeric value of type Integer for the answer from the extension element
 * @param a list of elements of type FHIR.Extension
 */
define function getAnswerOptionExtensionValue(extList List<FHIR.Extension>):
  (extList e where e.url ~ 'http://hl7.org/fhir/StructureDefinition/ordinalValue')[0].value.value as Integer
/*
 * return the numeric value as Integer for the answer based on value code
 * @param questionnaire as FHIR.Questionnaire where code in question is queried
 * @param code as String
 */
define function getAnswerValueByCode(questionnaire FHIR.Questionnaire, code String):
  (singleton from ((questionnaire.item.answerOption) Q where Q.value.code = code)) a
  let 
    extensionItem: a.extension
  return if extensionItem is not null then getAnswerOptionExtensionValue(extensionItem) else (0 as Integer)

/*
 * return the numeric value as Integer for an questionnaire response item
 * @param questionnaire as FHIR.Questionnaire where answer option code based on link id will be queried
 * @param responses as a list of FHIR.QuestionnaireResponse.Item
 * @param linkId as String
 */
define function getValueByResponseItem(questionnaire FHIR.Questionnaire, responses List<FHIR.QuestionnaireResponse.Item>, linkId String):
  (singleton from (((responses) o where o.linkId.value = linkId) I
  return 
    if I is null then ({null as Integer})
    else
      if I.answer[0].value.code is not null then getAnswerValueByCode(questionnaire, I.answer[0].value.code.value) else 0 as Integer))

/*
 * return questionnaire responses of type FHIR.QuestionnaireResponse matched to the target questionnaire
 * @param responses as FHIR.QuestionnaireResponse
 * @param questionnaire as FHIR.Questionnaire to match against
 */
define function MatchedReponsesByQuestionnaire(responses List<FHIR.QuestionnaireResponse>, targetQuestionnaire FHIR.Questionnaire):
  ((responses) Q
    where 
    (
      (
        PositionOf(Lower(targetQuestionnaire.name), Lower(Q.questionnaire.value)) != -1 or
        PositionOf(Lower(targetQuestionnaire.id), Lower(Q.questionnaire.value)) != -1
      ) and 
      Q.status.value = 'completed')
    sort by authored desc, meta.lastUpdated.value desc
  )
  

/*
 * return answer value FHIR object by response item of FHIR.QuestionnaireResponse.Item
 * @param linkId of the response item as String
 * @param responses as a list of FHIR.QuestionnaireResponse.Item
 */
define function GetResponseValueByLinkId(linkId String, responses List<FHIR.QuestionnaireResponse.Item>):
  (responses r where r.linkId.value = linkId) I
  return I.answer[0].value

/*
 * return FHIR Questionnaire object
 * 
 */
define function getQuestionnaire(matchedString String):
  First([Questionnaire] Q
    where 
      PositionOf(Lower(matchedString), Lower(Q.id)) != -1 or
      PositionOf(Lower(matchedString), Lower(Q.name)) != -1 or
      PositionOf(Lower(Q.name), Lower(matchedString)) != -1 or
      Lower(Q.name) = Lower(matchedString)
  )

// Logic for presenting questionnaire

// default scheduled timing for administering questionnaire
define Scheduled_Timing: Tuple {
  repeat: {
    frequency: 1,
    period: 1,
    periodUnit: 'd'
  }
}

define dcw_care_partner_present:
// TODO check Care Partner present (via CP gateway question, or field in FHIR?)
  true

define dcw_cog_level_1:
// if (no dementia condition)
  not HasDementia

define dcw_cog_level_2:
// if (dementia condition)
// and/or 
// CIRG-MINICOG score is fail
// a failed score is 0,1,2, or 3
  if HasDementia is true then true
  else if First(MINICOG_Score) <= 3 then true
  else false

define dcw_mood_level_1:
  dcw_care_partner_present

define dcw_mood_level_2:
// if (
//   depression condition ("F32.A - Depression, unspecified" and "F33.1 - Major Depressive Disorder, Recurrent, Moderate")
//   and/or 
//   anxiety condition ("F41.1 - Generalized Anxiety Disorder" - not present in our 3 test patients...)
//   and/or 
//   CIRG-BEHAV5 score is fail 
// )
  if HasMoodConditions is true then true 
  else if First(BEHAV5_Score) <= 7 then true
  else false

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
  (["Condition"] C where (
    C.code.coding[0].code.value = 'F03.9' or
    C.code.coding[0].code.value = 'F01.5' or
    C.code.coding[0].code.value = 'G31.0' or
    C.code.coding[0].code.value = 'G20' or
    C.code.coding[0].code.value = 'F03.91'
  ))

define HasDementia:
  Length(DementiaConditions) > 0

define LessThanHighSchoolCondition:
  ["Condition"] C where (
    C.code.coding[0].code.value = 'Z55.5'
  )

define HasHigerLevelEducation:
  Length(LessThanHighSchoolCondition) < 1

//   depression condition ("F32.A - Depression, unspecified" and "F33.1 - Major Depressive Disorder, Recurrent, Moderate")
//   and/or 
//   anxiety condition ("F41.1 - Generalized Anxiety Disorder" - not present in our 3 test patients...)

define MoodConditions: 
  ["Condition"] C where (
    C.code.coding[0].code.value = 'F32.A' or
    C.code.coding[0].code.value = 'F33.1' or
    C.code.coding[0].code.value = 'F41.1'
  )

define HasMoodConditions:
  Length(MoodConditions) > 0


// Naming pattern: "CIRG_MINICOG" is Questionnaire.id
define PresentQnr_CIRG_MINICOG:
  if dcw_cog_level_1 is true then {
    id: 'CIRG-MINICOG',
    schedule: Scheduled_Timing
  } else null

define PresentQnr_CIRG_ECOG12:
  if dcw_cog_level_1 is true then {
    id: 'CIRG-ECOG12',
    schedule: Scheduled_Timing
  }
  else null

define PresentQnr_CIRG_CP_ECOG:
  if dcw_cog_level_1 is true and dcw_care_partner_present is true then {
    id: 'CIRG-CP-ECOG',
    schedule: Scheduled_Timing
  } else null

define PresentQnr_CIRG_SLUMS:
  if dcw_cog_level_2 is true then {
    id: 'CIRG-SLUMS',
    schedule: Scheduled_Timing
  } else null

define PresentQnr_CIRG_ADL_IADL:
  if dcw_cog_level_2 is true and dcw_care_partner_present is true then {
    id: 'CIRG-ADL-IADL',
    schedule: Scheduled_Timing
  } else null

define PresentQnr_CIRG_BEHAV5:
  if dcw_mood_level_1 is true then {
    id: 'CIRG-BEHAV5',
    schedule: Scheduled_Timing
  } else null

define PresentQnr_CIRG_GAD7:
 // CIRG-SLUMS score is Normal or Mild Neurocognitive Disorder
  if dcw_mood_level_2 is true and (HasNormalSLUMSScore is true or HasMildNeuroCognitiveDisorderSLUMSScore is true) then {
    id: 'CIRG-GAD7',
    schedule: Scheduled_Timing
  } else null

define PresentQnr_CIRG_GDS:
  // CIRG-SLUMS score is Normal or Mild Neurocognitive Disorder
  if dcw_mood_level_2 is true and (HasNormalSLUMSScore is true or HasMildNeuroCognitiveDisorderSLUMSScore is true) then {
    id: 'CIRG-GDS',
    schedule: Scheduled_Timing
  } else null

define PresentQnr_CIRG_C_IDAS:
  // CIRG-SLUMS score indicates dementia 
  if dcw_mood_level_2 is true and 
     dcw_care_partner_present is true and 
     HasSLUMSDementiaScore is true
  then {
    id: 'CIRG-C-IDAS',
    schedule: Scheduled_Timing
  } else null

define BEHAV5_Questionnaire:
  getQuestionnaire('BEHAV5')

define BEHAV5_Responses:
  MatchedReponsesByQuestionnaire([QuestionnaireResponse], BEHAV5_Questionnaire)

define BEHAV5_Score:
  (BEHAV5_Responses) I
  return if Length(I) < 1 then null else 
  (
    Coalesce(First(getValueByResponseItem(BEHAV5_Questionnaire, I.item, 'behav-1')), 0) +
    Coalesce(First(getValueByResponseItem(BEHAV5_Questionnaire, I.item, 'behav-2')), 0) +
    Coalesce(First(getValueByResponseItem(BEHAV5_Questionnaire, I.item, 'behav-3')), 0) + 
    Coalesce(First(getValueByResponseItem(BEHAV5_Questionnaire, I.item, 'behav-4')), 0) +
    Coalesce(First(getValueByResponseItem(BEHAV5_Questionnaire, I.item, 'behav-5')), 0) +
    Coalesce(First(getValueByResponseItem(BEHAV5_Questionnaire, I.item, 'behav-6')), 0)
  )

define MINICOG_Questionnaire:
  getQuestionnaire('MINICOG')

define MINICOG_Responses:
  MatchedReponsesByQuestionnaire([QuestionnaireResponse], MINICOG_Questionnaire)

define MINICOG_Word_Recall_Score:
(MINICOG_Responses) I
  let
    responses: I.item,
    word_recall_value: First(GetResponseValueByLinkId('minicog-question1', responses))
  return if word_recall_value.value is null then null else word_recall_value.value as Integer

define MINICOG_Clock_Draw_Score:
(MINICOG_Responses) I
  let
    responses: I.item,
    clock_draw_value: First(GetResponseValueByLinkId('minicog-question2', responses))
  return if clock_draw_value is null then null else clock_draw_value.value as Integer 

define MINICOG_Score:
  (MINICOG_Responses) I
  let
    responses: I.item,
    word_recall_value: First(MINICOG_Word_Recall_Score),
    clock_draw_value: First(MINICOG_Clock_Draw_Score),
    word_recall_score: if word_recall_value is not null then word_recall_value else null,
    clock_draw_score: if clock_draw_value is not null then clock_draw_value else null
  return 
    if (Length(responses) < 1) then null
    else if word_recall_score is not null and clock_draw_score is null then word_recall_score
    else if clock_draw_score is not null and word_recall_score is null then clock_draw_score
    else if word_recall_score is not null and clock_draw_score is not null then word_recall_score + clock_draw_score
    else null


define SLUMS_Questionnaire:
  getQuestionnaire('SLUMS')

define SLUMS_Responses:
  MatchedReponsesByQuestionnaire([QuestionnaireResponse], SLUMS_Questionnaire)

define SLUMS_Score:
  (SLUMS_Responses) I
    let answerValue : First(GetResponseValueByLinkId('/71492-3', I.item))
    return 
      if Length(I) < 1 then null
      else if answerValue is not null then answerValue.value as Integer
      else null

define HasSLUMSDementiaScore:
  if HasHigerLevelEducation is true then First(SLUMS_Score) >= 1 and First(SLUMS_Score) <= 20
  else First(SLUMS_Score) >= 1 and First(SLUMS_Score) <= 19

define HasNormalSLUMSScore:
  if HasHigerLevelEducation is true then First(SLUMS_Score) >= 27
  else First(SLUMS_Score) >= 25

define HasMildNeuroCognitiveDisorderSLUMSScore:
  if HasHigerLevelEducation is true then First(SLUMS_Score) >= 21 and First(SLUMS_Score) <= 26
  else First(SLUMS_Score) >= 20 and First(SLUMS_Score) <= 24
