library Phq9LogicLibrary version '1.0.0'
/* Change Log
*/

using FHIR version '4.0.1'

include "FHIRHelpers" version '4.0.1' called FHIRHelpers

// -----------------------------------------------------------------------------
// CODESYSTEMS, VALUE SETS, CODES, AND CONCEPTS
// -----------------------------------------------------------------------------

codesystem "LOINC": 'http://loinc.org'
codesystem "LOCAL": 'http://www.cdc.gov/ncbddd/fasd'


// Local (non-standard) codes
// 44261-6 does link to PHQ9 score in Questionnaire-PHQ9.json
// Not sure if this qualifies as LOCAL...
code "PHQ9 Total Score code": '44261-6' from "LOCAL" display 'PHQ9 Total Score'

// -----------------------------------------------------------------------------
// PARAMETERS
// -----------------------------------------------------------------------------
parameter DisplayScreeningScores default true
parameter QuestionnaireURL default 'http://www.cdc.gov/ncbddd/fasd/phq9'

define question1LinkId: '/44250-9'
define question2LinkId: '/44255-8'
define question3LinkId: '/44259-0'
define question4LinkId: '/44254-1'
define question5LinkId: '/44251-7'
define question6LinkId: '/44258-2'
define question7LinkId: '/44252-5'
define question8LinkId: '/44253-3'
define question9LinkId: '/44260-8'
define question10LinkId: '/69722-7'

// -----------------------------------------------------------------------------
// PATIENT INFORMATION
// -----------------------------------------------------------------------------
context Patient

// We need to set the QuestionnaireURL parameter to an expression before we can use it
define CurrentQuestionnaireURL:
  QuestionnaireURL

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
    one: IndexOf(ItemLinkIds, question1LinkId),
    two: IndexOf(ItemLinkIds, question2LinkId),
    three: IndexOf(ItemLinkIds, question3LinkId),
    four: IndexOf(ItemLinkIds, question4LinkId),
    five: IndexOf(ItemLinkIds, question5LinkId),
    six: IndexOf(ItemLinkIds, question6LinkId),
    seven: IndexOf(ItemLinkIds, question7LinkId),
    eight: IndexOf(ItemLinkIds, question8LinkId),
    nine: IndexOf(ItemLinkIds, question9LinkId),
    ten: IndexOf(ItemLinkIds, question10LinkId)
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

/*
 @param question linkId of type FHIR.String
 @return answer element with that linkId
 */
define function getCurrentResponseByQuestionId(qid String):
  (
    CurrentResponses R
    where R.id = qid
    return R.answer
  )

/*
 retrieve concept code of the selected answer option
 @param question index of type FHIR.Integer
 @return code value for the answer
 */
define function getAnswerOptionCodeValue(qIndex Integer):
  if Phq9Questionnaire.item[qIndex] is not null then
    Phq9Questionnaire.item[qIndex].answerOption.value.code.value
  else
    null

/*
 * retrieve the numeric value for the answer from extension
 * @param a list of elements of type FHIR.Extension
 * @return the value as Integer
 */
define function getAnswerOptionExtensionValue(extList List<FHIR.Extension>):
  (singleton from (extList e where e.url ~ 'http://hl7.org/fhir/StructureDefinition/ordinalValue')).value.value as Integer

// Question 1
define Phq9AnswerOptionsQuestion1:
  getAnswerOptionCodeValue(IndexOfQuestion.one)

define CurrentResponse1:
  getCurrentResponseByQuestionId(question1LinkId)

define Phq9ResponseIndex1:
  if Exists(CurrentResponse1) then
    IndexOf(Phq9AnswerOptionsQuestion1, singleton from CurrentResponse1.code.value as String)
  else
    -1

define Phq9ScoreQuestion1:
  if Phq9ResponseIndex1 != -1 then
    getAnswerOptionExtensionValue(Phq9Questionnaire.item[IndexOfQuestion.one].answerOption[Phq9ResponseIndex1].extension)
  else
    0

// Question 2
define Phq9AnswerOptionsQuestion2:
  getAnswerOptionCodeValue(IndexOfQuestion.two)

define CurrentResponse2:
  getCurrentResponseByQuestionId(question2LinkId)

define Phq9ResponseIndex2:
  if Exists(CurrentResponse2) then
    IndexOf(Phq9AnswerOptionsQuestion2, singleton from CurrentResponse2.code.value as String)
  else
    -1

define Phq9ScoreQuestion2:
  if Phq9ResponseIndex2 != -1 then
    getAnswerOptionExtensionValue(Phq9Questionnaire.item[IndexOfQuestion.two].answerOption[Phq9ResponseIndex2].extension)
  else
    0

// Question 3
define Phq9AnswerOptionsQuestion3:
  getAnswerOptionCodeValue(IndexOfQuestion.three)

define CurrentResponse3:
  getCurrentResponseByQuestionId(question3LinkId)

define Phq9ResponseIndex3:
  if Exists(CurrentResponse3) then
    IndexOf(Phq9AnswerOptionsQuestion3, singleton from CurrentResponse3.code.value as String)
  else
    -1

define Phq9ScoreQuestion3:
  if Phq9ResponseIndex3 != -1 then
    getAnswerOptionExtensionValue(Phq9Questionnaire.item[IndexOfQuestion.three].answerOption[Phq9ResponseIndex3].extension)
  else
    0

// Question 4
define Phq9AnswerOptionsQuestion4:
  getAnswerOptionCodeValue(IndexOfQuestion.four)

define CurrentResponse4:
  getCurrentResponseByQuestionId(question4LinkId)

define Phq9ResponseIndex4:
  if Exists(CurrentResponse4) then
    IndexOf(Phq9AnswerOptionsQuestion4, singleton from CurrentResponse4.code.value as String)
  else
    -1

define Phq9ScoreQuestion4:
  if Phq9ResponseIndex4 != -1 then
    getAnswerOptionExtensionValue(Phq9Questionnaire.item[IndexOfQuestion.four].answerOption[Phq9ResponseIndex4].extension)
  else
    0

// Question 5
define Phq9AnswerOptionsQuestion5:
  getAnswerOptionCodeValue(IndexOfQuestion.five)

define CurrentResponse5:
  getCurrentResponseByQuestionId(question5LinkId)

define Phq9ResponseIndex5:
  if Exists(CurrentResponse5) then
    IndexOf(Phq9AnswerOptionsQuestion5, singleton from CurrentResponse5.code.value as String)
  else
    -1

define Phq9ScoreQuestion5:
  if Phq9ResponseIndex5 != -1 then
    getAnswerOptionExtensionValue(Phq9Questionnaire.item[IndexOfQuestion.five].answerOption[Phq9ResponseIndex5].extension)
  else
    0

// Question 6
define Phq9AnswerOptionsQuestion6:
  getAnswerOptionCodeValue(IndexOfQuestion.six)

define CurrentResponse6:
  getCurrentResponseByQuestionId(question6LinkId)

define Phq9ResponseIndex6:
  if Exists(CurrentResponse6) then
    IndexOf(Phq9AnswerOptionsQuestion6, singleton from CurrentResponse6.code.value as String)
  else
    -1

define Phq9ScoreQuestion6:
  if Phq9ResponseIndex6 != -1 then
    getAnswerOptionExtensionValue(Phq9Questionnaire.item[IndexOfQuestion.six].answerOption[Phq9ResponseIndex6].extension)
  else
    0

// Question 7
define Phq9AnswerOptionsQuestion7:
  getAnswerOptionCodeValue(IndexOfQuestion.seven)

define CurrentResponse7:
  getCurrentResponseByQuestionId(question7LinkId)

define Phq9ResponseIndex7:
  if Exists(CurrentResponse7) then
    IndexOf(Phq9AnswerOptionsQuestion7, singleton from CurrentResponse7.code.value as String)
  else
    -1

define Phq9ScoreQuestion7:
  if Phq9ResponseIndex7 != -1 then
    getAnswerOptionExtensionValue(Phq9Questionnaire.item[IndexOfQuestion.seven].answerOption[Phq9ResponseIndex7].extension)
  else
    0

// Question 8
define Phq9AnswerOptionsQuestion8:
  getAnswerOptionCodeValue(IndexOfQuestion.eight)

define CurrentResponse8:
  getCurrentResponseByQuestionId(question8LinkId)

define Phq9ResponseIndex8:
  if Exists(CurrentResponse8) then
    IndexOf(Phq9AnswerOptionsQuestion8, singleton from CurrentResponse8.code.value as String)
  else
    -1

define Phq9ScoreQuestion8:
  if Phq9ResponseIndex8 != -1 then
    getAnswerOptionExtensionValue(Phq9Questionnaire.item[IndexOfQuestion.eight].answerOption[Phq9ResponseIndex8].extension)
  else
    0

// Question 9
define Phq9AnswerOptionsQuestion9:
  getAnswerOptionCodeValue(IndexOfQuestion.nine)

define CurrentResponse9:
  getCurrentResponseByQuestionId(question9LinkId)

define Phq9ResponseIndex9:
  if Exists(CurrentResponse9) then
    IndexOf(Phq9AnswerOptionsQuestion9, singleton from CurrentResponse9.code.value as String)
  else
    -1

define Phq9ScoreQuestion9:
  if Phq9ResponseIndex9 != -1 then
    getAnswerOptionExtensionValue(Phq9Questionnaire.item[IndexOfQuestion.nine].answerOption[Phq9ResponseIndex9].extension)
  else
    0

// Question 10
define Phq9AnswerOptionsQuestion10:
  getAnswerOptionCodeValue(IndexOfQuestion.ten)

define CurrentResponse10:
  getCurrentResponseByQuestionId(question10LinkId)

define Phq9ResponseIndex10:
  if Exists(CurrentResponse10) then
    IndexOf(Phq9AnswerOptionsQuestion10, singleton from CurrentResponse10.code.value as String)
  else
    -1

define Phq9ScoreQuestion10:
  if Phq9ResponseIndex10 != -1 then
    getAnswerOptionExtensionValue(Phq9Questionnaire.item[IndexOfQuestion.ten].answerOption[Phq9ResponseIndex10].extension)
  else
    0

// Should the score for the Full PHQ9 be displayed?
define DisplayScoreFullPhq9:
    (CurrentResponse1 is not null or
    CurrentResponse2 is not null or
    CurrentResponse3 is not null or
    CurrentResponse4 is not null or
    CurrentResponse5 is not null or
    CurrentResponse6 is not null or
    CurrentResponse7 is not null or
    CurrentResponse8 is not null or
    CurrentResponse9 is not null or
    CurrentResponse10 is not null
    )
    and DisplayScreeningScores // Input parameter which allows score display to be disabled

// Calculate the score for the Full PHQ9
// sum up all numeric values for all the answers
define ScoreFullPhq9:
  Phq9ScoreQuestion1
  + Phq9ScoreQuestion2
  + Phq9ScoreQuestion3
  + Phq9ScoreQuestion4
  + Phq9ScoreQuestion5
  + Phq9ScoreQuestion6
  + Phq9ScoreQuestion7
  + Phq9ScoreQuestion8
  + Phq9ScoreQuestion9
  + Phq9ScoreQuestion10
