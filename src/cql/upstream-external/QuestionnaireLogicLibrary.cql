library QuestionnaireLogicLibrary version '1.0.0'

using FHIR version '4.0.1'

include "FHIRHelpers" version '4.0.1' called FHIRHelpers

define function getQuestionnaire(questionnaireName String):
  First([Questionnaire] Q
    where 
      PositionOf(Lower(questionnaireName), Lower(Q.id)) != -1 or
      PositionOf(Lower(questionnaireName), Lower(Q.name)) != -1 or
      Lower(Q.name) = Lower(questionnaireName)
  )
define PHQ9_Questionnaire:
  getQuestionnaire('PHQ9')

define GA7_Questionnaire:
  getQuestionnaire('GAD7')

define PHQ9_Responses:
  ([QuestionnaireResponse] QR
    where (
      (PositionOf(PHQ9_Questionnaire.id, QR.questionnaire.value)  != -1 or
      PositionOf(PHQ9_Questionnaire.name, QR.questionnaire.value) != -1) and
      date from QR.authored.value >= Today() and 
      QR.status.value = 'complete'
    )
    sort by authored desc
  )

define GAD7_Responses:
  ([QuestionnaireResponse] QR
    where (
      (PositionOf(GA7_Questionnaire.id, QR.questionnaire.value)  != -1 or
      PositionOf(GA7_Questionnaire.name, QR.questionnaire.value) != -1) and
      date from QR.authored.value >= Today() and 
      QR.status.value = 'complete'
    )
    sort by authored desc
  )

define PresentPHQ9:
  Length(PHQ9_Responses) = 0
  
define PresentGAD7:
  Length(GAD7_Responses) = 0
