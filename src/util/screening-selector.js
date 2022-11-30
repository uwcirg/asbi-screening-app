import valueSetJson from "../cql/valueset-db.json";
import { getEnv } from "./util.js";

export async function getPatientCarePlan(client, patientId) {
  if (!client || !patientId) return null;
  const sessionKey = client.getState().key;
  const CARE_PLAN_STORAGE_KEY = `careplan_${sessionKey}_${patientId}`;
  const storageItem = sessionStorage.getItem(CARE_PLAN_STORAGE_KEY);
  if (storageItem) return JSON.parse(storageItem);
  const carePlan = await client.request(
    `CarePlan?subject=Patient/${patientId}&category:text=questionnaire&_sort=-_lastUpdated`
  );
  if (carePlan && carePlan.entry && carePlan.entry.length) {
    sessionStorage.setItem(CARE_PLAN_STORAGE_KEY, JSON.stringify(carePlan));
    return carePlan;
  }

  return null;
}

export function getEnvInstrumentList() {
  const envList = getEnv("VUE_APP_SCREENING_INSTRUMENT") || "";
  console.log("instruments from environment ", envList);
  return envList.split(",").map((item) => item.trim());
}

export function getInstrumentListFromCarePlan(
  carePlan,
  questionnaireResponses
) {
  // no care plan entry, return empty array
  if (!carePlan || !carePlan.entry || !carePlan.entry.length) return [];
  const resources = carePlan.entry;
  let instrumentList = [];
  let activities = [];
  // gather activities from careplan(s)
  resources.forEach((item) => {
    if (item.resource.activity) {
      activities = [...activities, ...item.resource.activity];
    }
  });
  // no activities, return empty array
  if (!activities.length) return [];

  const responses = questionnaireResponses ? questionnaireResponses : [];

  // loop through activities that contains instantiatesCanonical
  activities.forEach((a) => {
    let qId = null;
    const detailElement = a.detail;
    if (
      detailElement &&
      detailElement.instantiatesCanonical &&
      detailElement.instantiatesCanonical.length
    ) {
      // instantiatesCanonical is in the form of Questionnaire/[questionnaire id]
      qId = a.detail.instantiatesCanonical[0].split("/")[1];
    }
    if (!qId) return true;

    // get matched questionnaire response(s) for the questionnaire
    const qResults = responses.filter((q) => {
      const questionnaireIdentifier = q.questionnaire.toUpperCase();
      return questionnaireIdentifier.indexOf(qId.toUpperCase()) !== -1;
    });

    // check instruments against scheduled scheduledTiming
    const scheduledTiming = detailElement.scheduledTiming;
    const repeat = scheduledTiming ? scheduledTiming.repeat : null;
    // check repeat schedule
    const period =
      repeat.period && !isNaN(repeat.period) ? parseInt(repeat.period) : 0;
    // h | d | wk | mo, https://fhir-ru.github.io/datatypes.html#Timing
    const toHours = {
      h: 1 * period,
      d: 24 * period, // day
      wk: 24 * 7 * period, // week
      mo: 24 * 30 * period, // assume 30 days in a month
    };

    const frequency = isNaN(repeat.frequency)
      ? null
      : parseInt(repeat.frequency);

    const dueInHours = repeat.periodUnit ? toHours[repeat.periodUnit] : 0;

    if (!qResults.length || !frequency || !dueInHours) {
      if (instrumentList.indexOf(qId) === -1) instrumentList.push(qId);
      return true;
    }

    // get today's date
    let today = new Date();
    today.setHours(0, 0, 0, 0);
  
    // search for questionnaire responses that fall within time range
    const matchedResults = qResults.filter((q) => {
      let authoredDate = new Date(q.authored);
      let timeZoneCorrection = authoredDate.getTimezoneOffset() * 60 * 1000; // [minutes] * [seconds/minutes] * [milliseconds/second]
      let correctedDate = new Date(authoredDate.getTime() + timeZoneCorrection);
      // miniseconds between two dates
      const msBetweenDates = Math.abs(
        today.getTime() - correctedDate.getTime()
      );
      // hours between two dates
      const hoursBetweenDates = msBetweenDates / (60 * 60 * 1000);
      return hoursBetweenDates < dueInHours;
    });

    // questionnaire response(s) found within the scheduled time and matched the frequency
    if (matchedResults.length > 0 && matchedResults.length === repeat.frequency)
      return true;
    if (instrumentList.indexOf(qId) === -1) instrumentList.push(qId);
  });

  console.log(
    "Screening instrument specified in careplan ",
    instrumentList.join(", ")
  );
  return instrumentList;
}

export async function getInstrumentList(client, patientId) {
  // if no patient id provided, get the questionnaire(s) fron the environment variable
  if (!patientId) return getEnvInstrumentList();
  const key = client.getState().key;
  // if questionnaire list is already stored within a session variable, returns it
  const sessionList = getSessionInstrumentList(key);
  if (sessionList) return sessionList;
  // get questionnaire(s) from care plan
  // NOTE: this is looking to the care plan as the source of truth about what questionnaire(s) are required for the patient
  const carePlan = await getPatientCarePlan(client, patientId);

  const questionnaireResponsesResult = await client.request(
    `QuestionnaireResponse?patient=${patientId}`
  );
  const questionnaireResponses =
    questionnaireResponsesResult && questionnaireResponsesResult.entry
      ? questionnaireResponsesResult.entry.map((result) => result.resource)
      : null;

  let instrumentList = carePlan
    ? getInstrumentListFromCarePlan(carePlan, questionnaireResponses)
    : [];

  // if we don't find a specified questionnaire from a patient's careplan,
  // we look to see if it is specifed in the environment variable
  if (!carePlan && (!instrumentList || !instrumentList.length)) {
    instrumentList = getEnvInstrumentList();
  }
  return instrumentList;
}

export function setSessionInstrumentList(key, data) {
  sessionStorage.setItem(`${key}_qList`, JSON.stringify(data));
}
export function getSessionInstrumentList(key) {
  const storedItem = sessionStorage.getItem(`${key}_qList`);
  if (!storedItem) return false;
  return JSON.parse(storedItem);
}
export function removeSessionInstrumentList(key) {
  sessionStorage.removeItem(`${key}_qList`);
}

//dynamically load questionnaire and cql JSON
export async function getScreeningInstrument(client, patientId) {
  if (!client) throw new Error("invalid FHIR client provided");
  const instrumentList = await getInstrumentList(client, patientId).catch((e) =>
    console.log("Error getting instrument list ", e)
  );
  if (!instrumentList || !instrumentList.length) {
    // TODO need to figure out if no questionnaire to administer is due to whether the user has completed all the survey(s)
    return [];
  }
  setSessionInstrumentList(client.getState().key, instrumentList);
  const screeningInstrument = instrumentList[0];
  if (screeningInstrument == "usaudit") {
    let questionnaireUsAudit = await import(
      "../fhir/1_Questionnaire-USAUDIT.json"
    ).then((module) => module.default);
    let elmJsonUsAudit = await import("../cql/UsAuditLogicLibrary.json").then(
      (module) => module.default
    );
    return [questionnaireUsAudit, elmJsonUsAudit, valueSetJson];
  } else if (screeningInstrument == "whoaudit") {
    let questionnaireWhoAudit = await import(
      "../fhir/1_Questionnaire-WHOAUDIT.json"
    ).then((module) => module.default);
    let elmJsonWhoAudit = await import("../cql/WhoAuditLogicLibrary.json").then(
      (module) => module.default
    );
    return [questionnaireWhoAudit, elmJsonWhoAudit, valueSetJson];
  } else if (screeningInstrument == "nidaqs2usaudit") {
    let questionnaireNidaQs = await import(
      "../fhir/1_Questionnaire-NIDAQS2USAUDIT.json"
    ).then((module) => module.default);
    let elmJsonNidaQs = await import(
      "../cql/NidaQsToUsAuditLogicLibrary.json"
    ).then((module) => module.default);
    return [questionnaireNidaQs, elmJsonNidaQs, valueSetJson];
  } else {
    const searchData = await Promise.all([
      // look up the questionnaire based on whether the id or the name attribute matches the specified instrument id?
      client.request("/Questionnaire/?_id=" + screeningInstrument),
      client.request("/Questionnaire?name:contains=" + screeningInstrument),
    ]).catch((e) => {
      throw new Error(
        `Error retrieving questionnaire from SoF host server: ${e}`
      );
    });
    let questionnaireJson;
    const qResults = searchData.filter((q) => q.entry && q.entry.length > 0);
    if (qResults.length) {
      questionnaireJson = qResults[0].entry[0].resource;
    }
    if (!questionnaireJson) {
      throw new Error(
        `No matching ${screeningInstrument || ""} questionnaire found.`
      );
    }
    let elmJson;
    let libId = questionnaireJson.name
      ? questionnaireJson.name.toUpperCase()
      : screeningInstrument.toUpperCase();
    try {
      elmJson = await import(`../cql/${libId}_LogicLibrary.json`).then(
        (module) => module.default
      );
    } catch (e) {
      // just log error to console as not every questionnaire has a corresponding ELM library
      console.log("error ", e);
      // throw new Error(
      //   "Error loading ELM library. Unsupported ELM library may have been specified " + e
      // );
    }
    return [instrumentList, questionnaireJson, elmJson, valueSetJson];
  }
}
