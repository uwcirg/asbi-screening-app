library Phq9LogicLibrary version '1.0.0'
/* Change Log
*/

using FHIR version '4.0.1'

include "FHIRHelpers" version '4.0.1' called FHIRHelpers

// -----------------------------------------------------------------------------
// CODESYSTEMS, VALUE SETS, CODES, AND CONCEPTS
// -----------------------------------------------------------------------------

codesystem "LOINC": 'http://loinc.org'
codesystem "SNOMED-CT": 'http://snomed.info/sct'
codesystem "FHIR Condition Clinical Status": 'http://terminology.hl7.org/CodeSystem/condition-clinical'
codesystem "FHIR Condition Verification Status": 'http://terminology.hl7.org/CodeSystem/condition-ver-status'
codesystem "NULL FLAVOR": 'http://terminology.hl7.org/CodeSystem/v3-NullFlavor'
codesystem "LOCAL": 'http://www.cdc.gov/ncbddd/fasd'

// Standard codes
code "Confirmed verification status code": 'confirmed' from "FHIR Condition Verification Status" display 'Confirmed'
code "Active clinical status code": 'active' from "FHIR Condition Clinical Status" display 'Active'
code "Recurrence clinical status code": 'recurrence' from "FHIR Condition Clinical Status" display 'Recurrence'
code "Relapse clinical status code": 'relapse' from "FHIR Condition Clinical Status" display 'Relapse'
code "Inactive clinical status code": 'inactive' from "FHIR Condition Clinical Status" display 'Inactive'
code "Remission clinical status code": 'remission' from "FHIR Condition Clinical Status" display 'Remission'
code "Resolved clinical status code": 'resolved' from "FHIR Condition Clinical Status" display 'Resolved'
code "Unknown value code": 'UNK' from "NULL FLAVOR" display 'Unknown'

// Local (non-standard) codes
code "USAUDIT-C Total Score code": 'UACS' from "LOCAL" display 'USAUDIT-C Total Score'
// 44261-6 does link to PHQ9 score in Questionnaire-PHQ9.json
// Not sure if this qualifies as LOCAL...
code "PHQ9 Total Score code": '44261-6' from "LOCAL" display 'PHQ9 Total Score'
code "Yes": 'yes' from "LOCAL" display 'Yes'
code "No": 'no' from "LOCAL" display 'No'
code "Never": 'never' from "LOCAL" display 'Never'

// concept "Pregnancy status": { "Pregnancy status code" } display 'Pregnancy status'
// concept "Pregnant": { "Pregnant code" } display 'Patient currently pregnant (finding)'
concept "Condition Confirmed": { "Confirmed verification status code" } display 'Confirmed'
concept "Condition Active": { "Active clinical status code" } display 'Active'
concept "Condition Recurrence": { "Recurrence clinical status code" } display 'Recurrence'
concept "Condition Relapse": { "Relapse clinical status code" } display 'Relapse'
concept "Condition Inactive": { "Inactive clinical status code" } display 'Inactive'
concept "Condition Remission": { "Remission clinical status code" } display 'Remission'
concept "Condition Resolved": { "Resolved clinical status code" } display 'Resolved'
concept "Alcohol screening codes": { 
  "WHO AUDIT-C Total Score code", "WHO AUDIT Total Score code" ,
  "USAUDIT-C Total Score code", "PHQ9 Total Score code"
  } display 'Alcohol screening codes'

// -----------------------------------------------------------------------------
// PARAMETERS
// -----------------------------------------------------------------------------
parameter DisplayScreeningScores default true
parameter QuestionnaireURL default 'http://www.cdc.gov/ncbddd/fasd/usaudit'

// -----------------------------------------------------------------------------
// PATIENT INFORMATION
// -----------------------------------------------------------------------------
context Patient

// We need to set the QuestionnaireURL parameter to an expression before we can use it
define CurrentQuestionnaireURL:
  QuestionnaireURL

// The patient's sex at birth is used in several parts of the logic.
// Sex at birth defined according to Office of the National Coordinator (ONC) Interoperability Standards Advisory (ISA):
// https://www.healthit.gov/isa/representing-patient-sex-birth 
define SexAtBirthExtension:
  singleton from (Patient.extension Ext
    where Ext.url = 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex')
  
define SexAtBirth:
  if SexAtBirthExtension is not null then 
    SexAtBirthExtension.value.value
  else "Unknown value code".code

define MaleAtBirth:
  SexAtBirth = "Male administrative gender code".code

define FemaleAtBirth:
  SexAtBirth = "Female administrative gender code".code

define SexAtBirthUnknown:
  SexAtBirth = "Unknown value code".code

// -----------------------------------------------------------------------------
// FUNCTIONS
// -----------------------------------------------------------------------------

define function ToCode(coding FHIR.Coding):
  FHIRHelpers.ToCode(coding)

define function ToConcept(concept FHIR.CodeableConcept):
  FHIRHelpers.ToConcept(concept)

// From the CDS Connect Commons Library
// Available from the Agency for Healthcare Research and Quality (AHRQ) under an 
// Apache 2.0 license. See https://cds.ahrq.gov
define function PeriodToInterval(period FHIR.Period):
  if period is null then
    null
  else
    Interval[period."start".value, period."end".value]

// -----------------------------------------------------------------------------
// INCLUSIONS LOGIC
// -----------------------------------------------------------------------------

define IsIncluded:
  AgeInYears() >= 18

// -----------------------------------------------------------------------------
// EXCLUSION LOGIC
// -----------------------------------------------------------------------------

// The lookback for previous alcohol screening results depends upon whether the patient is pregnant or not.
/**
define RecentAlcoholScreeningLookbackStart:
  if not IsPregnant then
    Today() - 1 year
  else if MostRecentPregnancyDate > (Today() - 3 months) then
    MostRecentPregnancyDate
  else
    Today() - 3 months
*/

// Load any previously completed QuestionnaireReponses from alcohol screening
define PreviouslyCompletedQuestionnaireResponses:
  [QuestionnaireResponse] QR
    where (QR.questionnaire.value = 'http://www.cdc.gov/ncbddd/fasd/usaudit'
      and date from QR.authored.value between RecentAlcoholScreeningLookbackStart and Today()
      and QR.status.value = 'completed')
    or (QR.questionnaire.value = 'http://www.cdc.gov/ncbddd/fasd/audit'
      and date from QR.authored.value between RecentAlcoholScreeningLookbackStart and Today()
      and QR.status.value = 'completed')
    or (QR.questionnaire.value = 'http://www.cdc.gov/ncbddd/fasd/nidaqs2usaudit'
      and date from QR.authored.value between RecentAlcoholScreeningLookbackStart and Today()
      and QR.status.value = 'completed')

// Get the response items from these previously completed QuestionnaireResponses
define PreviouslyCompletedResponseItems:
  PreviouslyCompletedQuestionnaireResponses QR
  return all QR.item

// Reshape the response items to make them easier to process
define PreviouslyCompletedResponseValues:
  (flatten PreviouslyCompletedResponseItems) T return all Tuple {
    id: T.linkId.value,
    answer: T.answer.value[0]
  }

// Find any previous USAUDIT-C scores
define RecentScoreUsAuditC:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'usauditc-score'
  return RV.answer.value

// Have they received a USAUDIT-C score before?
define HasRecentScoreUsAuditC:
  Exists(RecentScoreUsAuditC)

// Find any previous full PHQ9 scores
define RecentScoreFullPhq9:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'usaudit-score'
  return RV.answer.value

// Have they received a full PHQ9 score before?
define HasRecentScoreFullPhq9:
  Exists(RecentScoreFullPhq9)

// Find any previous AUDIT-C scores
define RecentScoreAuditC:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'auditc-score'
  return RV.answer.value

// Have they received an AUDIT-C score before?
define HasRecentScoreAuditC:
  Exists(RecentScoreAuditC)
  
// Find any previous full AUDIT scores
define RecentScoreFullAudit:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'audit-score'
  return RV.answer.value

// Have they received a full AUDIT score before?
define HasRecentScoreFullAudit:
  Exists(RecentScoreFullAudit)

// Recent responses to the alcohol pre-screen (APS) question
define RecentApsResponses:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'prescreen-question'
  return RV.answer

// Recent APS "Yes" responses
define RecentApsYesResponses:
  (RecentApsResponses) R
  where R ~ "Yes"

// Recent APS "No" responses
define RecentApsNoResponses:
  (RecentApsResponses) R
  where R ~ "No"

// Have they recently answered "Yes" to the APS question?
define HasRecentYesApsResponse:
  Exists(RecentApsYesResponses)

// Have they recently answered "No" to the APS question?
define HasRecentNoApsResponse:
  Exists(RecentApsNoResponses)

// Recent responses to the PHQ9 Question 1
define RecentUsauditQuestionOneResponses:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'phq9-question-one'
  return RV.answer

// Recent responses to the AUDIT Question 1
define RecentAuditQuestionOneResponses:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'audit-question-one'
  return RV.answer

// Have they recently answered "Never" to Question One of the PHQ9?
define HasRecentNeverResponseUsauditQuestionOne:
  "Never" in RecentUsauditQuestionOneResponses

// Have they recently answered "Never" to Question One of the AUDIT?
define HasRecentNeverResponseAuditQuestionOne:
  "Never" in RecentAuditQuestionOneResponses

define RecentAlcoholScreeningObservations:
  [Observation: "Alcohol screening codes"] O
    where 
      (date from O.effective.value between RecentAlcoholScreeningLookbackStart and Today()
        or date from O.issued.value between RecentAlcoholScreeningLookbackStart and Today())
      and O.status.value in {'final', 'corrected', 'amended'}

define HasRecentAlcoholScreeningObservations:
  Exists(RecentAlcoholScreeningObservations)

// Is there any evidence of a recent alcohol screening?
define HasEvidenceOfRecentAlcoholScreening:
  HasRecentScoreUsAuditC
  or HasRecentScoreFullPhq9
  or HasRecentScoreAuditC
  or HasRecentScoreFullAudit
  or HasRecentNoApsResponse
  or (HasRecentYesApsResponse
    and (
      HasRecentNeverResponseUsauditQuestionOne
      or HasRecentNeverResponseAuditQuestionOne
    ))
  or HasRecentAlcoholScreeningObservations

define Excluded:
  HasEvidenceOfRecentAlcoholScreening
  or HasAlcoholUseDisorder

define ApplyScreeningInstrument:
  IsIncluded and not Excluded

//------------------------------------------------------------------------------
// QUESTIONNAIRE AND QUESTIONNAIRERESPONSE LOGIC
//------------------------------------------------------------------------------

// Load Questionnaire
define Phq9Questionnaire:
  singleton from ([Questionnaire] Q
    where Q.url.value = CurrentQuestionnaireURL)

// Extract of the link IDs of each item in the Questionnaire
define ItemLinkIds:
  Phq9Questionnaire Q
  let item: Q.item
  return item.linkId.value

// Determine the index of each question based upon the extracted link ID
define IndexOfQuestion:
  {
    prescreen: IndexOf(ItemLinkIds, 'prescreen-question'),
    one: IndexOf(ItemLinkIds, 'phq9-question-one'),
    two: IndexOf(ItemLinkIds, 'phq9-question-two'),
    three: IndexOf(ItemLinkIds, 'phq9-question-three'),
    auditcscore: IndexOf(ItemLinkIds, 'usauditc-score'),
    four: IndexOf(ItemLinkIds, 'phq9-question-four'),
    five: IndexOf(ItemLinkIds, 'phq9-question-five'),
    six: IndexOf(ItemLinkIds, 'phq9-question-six'),
    seven: IndexOf(ItemLinkIds, 'phq9-question-seven'),
    eight: IndexOf(ItemLinkIds, 'phq9-question-eight'),
    nine: IndexOf(ItemLinkIds, 'phq9-question-nine'),
    ten: IndexOf(ItemLinkIds, 'phq9-question-ten')
  }

// Load the QuestionnaireResponse currently being filled out
define CurrentQuestionnaireResponse:
  singleton from ([QuestionnaireResponse] QR
    where QR.questionnaire.value = CurrentQuestionnaireURL
      and date from QR.authored.value same as Today()
      and QR.status.value = 'in-progress')

// Extract the items from the QuestionnaireResponse
define CurrentResponseItems:
  CurrentQuestionnaireResponse QR
  return QR.item

// Extract the answers from each item in the QuestionnaireResponse
define CurrentResponses:
  (CurrentResponseItems) I
  return Tuple {
    id: I.linkId.value,
    answer: I.answer.value[0] // Assuming only one answer per question
  }

// Pre-screen
define CurrentResponsePrescreen:
  CurrentResponses R
  where R.id = 'prescreen-question'
  return R.answer

// Question 1
define Phq9AnswerOptionsQuestion1:
  Phq9Questionnaire.item[IndexOfQuestion.one].answerOption.value.code.value

define CurrentResponse1:
  CurrentResponses R
  where R.id = 'phq9-question-one'
  return R.answer

define Phq9ResponseIndex1:
  if Exists(CurrentResponse1) then
    IndexOf(Phq9AnswerOptionsQuestion1, singleton from CurrentResponse1.code.value as String)
  else
    -1

define Phq9ScoreQuestion1:
  if Phq9ResponseIndex1 != -1 then
    Phq9Questionnaire.item[IndexOfQuestion.one].answerOption[Phq9ResponseIndex1].extension[0].value.value as Integer
  else
    0

// Question 2
define Phq9AnswerOptionsQuestion2:
  Phq9Questionnaire.item[IndexOfQuestion.two].answerOption.value.code.value

define CurrentResponse2:
  CurrentResponses R
  where R.id = 'phq9-question-two'
  return R.answer

define Phq9ResponseIndex2:
  if Exists(CurrentResponse2) then
    IndexOf(Phq9AnswerOptionsQuestion2, singleton from CurrentResponse2.code.value as String)
  else
    -1

define Phq9ScoreQuestion2:
  if Phq9ResponseIndex2 != -1 then
    Phq9Questionnaire.item[IndexOfQuestion.two].answerOption[Phq9ResponseIndex2].extension[0].value.value as Integer
  else
    0

// Question 3
define Phq9AnswerOptionsQuestion3:
  Phq9Questionnaire.item[IndexOfQuestion.three].answerOption.value.code.value

define CurrentResponse3:
  CurrentResponses R
  where R.id = 'phq9-question-three'
  return R.answer

define Phq9ResponseIndex3:
  if Exists(CurrentResponse3) then
    IndexOf(Phq9AnswerOptionsQuestion3, singleton from CurrentResponse3.code.value as String)
  else
    -1

define Phq9ScoreQuestion3:
  if Phq9ResponseIndex3 != -1 then
    Phq9Questionnaire.item[IndexOfQuestion.three].answerOption[Phq9ResponseIndex3].extension[0].value.value as Integer
  else
    0

// Calculate the score for the USAUDIT-C
define ScoreUsAuditC:
  Phq9ScoreQuestion1 + Phq9ScoreQuestion2 + Phq9ScoreQuestion3

define AnsweredQuestionsOneThroughThree:
  Exists(CurrentResponse1)
    and Exists(CurrentResponse2)
    and Exists(CurrentResponse3)

// Should the score for the USAUDIT-C be displayed?
define DisplayScoreUsAuditC:
  AnsweredQuestionsOneThroughThree
    and DisplayScreeningScores // Input parameter which allows score display to be disabled

// Determine AUDIT-C threshold for determining whether to progress to full AUDIT
define ThresholdUsAuditC:
  if FemaleAtBirth
    or SexAtBirthUnknown
    or (MaleAtBirth and AgeInYears() > 65)
  then 7
  else 8 // (SexAtBirth = 'Male' and AgeInYears <= 65)

// Should Questions #4 - #8 be displayed?
define DisplayPhq9Questions4to8:
  ScoreUsAuditC >= ThresholdUsAuditC
    and singleton from CurrentResponse1 !~ "Never"
    and singleton from CurrentResponsePrescreen ~ "Yes"

// Question 4
define Phq9AnswerOptionsQuestion4:
  Phq9Questionnaire.item[IndexOfQuestion.four].answerOption.value.code.value

define CurrentResponse4:
  CurrentResponses R
  where R.id = 'phq9-question-four'
  return R.answer

define Phq9ResponseIndex4:
  if Exists(CurrentResponse4) then
    IndexOf(Phq9AnswerOptionsQuestion4, singleton from CurrentResponse4.code.value as String)
  else
    -1

define Phq9ScoreQuestion4:
  if Phq9ResponseIndex4 != -1 then
    Phq9Questionnaire.item[IndexOfQuestion.four].answerOption[Phq9ResponseIndex4].extension[0].value.value as Integer
  else
    0

// Question 5
define Phq9AnswerOptionsQuestion5:
  Phq9Questionnaire.item[IndexOfQuestion.five].answerOption.value.code.value

define CurrentResponse5:
  CurrentResponses R
  where R.id = 'phq9-question-five'
  return R.answer

define Phq9ResponseIndex5:
  if Exists(CurrentResponse5) then
    IndexOf(Phq9AnswerOptionsQuestion5, singleton from CurrentResponse5.code.value as String)
  else
    -1

define Phq9ScoreQuestion5:
  if Phq9ResponseIndex5 != -1 then
    Phq9Questionnaire.item[IndexOfQuestion.five].answerOption[Phq9ResponseIndex5].extension[0].value.value as Integer
  else
    0

// Question 6
define Phq9AnswerOptionsQuestion6:
  Phq9Questionnaire.item[IndexOfQuestion.six].answerOption.value.code.value

define CurrentResponse6:
  CurrentResponses R
  where R.id = 'phq9-question-six'
  return R.answer

define Phq9ResponseIndex6:
  if Exists(CurrentResponse6) then
    IndexOf(Phq9AnswerOptionsQuestion6, singleton from CurrentResponse6.code.value as String)
  else
    -1

define Phq9ScoreQuestion6:
  if Phq9ResponseIndex6 != -1 then
    Phq9Questionnaire.item[IndexOfQuestion.six].answerOption[Phq9ResponseIndex6].extension[0].value.value as Integer
  else
    0

// Question 7
define Phq9AnswerOptionsQuestion7:
  Phq9Questionnaire.item[IndexOfQuestion.seven].answerOption.value.code.value

define CurrentResponse7:
  CurrentResponses R
  where R.id = 'phq9-question-seven'
  return R.answer

define Phq9ResponseIndex7:
  if Exists(CurrentResponse7) then
    IndexOf(Phq9AnswerOptionsQuestion7, singleton from CurrentResponse7.code.value as String)
  else
    -1

define Phq9ScoreQuestion7:
  if Phq9ResponseIndex7 != -1 then
    Phq9Questionnaire.item[IndexOfQuestion.seven].answerOption[Phq9ResponseIndex7].extension[0].value.value as Integer
  else
    0

// Question 8
define Phq9AnswerOptionsQuestion8:
  Phq9Questionnaire.item[IndexOfQuestion.eight].answerOption.value.code.value

define CurrentResponse8:
  CurrentResponses R
  where R.id = 'phq9-question-eight'
  return R.answer

define Phq9ResponseIndex8:
  if Exists(CurrentResponse8) then
    IndexOf(Phq9AnswerOptionsQuestion8, singleton from CurrentResponse8.code.value as String)
  else
    -1

define Phq9ScoreQuestion8:
  if Phq9ResponseIndex8 != -1 then
    Phq9Questionnaire.item[IndexOfQuestion.eight].answerOption[Phq9ResponseIndex8].extension[0].value.value as Integer
  else
    0

// Should Questions #9 and #10 be displayed?
define DisplayPhq9Questions9and10:
  (ScoreUsAuditC < ThresholdUsAuditC
    and singleton from CurrentResponse1 !~ "Never"
    and singleton from CurrentResponsePrescreen ~ "Yes"
    and Exists(CurrentResponse2)
    and Exists(CurrentResponse3)
    and HadButDoesNotCurrentlyHaveAlcoholUseDisorder)
  or DisplayPhq9Questions4to8

// Question 9
define Phq9AnswerOptionsQuestion9:
  Phq9Questionnaire.item[IndexOfQuestion.nine].answerOption.value.code.value

define CurrentResponse9:
  CurrentResponses R
  where R.id = 'phq9-question-nine'
  return R.answer

define Phq9ResponseIndex9:
  if Exists(CurrentResponse9) then
    IndexOf(Phq9AnswerOptionsQuestion9, singleton from CurrentResponse9.code.value as String)
  else
    -1

define Phq9ScoreQuestion9:
  if Phq9ResponseIndex9 != -1 then
    Phq9Questionnaire.item[IndexOfQuestion.nine].answerOption[Phq9ResponseIndex9].extension[0].value.value as Integer
  else
    0

// Question 10
define Phq9AnswerOptionsQuestion10:
  Phq9Questionnaire.item[IndexOfQuestion.ten].answerOption.value.code.value

define CurrentResponse10:
  CurrentResponses R
  where R.id = 'phq9-question-ten'
  return R.answer

define Phq9ResponseIndex10:
  if Exists(CurrentResponse10) then
    IndexOf(Phq9AnswerOptionsQuestion10, singleton from CurrentResponse10.code.value as String)
  else
    -1

define Phq9ScoreQuestion10:
  if Phq9ResponseIndex10 != -1 then
    Phq9Questionnaire.item[IndexOfQuestion.ten].answerOption[Phq9ResponseIndex10].extension[0].value.value as Integer
  else
    0

define AnsweredQuestionsFourThroughEight:
  Exists(CurrentResponse4)
    and Exists(CurrentResponse5)
    and Exists(CurrentResponse6)
    and Exists(CurrentResponse7)
    and Exists(CurrentResponse8)

define AnsweredQuestionsNineAndTen:
  Exists(CurrentResponse9)
    and Exists(CurrentResponse10)

define AnsweredQuestionsFourThroughTen:
  AnsweredQuestionsFourThroughEight
    and AnsweredQuestionsNineAndTen

// Should the score for the Full PHQ9 be displayed?
define DisplayScoreFullPhq9:
  AnsweredQuestionsFourThroughTen
    and DisplayScreeningScores // Input parameter which allows score display to be disabled

// Calculate the score for the Full PHQ9
define ScoreFullPhq9:
  ScoreUsAuditC
  + Phq9ScoreQuestion4
  + Phq9ScoreQuestion5
  + Phq9ScoreQuestion6
  + Phq9ScoreQuestion7
  + Phq9ScoreQuestion8
  + Phq9ScoreQuestion9
  + Phq9ScoreQuestion10

