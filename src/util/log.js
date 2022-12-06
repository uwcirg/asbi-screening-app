import { getEnv } from "./util";

function getDefaultLogObject() {
  return {
    level: "info",
    tags: ["screener-front-end"],
    message: {
      systemURL: window.location.href,
    },
  };
}
//write to audit log
// @param level, expect string
// @param tags, expect array, e.g. ['etc']
// @param message, expect object, e.g. { "questionId": "123"}
export function writeToLog(level, tags, message) {
  const confidentialBackendURL = getEnv("VUE_APP_CONF_API_URL");
  if (!confidentialBackendURL) {
    console.log("confidential backend URL is not set.");
    return;
  }
  let postBody = getDefaultLogObject();
  if (level) postBody.level = level;
  if (tags) postBody.tags = [...postBody.tags, ...tags];
  if (message)
    postBody.message = {
      ...postBody.message,
      ...message,
    };
  const auditURL = `${confidentialBackendURL || ""}/auditlog`;
  fetch(auditURL, {
    method: "post",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(postBody),
  })
    .then((response) => {
      if (!response.ok) {
        throw Error(response.statusText);
      }
      return response.json();
    })
    .then(function (data) {
      console.log("audit request succeeded with response ", data);
    })
    .catch(function (error) {
      console.log("Request failed", error);
    });
}

// write to log on survey page change event
// @param options, see options object available on SurveyJS onCurrentPageChanged event
// https://surveyjs.io/form-library/documentation/api-reference/surveymodel#onCurrentPageChanged
// @param params, of type object, optional, additional params post to log server
export function writeLogOnSurveyPageChange(options, params) {
  if (!options) return;
  const questionElements = options.oldCurrentPage
    ? options.oldCurrentPage.questions
    : null;
  if (!questionElements) {
    return;
  }
  params = params || {};
  let arrVisibleQuestions = questionElements
    .filter((q) => q.isVisible)
    .map((q) => q.name);
  // whether user clicks the previous or next button
  const navDirection = options.isNextPage
    ? "clickNext"
    : options.isPrevPage
    ? "clickPrev"
    : "";
  if (arrVisibleQuestions.length) {
    writeToLog("info", ["questionDisplayed", "onPageChanged", navDirection], {
      questionID: arrVisibleQuestions,
      ...params,
    });
  }
}
// write to log on survey question value change event
// @param options, see options object available on SurveyJS onValueChanging event
// https://surveyjs.io/form-library/documentation/api-reference/surveymodel#onValueChanging
// @param params, of type object, optional, additional params post to log server
export function writeLogOnSurveyQuestionValueChange(options, params) {
  if (!options) return;
  params = params || {};
  writeToLog("info", ["answerEvent"], {
    questionId: options.name,
    answerEntered: options.value,
    ...params,
  });
}

// write to log on survey completing
// @params sender, see sender object available on SurveyJs OnComplete event
// https://surveyjs.io/form-library/documentation/api-reference/surveymodel#onComplete
// @param params, of type object, optional, additional params post to log server
export function writeLogOnSurveySubmit(sender, params) {
  const questionElements =
    sender.currentPage && sender.currentPage.questions
      ? sender.currentPage.questions
      : null;
  if (!questionElements) return;
  params = params || {};
  questionElements.forEach((el) => {
    console.log("value ", el.value);
  });
  let arrAnswers = questionElements
    .filter((q) => q.value)
    .map((q) => ({
      questionID: q.name,
      answer: q.value,
    }));
  let arrVisibleQuestions = questionElements
    .filter((q) => q.isVisible)
    .map((q) => q.name);
  if (arrVisibleQuestions.length) {
    writeToLog("info", ["onSubmit"], {
      questionsDisplayedOnPage: arrVisibleQuestions,
      questionsAnsweredOnPage: arrAnswers,
      ...params,
    });
  }
}
