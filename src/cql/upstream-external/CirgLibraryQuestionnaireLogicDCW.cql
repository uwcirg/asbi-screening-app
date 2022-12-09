library CirgLibraryQuestionnaireLogicDCW version '0.1.0'

using FHIR version '4.0.1'

include "FHIRHelpers" version '4.0.1' called FHIRHelpers

context Patient

define dcw_cog_level_1:
// if (no dementia condition)
  return true

// Naming pattern: "CIRG-ECOG12" is Questionnaire.id
define PresentQnr_CIRG-ECOG12:
// if dcw_cog_level_1 
  return true

define PresentQnr_CIRG-CP-ECOG:
// if dcw_cog_level_1 
// and
// Care Partner present (via CP gateway question, or field in FHIR?)
  return true

define PresentQnr_CIRG-MINICOG:
// if dcw_cog_level_1 
  return true

define dcw_cog_level_2:
// if (dementia condition)
// and/or 
// CIRG-MINICOG score is fail 
  return true

define PresentQnr_CIRG-SLUMS:
// if dcw_cog_level_2
  return true

define PresentQnr_CIRG-ADL-IADL:
// if dcw_cog_level_2
// and
// Care Partner present (via CP gateway question, or field in FHIR?)
  return true

define dcw_mood_level_1:
// if
// Care Partner present (via CP gateway question, or field in FHIR?)
  return true

define PresentQnr_CIRG-BEHAV5:
// if dcw_mood_level_1
  return true

define dcw_mood_level_2:
// if (
//   depression condition
//   and/or 
//   anxiety condition
//   and/or 
//   CIRG-BEHAV5 score is fail 
// )
  return true

define PresentQnr_CIRG-GAD7:
// if 
//   dcw_mood_level_2
// and
//   CIRG-SLUMS score is Normal or Mild Neurocognitive Disorder 
  return true

define PresentQnr_CIRG-GDS:
// if 
//   dcw_mood_level_2
// and
//   CIRG-SLUMS score is Normal or Mild Neurocognitive Disorder 
  return true

define PresentQnr_CIRG-C-IDAS:
// if 
//   dcw_mood_level_2
// and
//   CIRG-SLUMS score indicates dementia 
// and
//   Care Partner present (via CP gateway question, or field in FHIR?)
  return true


// below from: https://github.com/uwcirg/asbi-screening-app/blob/feature/apply-plandefinition-without-encender/src/cql/upstream-external/QuestionnaireLogicLibrary_PHQ9_GAD7.cql

define function getQuestionnaire(questionnaireName String):
  First([Questionnaire] Q
    where 
      PositionOf(Lower(questionnaireName), Lower(Q.id)) != -1 or
      PositionOf(Lower(questionnaireName), Lower(Q.name)) != -1 or
      Lower(Q.name) = Lower(questionnaireName)
  )

// TODO generalize, call by Questionnaire.id
define PHQ9_Questionnaire:
  getQuestionnaire('PHQ9')

define GA7_Questionnaire:
  getQuestionnaire('GAD7')

// TODO generalize, call by Questionnaire.id
define PHQ9_Responses:
  ([QuestionnaireResponse] QR
    where (
      (PositionOf(PHQ9_Questionnaire.id, QR.questionnaire.value)  != -1 or
      PositionOf(PHQ9_Questionnaire.name, QR.questionnaire.value) != -1) and
      date from QR.authored.value >= Today() and 
      QR.status.value = 'completed'
    )
    sort by authored desc
  )

define GAD7_Responses:
  ([QuestionnaireResponse] QR
    where (
      (PositionOf(GA7_Questionnaire.id, QR.questionnaire.value)  != -1 or
      PositionOf(GA7_Questionnaire.name, QR.questionnaire.value) != -1) and
      date from QR.authored.value >= Today() and 
      QR.status.value = 'completed'
    )
    sort by authored desc
  )

define PresentPHQ9:
  (Length(PHQ9_Responses)) l
  return 
    if l != 0 then null 
    else PHQ9_Questionnaire.id.value
  
define PresentGAD7:
  (Length(GAD7_Responses)) l 
  return 
    if l != 0 then null
    else GA7_Questionnaire.id.value


